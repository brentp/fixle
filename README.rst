=============================================================
Fixle: fast, fixed-length, integer-keyed db via tokyo-cabinet
=============================================================

:Author: Brent Pedersen (brentp)
:Email: bpederse@gmail.com
:License: LGPL3

.. contents ::

Implementation
==============

uses cython to wrap the fixed length database `api`_ in `tokyo-cabinet`_ .

Usage
=====

acts like a list, except for deletions.
::

    >>> from fixle import Fixle
    >>> import os

    >>> fdb = Fixle('t.fdb', mode='w')
    >>> for i in range(10):
    ...     fdb[i] = str(i)
    >>> fdb.append('100')
    >>> fdb.extend(['111', '222'])
    >>> fdb[1]
    '1'

    >>> fdb[2:5]
    ['2', '3', '4']

    >>> del fdb[4]
    >>> fdb[2:5]
    ['2', '3']

    >>> fdb.items(2, 5)
    [(2L, '2'), (3L, '3')]

    >>> del fdb



can also be used like a shelve where the values are pickled.
::

    >>> fdb = Fixle('p.fdb', 'w', pickle=True)
    >>> for i in range(10):
    ...     fdb.append({'a': i, 'b': range(i, i + 3)})

    >>> fdb[2]
    {'a': 2, 'b': [2, 3, 4]}

speed
=====

Fixle should be very fast, run
::

    $ python tests/bench.py b

to see it compared to shelve and bsddb. seems to be
about 10x faster even when pickling the entries, but NOTE that
it must use integer keys.

.. _`tokyo-cabinet`: http://1978th.net/tokyocabinet/
.. _`api`: http://1978th.net/tokyocabinet/spex-en.html#tcfdbapi

