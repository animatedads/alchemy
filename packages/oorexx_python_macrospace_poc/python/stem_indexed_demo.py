import os
from pathlib import Path
import _rexxpython_poc as n
R=Path(__file__).resolve().parents[1]
rp=os.pathsep.join([str(R/"rexx"),os.environ["ALCHEMY_OBJECTS_SRC"],os.environ["ALCHEMY_CRYPTO_SRC"],os.environ["OOREXX_PLATFORM_BIN"]])
n.bootstrap_rexx_package_space(rp,str(R/"rexx"/"animals.cls"))
from objects import RexxStem, FACTORY
s=RexxStem.new()
assert len(s)==2
assert list(s)==["biscuit","seed"]
s.append("apple")
assert len(s)==3 and s["0"]=="3" and s["3"]=="apple"
# completely bridge-unaware Rexx class consumes the same retained Stem using .0 + 1..n
result=n.consume_stem_rexx(s._handle,FACTORY)
print("python-indexed-stem:",list(s))
print("rexx-unaware-consumer:",result)
assert result=="3:biscuit|seed|apple"
print("INDEXED REAL OOREXX STEM ROUNDTRIP PASS")
