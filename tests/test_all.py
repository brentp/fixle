import unittest
import os
from fixle import Fixle, FixleException, FixleLong, FixleDouble

class FixleTest(unittest.TestCase):
    list = ["asdf", "bbbb", "a\0a"]
    def setUp(self):
        _cleanup()
        self.f = Fixle("./t.fdb", mode='w')
        for i, v in enumerate(self.list):
            self.f[i] = v

        self.f.sync()

    def test_len(self):
        self.assertEquals(len(self.f), 3)

    def test_get(self):
        for i, v in enumerate(self.list):
            self.assertEquals(self.f[i], v)

    def test_read(self):
        self.f.close()
        self.f = Fixle("./t.fdb", mode="r")
        self.assertEquals(self.f[1], self.list[1])

        self.assertRaises(FixleException, self.f.__setitem__, 1, "g")

    def test_range(self):
        self.assertEquals(self.f[1:3], self.list[1:3])
        self.assertEquals(self.f[:3], self.list[:3])
        self.assertEquals(self.f[2:], self.list[2:])

    def test_append(self):
        values = ["g", "h", "i"]
        for v in values:
            self.f.append(v)
        self.f.sync()

        for i, v in zip(range(3, 6), values):
            self.assertEqual(self.f[i], v)

    def test_extend(self):
        n = len(self.f)
        values = ["rrg", "rrh", "rri"]
        self.f.extend(values)
        self.assertEqual(len(self.f), n + 3)
        n = len(self.f)
        for i, v in enumerate(self.f[n - 3:]):
            self.assertEqual(v, values[i])

    def tearDown(self):
        self.f.clear()
        del self.f

    def test_index(self):
        self.assertRaises(IndexError, self.f.__getitem__, 10)

    def test_iter(self):
        self.assertEquals(list(self.f), self.list)

    def test_del(self):
        # note delete will act more like a dict than a list.
        f = self.f
        self.assertEquals(len(f), 3)
        del f[1]
        self.assertEquals(len(f), 2)

        olist = self.list[:]
        del olist[1]

        self.assertEquals(list(f), olist)

        self.assertEquals(f.keys(), [0, 2])

    def test_items(self):
        f = self.f
        self.assertEqual(f.items(), list(enumerate(self.list)))

        self.assertEqual(f.items(2), list(enumerate(self.list))[2:])

        self.assertEqual(f.items(1, 2), list(enumerate(self.list))[1:2])

    def test_zero(self):
        f = self.f
        self.assertEqual(f[0], self.list[0])


def _cleanup():
    try: os.unlink('./t.fdb')
    except: pass
    import time
    time.sleep(0.1)


class FixleLongTest(unittest.TestCase):
    def setUp(self):
        self.f = FixleLong('./t.fldb', mode='w', width=8)
        for i in range(100):
            self.f[i] =i

    def test_get(self):
        self.assertEquals(self.f[3], 3)
        self.assertEquals(self.f[9], 9)
        self.assertEquals(self.f[0], 0)
        self.assertEquals(self.f[99], 99)
        #self.assertEqual(list(self.f), range(10))

    
    def test_range(self):
        rms = (41, 43, 44, 46, 47, 48, 50)
        for i in rms:
            del self.f[i]

        r = self.f[40:52]
        for arm in rms:
            self.assert_(not arm in r)

        self.assertEqual(r, [40, 42, 45, 49, 51])

    def tearDown(self):
        self.f.clear()
        del self.f

class FixleDoubleText(FixleLongTest):

    def setUp(self):
        self.f = FixleDouble('./t.fldb', mode='w', width=22)
        self.f.clear()
        for i in range(100):
            self.f[i] = i * 99.99

    def test_get(self):
        self.assertAlmostEqual(self.f[3], 3 * 99.99)
        self.assertAlmostEqual(self.f[9], 9 * 99.99)
        self.assertAlmostEqual(self.f[0], 0 * 99.99)
        self.assertAlmostEqual(self.f[99], 99 * 99.99)

    def test_range(self):
        pass

class FixlePickle(FixleTest):
    list = ["asdf", (1, 2, 3, 4), (range(3), {"a": 4})]
    def setUp(self):
        self.f = Fixle("./t.fdb", mode='w', pickle=True)
        for i, v in enumerate(self.list):
            self.f[i] = v

        self.f.sync()

    def test_read(self):
        self.f.close()
        self.f = Fixle("./t.fdb", mode="r", pickle=True)
        self.assertEquals(self.f[1], self.list[1])

        self.assertRaises(FixleException, self.f.__setitem__, 1, "g")

if __name__ == "__main__":
    unittest.main()
    os.unlink("t.fdb")
