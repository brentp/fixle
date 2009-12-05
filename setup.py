#!/usr/bin/env python
# -*- coding: utf-8 -*-

#from distutils.core import setup
from setuptools import setup
from distutils.extension import Extension
import os, sys

if not os.path.exists('src/cfixle.c'):
    print "run cython src/cfixle.c"
    sys.exit()

setup(
    ext_modules = [Extension("cfixle", ["src/cfixle.c"],
                             libraries=['tokyocabinet'],
                            )
                  ],
    name = 'fixle',
    version = '0.0.1',
    description = 'fast, fixed-length, integer-keyed db via tokyo-cabine',
    license = 'License :: OSI Approved :: GNU Library or Lesser General Public License (LGPL)',
    long_description = open('README.rst').read(),
    url          = '',
    download_url = '',
    classifiers  = ['Development Status :: 3 - Alpha',
                    'Intended Audience :: Developers',
                    'License :: OSI Approved :: GNU Library or Lesser General Public License (LGPL)',
                    'Operating System :: OS Independent',
                    'Programming Language :: Python',
                    'Programming Language :: C',
                    'Topic :: Database :: Database Engines/Servers',
                   ],
    package_dir = {'': 'fixle'},
    test_suite="nose.collector",
    packages = ['.'],
)
