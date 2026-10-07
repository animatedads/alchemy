import os
from pathlib import Path
import _rexxpython_poc as _native
ROOT = Path(__file__).resolve().parents[1]
_required = ["ALCHEMY_OBJECTS_SRC","ALCHEMY_CRYPTO_SRC","OOREXX_PLATFORM_BIN"]
_missing = [k for k in _required if not os.environ.get(k)]
if _missing:
    raise RuntimeError("stem_demo requires package-space environment: " + ", ".join(_missing))
_rexx_path = os.pathsep.join([str(ROOT/"rexx"), os.environ["ALCHEMY_OBJECTS_SRC"], os.environ["ALCHEMY_CRYPTO_SRC"], os.environ["OOREXX_PLATFORM_BIN"]])
_native.bootstrap_rexx_package_space(_rexx_path, str(ROOT/"rexx"/"animals.cls"))

from objects import RexxStem

stem = RexxStem.new()

print("stem-NAME:", stem["NAME"])
print("stem-SPECIES:", stem["SPECIES"])
print("stem-compound-FOOD.1:", stem["FOOD.1"])
assert stem["NAME"] == "Monty"
assert stem["SPECIES"] == "parrot"
assert stem["FOOD.1"] == "biscuit"
assert stem["FOOD.2"] == "seed"

# Python mutates the retained Rexx Stem rather than a copied dict.
stem["NAME"] = "Polly"
stem["FOOD.3"] = "apple"

print("python-wrote-NAME:", stem["NAME"])
print("python-wrote-FOOD.3:", stem["FOOD.3"])
assert stem["NAME"] == "Polly"
assert stem["FOOD.3"] == "apple"

print("PYTHON <-> REAL OOREXX STEM POC PASS")
