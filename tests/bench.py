
from fixle import Fixle
import shelve
import bsddb
import os

def rm(p):
    try:os.unlink(p)
    except OSError: pass
N = long(1e5)

rm('t.fdb')
rm('t.pfd')
rm('t.shv')
rm('t.bsd')

def load_str(db, N=N):
    if isinstance(db, Fixle):
        for i in xrange(N):
            db[i] = str(i)
    else:
        for i in xrange(N):
            s = str(i)
            db[s] = s

       

def read_str(db, N=N):
    if isinstance(db, Fixle):
        for i in xrange(N):
             assert str(i) == db[i], i

    else:
        for i in xrange(N):
             assert str(i) == db[str(i)]

if __name__ == "__main__":
    import sys
    if sys.argv[1] != 'b':
        sys.exit(0)

    import time

    fdb = Fixle('t.fdb', 'w', n_records=N)
    pfd = Fixle('t.pfd', 'w', n_records=N, pickle=True)
    sdb = shelve.open('t.shv', 'c', protocol=2)
    bsd = bsddb.hashopen('t.bsd', 'c', nelem=N, pgsize=512)

    print "'pik' is fixle with pickling"
    print "db : load,  read"

    for db, name, n in ((fdb, 'fdb', 10), (pfd, 'pik', 10), (sdb, 'sdb', 1), (bsd, 'bsd', 1)):
        t0 = time.time()
        load_str(db, N * n)
        #fdb.autooptimize()
        t1 = time.time()
        read_str(db, N * n)
        print "%s: %.3f, %.3f" % (name, (t1 - t0) / float(n), (time.time() - t1) / float(n))

        del db
