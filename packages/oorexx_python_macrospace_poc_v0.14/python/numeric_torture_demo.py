"""Numeric boundary torture chamber.

This test is intentionally suspicious.  It first records Python's own numeric
types and exact spellings.  It does not silently coerce numeric-looking strings
or Decimal into float.
"""
from decimal import Decimal
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

cases = [
    ("big-int", int("9" * 100)),
    ("decimal-tenth", Decimal("0.1")),
    ("decimal-precise", Decimal("0.10000000000000000000000000000000000001")),
    ("binary-float-tenth", 0.1),
    ("lexical-number", "00123.4500"),
    ("boolean", True),
    ("none", None),
]

for name, value in cases:
    print(f"python-{name}: type={type(value).__name__} repr={value!r}")

assert isinstance(cases[0][1], int) and not isinstance(cases[0][1], bool)
assert str(cases[1][1]) == "0.1"
assert repr(cases[3][1]) == "0.1"
assert cases[4][1] == "00123.4500"
assert isinstance(cases[5][1], bool)  # bool/int trap explicitly recorded

# Decimal arithmetic must stay decimal in Python.
d = Decimal("0.1")
assert d * 10 == Decimal("1.0")
print("python-decimal-tenth-times-ten:", d * 10)

# Binary float is *not* declared exact merely because repr is short.
print("python-float-hex:", float(0.1).hex())

# Non-finite floats are recorded as a separate policy problem, not passed
# through as if Rexx necessarily had the same numeric domain.
for value in (float("nan"), float("inf"), float("-inf"), -0.0):
    print("python-special-float:", repr(value), "hex=", value.hex() if not math.isnan(value) else "nan")

# Run the Rexx half when a rexx executable is available.  This is deliberately
# separate from native marshalling: first establish each runtime's semantics.
try:
    cp = subprocess.run(["rexx", str(ROOT/"rexx/numeric_torture.rex")],
                        text=True, capture_output=True, check=False)
except FileNotFoundError:
    print("rexx-numeric-probe: SKIP (rexx executable not on PATH)")
else:
    print(cp.stdout, end="")
    if cp.stderr:
        print(cp.stderr, end="")
    if cp.returncode:
        raise SystemExit(f"Rexx numeric torture failed rc={cp.returncode}")

print("NUMERIC TORTURE OBSERVATION POC PASS")
