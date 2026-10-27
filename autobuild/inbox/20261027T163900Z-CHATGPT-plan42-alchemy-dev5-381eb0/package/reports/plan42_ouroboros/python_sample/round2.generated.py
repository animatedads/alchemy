#!/usr/bin/env python3
"""
Generated from Plan42 module: ouroboros_python_sample
Python module converted into a Plan42 program specification.

This file was emitted by plan42c.py.  Do not hand-edit generated output
unless you are deliberately breaking the Ouroboros loop.
"""

# PLAN42_EMBEDDED_SPEC_GZIP_BASE64_BEGIN
# H4sIAAAAAAAC/81WTW/bOBD9KwQv6QLa1JZlW85ij0Wxh10Uxd4CQ6WokU2EJlWKTBME/u+doWRb
# LmInNVKgBxvix8y8efOG5BOX1tyDa5U1ReuFb/nNE1ebRheltvIOh6OEt94F6YMTujC2ApwcjxMe
# TBuaxjoPVQEPjYOWvHQWwzVyCxswvlv6JpxRZoWD2+U24ehOOtV4NOU3/NOjX1vDNrYKGliHDX0w
# Zbxlgn3SwmQpa5xdObFhbQNS1UoKsr7mCe/s0I8NzpbW2bZooseiFZgT4JY+gdsnXoZWGQRdNME1
# tiWzf6P9nxruQbMeC4LADIxnlCG4e0RTO4vBMYYEimrEhow/fv7w4f9//vuIM7bBcTTEQY8A6RRd
# lk+4pAtb1y34SAmYqhhOjfNuTiM+Y3Gc8P0nUnYvdKCAa9Da8m2CqdjqMeZEdaAAGmr0wx92WDZB
# 46dTq7Wn5TinlQcsKd87TLfbfrsDrLZ5GXv2DPbZMfbsgD07YL8c4XaZPFe5vlh1MJKAsi+VDaWG
# LwMNDRXkbPDoYlC9bv8OTb9ODAhUGgkGoS53hBBC0T4ayW9qoVsgGUvrhLcu6jrpGcSBCVpjB6mV
# ETgTI0HNumjvHv7A8l0ikNMkT7bPCuIEnySnngCzyx1T0cLBZdUfHQObH4DNMZQXbkXbYrC9FE5i
# o0yOFb3XzY/NJqrqZflwxvcSPzLoONgtYe2b4C/Kf5Ie558f8s9/pjBc25WShyPnp7HlL2OjWh2+
# Y2Nhs1RDsrFcUfqGpN8dakLHPu37Y983O3zw9eUyZPGgAU2N+1omSmfvwLwFDeniBxrSAQ1ppCGG
# UPVFCjjnfkEtsMY0flMBnLlKTuLEic3f/PmuorVfUrLBeTfOYskUvR5ur8RVwq5K+pNXS4wVEfRA
# 4sgV53m/5QIHJf4kX+6g1xbNhFy/jSCG4CfxSnR7rl55uW2EMq+/2mj3uYstbnu7u43CvSOfF15u
# 5wibxWJ3T6/O1e71isEPz1T2bQ0OGNLXKjyd/mIdCkYPW4ZZ6VLIu36Tg69BOSDd1kpDz5m3Vrfv
# Tzwjr5tH3I10r4JY0e5udYKT7Vqk0xlOLaCeZvk4n07ytK7rdFKW5UzOptU0z+f5pJqVi8l8McsW
# IEZTkVVluRD5bDSGVICcpnPijt636Gp8PeLb75/Us5uqCwAA
# PLAN42_EMBEDDED_SPEC_GZIP_BASE64_END

from __future__ import annotations
from pathlib import Path
from typing import Any

GREETING = 'hello'
def double(x):
    'Python function `double` converted to a Plan42 routine.'
    return (x * 2)

def main(name):
    'Python function `main` converted to a Plan42 routine.'
    n = 21
    print(((GREETING + ' ') + name))
    if (double(n) == 42):
        print('logic preserved')
    else:
        print('logic broken')
    for item in ['a', 'b', 'c']:
        print(('item=' + item))


if __name__ == "__main__":
    import argparse as _p42_argparse
    _p42_parser = _p42_argparse.ArgumentParser()
    _p42_parser.add_argument('--name', default='')
    _p42_args = _p42_parser.parse_args()
    main(_p42_args.name)
