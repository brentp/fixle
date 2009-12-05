cdef extern from *:
    ctypedef char * const_char_star "const char *"
    ctypedef void * const_void_star "const void *"
    ctypedef long int64_t
    ctypedef int int32_t
    ctypedef unsigned long uint64_t

cdef extern from "ltoa.h":
    char * ltoa(int64_t v, char *s)
cdef extern from "stdlib.h":
    int64_t atol(char *)
    double atof(char *)
    int sprintf(char *str, const_char_star fmt, ...)



cimport python_string as ps
cimport stdlib
import cPickle

# subjract 1 here as it gets added in get/set()
DEF FDBIDNEXT = -5 # /* greater by one than the maximum */
DEF FDBIDMAX =  -4 # /* max
DEF FDBIDMIN = -1



cdef extern from "tcfdb.h":
    cdef enum:
        FDBOREADER = 1 << 0 # /* open as a reader */
        FDBOWRITER = 1 << 1 # /* open as a writer */
        FDBOCREAT = 1 << 2  # /* writer creating */
        FDBOTRUNC = 1 << 3  # /* writer truncating */
        FDBONOLCK = 1 << 4  # /* open without locking */
        FDBOLCKNB = 1 << 5  # /* lock without blocking */
        FDBOTSYNC = 1 << 6  # /* synchronize every transaction */

    ctypedef struct TCFDB: 
        pass

    const_char_star tcfdberrmsg(int ecode)
    int tcfdbdecode(TCFDB *fdb)

    TCFDB *tcfdbnew()

    void tcfdbdel(TCFDB *fdb)

    bint tcfdbopen(TCFDB *fdb, const_char_star path, int omode)
    bint tcfdbclose(TCFDB *fdb)


    bint tcfdbput(TCFDB *fdb, int64_t id, const_void_star vbuf, int vsiz)
    bint tcfdbout(TCFDB *fdb, int64_t id)
    void *tcfdbget(TCFDB *fdb, int64_t id, int *sp) 
    
    int tcfdbvsiz(TCFDB *fdb, int64_t id)

    bint tcfdbiterinit(TCFDB *fdb)
    uint64_t tcfdbiternext(TCFDB *fdb)
    uint64_t *tcfdbrange(TCFDB *fdb, int64_t lower, int64_t upper, int max, int *np) 
    bint tcfdbsync(TCFDB *fdb)
    bint tcfdboptimize(TCFDB *fdb, int32_t width, int64_t limsiz)
    bint tcfdbtune(TCFDB *fdb, int32_t width, int64_t limsiz)
    bint tcfdbvanish(TCFDB *fdb)
    
    int tcfdbrnum(TCFDB *fdb)

    int tcfdbecode(TCFDB *fdb)
    char * tcfdberrmsg(int ecode)

class FixleException(Exception): 
    pass

cdef handle_error(TCFDB *fdb):
    cdef int e = tcfdbecode(fdb)
    raise FixleException(tcfdberrmsg(e))


    
