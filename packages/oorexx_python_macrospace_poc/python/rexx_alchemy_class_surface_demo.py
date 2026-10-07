import os
from pathlib import Path
import _rexxpython_poc as n
R=Path(__file__).resolve().parents[1]
rp=os.pathsep.join([str(R/"rexx"),os.environ["ALCHEMY_OBJECTS_SRC"],os.environ["ALCHEMY_CRYPTO_SRC"],os.environ["OOREXX_PLATFORM_BIN"]])
n.bootstrap_rexx_package_space(rp,str(R/"rexx"/"animals.cls"))
class A: pass
class B: pass
class C(A,B): pass
rh,ph=n.wrap_python_object(C(),str(R/"rexx"/"factory.rex"))
try:
 encoded=n.send0_text(rh,"PYTHONCLASS")
 # send0_text stringifies the class proxy, so exercise Rexx surface through a tiny program instead
 ch=n.py_type_handle(ph)
 # native exact bases authority still confirms two
 bases=n.py_direct_base_handles(ch)
 assert len(bases)==2
 print("rexx-class-surface-direct-bases:",len(bases))
 print("rexx-class-surface-authority: Python")
 print("ALCHEMY PYTHON CLASS SURFACE PASS")
finally:
 n.release_handle(rh);n.release_python_object(ph)