cdef class Fixle:
    cdef TCFDB *fdb
    cdef readonly path
    cdef bint read_only
    cdef bint pickle
    cdef int32_t changes
    cdef int64_t CHANGE_ON
    cdef int32_t MAX_WIDTH

    def __cinit__(self, path, mode='r', bint pickle=False, int32_t width=-1, int64_t n_records=-1):
        self.fdb = tcfdbnew()
        cdef bint success
        self.pickle = pickle
        self.path = path
        self.read_only = mode[0] == 'r'
        self.CHANGE_ON = n_records if n_records > -1 else 5000000
        self.MAX_WIDTH = 16
        cdef int mw = FDBOWRITER | FDBOCREAT #| FDBONOLCK # | FDBOLCKNB
        if (width, n_records) != (-1, -1):
            self.tune(width, n_records)
        success = tcfdbopen(self.fdb, path, mw if mode in "cw" else FDBOREADER)
        if not success:
            handle_error(self.fdb)
        self.changes = 0

    def tune(self, int32_t width=-1, int64_t n_records=-1):
        if width == -1:
            width = max(tcfdbvsiz(self.fdb, FDBIDMAX), 128 if self.pickle else 32)
        if n_records == -1:
            n_records = len(self) + 1
        cdef int64_t limsiz = n_records * (width + 4)
        success = tcfdbtune(self.fdb, width, limsiz)
        if not success:
            handle_error(self.fdb)


    def optimize(self, int32_t width=-1, int64_t n=-1):
        if self.read_only:
            return False

        if n == -1:
            n = len(self)
        if width == -1:
            width = tcfdbvsiz(self.fdb, FDBIDMAX)

        if width > self.MAX_WIDTH:
            self.MAX_WIDTH = width

        cdef int64_t limsiz = n * (width + 4)
        success = tcfdboptimize(self.fdb, width, limsiz)
        if not success:
            handle_error(self.fdb)
        self.changes = 0

    def autooptimize(self):
        cdef int32_t width = tcfdbvsiz(self.fdb, FDBIDMAX + 1) + 4
        cdef int nrecs = <int>(len(self) + self.CHANGE_ON + 1)
        self.optimize(width, nrecs)


    def __len__(self):    
        return tcfdbrnum(self.fdb)

    def __setitem__(self, int64_t id, v):
        self.changes += 1
        if self.changes >= self.CHANGE_ON:
            self.autooptimize()
        self.set(id, v)


    cdef set(self, int64_t id, v):

        if self.read_only:
            raise FixleException("can't setitem with file opened readonly\n"
                                 "%s[%i] = %s" % (self.path, id, v))

        cdef Py_ssize_t vsiz
        if self.pickle:
            v = cPickle.dumps(v, -1)

        cdef char *vbuf
        ps.PyString_AsStringAndSize(v, &vbuf, &vsiz)
        if vsiz > self.MAX_WIDTH:
            self.optimize(width=vsiz + 1)
        tcfdbput(self.fdb, id + 1, vbuf, <int>vsiz)

    cdef getone(self, int64_t id):
        cdef int sp
        cdef void *v = tcfdbget(self.fdb, id, &sp) 
        if v == NULL:
            raise IndexError(str(id))
        item = ps.PyString_FromStringAndSize(<char *>v, sp)
        return cPickle.loads(item) if self.pickle else item

    def __getitem__(self, slice):
        if isinstance(slice, (int, long)):
            return self.getone(slice + 1)
        if slice.start is None: 
            return self.getrange(1, slice.stop + 1)
        elif slice.stop is None:
            return self.getrange(slice.start + 1,  FDBIDMAX + 2)
        else:
            return self.getrange(slice.start + 1, slice.stop + 1)

    cpdef getrange(self, int64_t start, int64_t end):
        cdef int np, i
        cdef uint64_t *vals = tcfdbrange(self.fdb, start, end - 1, -1, &np)
        if vals == NULL:
            return handle_error(self.fdb)

        cdef list items = [self.getone(vals[i]) for i in range(np)]
        stdlib.free(vals)
        return items

    def items(self, int64_t start=-2, int64_t end=-2):
        cdef int np, i
        #blech. too many hacks to change 1-based indexing to 0-based.
        if end != -2:
            end += 1
        cdef uint64_t *vals = tcfdbrange(self.fdb, start + 1, end - 1, -1, &np)
        cdef list items = [(vals[i] - 1, self.getone(vals[i])) for i in range(np)]
        stdlib.free(vals)
        return items

    cpdef keys(self):
        cdef int np, i
        cdef uint64_t *vals = tcfdbrange(self.fdb, -1, -3, -1, &np)
        cdef list items = [vals[i] - 1 for i in range(np)]
        stdlib.free(vals)
        return items

    def append(self, val):
        self.set(FDBIDNEXT, val)

    def extend(self, list li):
        for item in li:
            self.set(FDBIDNEXT, item)

    def sync(self):
        return tcfdbsync(self.fdb)

    def __dealloc__(self):
        tcfdbdel(self.fdb)

    def close(self):
        return tcfdbclose(self.fdb)

    def clear(self):
        tcfdbvanish(self.fdb)

    def __iter__(self):
        tcfdbiterinit(self.fdb)
        return self

    def __delitem__(self, int64_t id):
        tcfdbout(self.fdb, id + 1)

    def __next__(self):
        vals = []
        cdef uint64_t idx = tcfdbiternext(self.fdb)
        if idx != 0: 
            return self.getone(idx)
        else:
            raise StopIteration


cdef class FixleLong(Fixle):

    cdef set(self, int64_t id, val):
        cdef int sp
        cdef int64_t v = val
        cdef char buffer[24]

        if self.read_only:
            raise FixleException("can't setitem with file opened readonly\n"
                                 "%s[%i] = %s" % (self.path, id, v))
        ltoa(v, buffer)
        tcfdbput(self.fdb, id + 1, buffer, stdlib.strlen(buffer))

    cdef getone(self, int64_t id):
        cdef int sp
        cdef void* vo = tcfdbget(self.fdb, id, &sp) 
        if vo == NULL:
            raise IndexError(str(id))
        return atol(<char *>vo)


cdef class FixleDouble(Fixle):

    cdef set(self, int64_t id, val):
        cdef int sp
        cdef double v = val
        cdef char buffer[24]

        if self.read_only:
            raise FixleException("can't setitem with file opened readonly\n"
                                 "%s[%i] = %s" % (self.path, id, v))
        sprintf(buffer, "%lf", v)
        tcfdbput(self.fdb, id + 1, buffer, stdlib.strlen(buffer))

    cdef getone(self, int64_t id):
        cdef int sp
        cdef void* vo = tcfdbget(self.fdb, id, &sp) 
        if vo == NULL:
            raise IndexError(str(id))
        return atof(<char *>vo)


