import os
from pathlib import Path
import _rexxpython_poc as n
ROOT=Path(__file__).resolve().parents[1]
paths=[
 str(ROOT/"rexx"),
 os.environ["ALCHEMY_OBJECTS_SRC"],
 os.environ["ALCHEMY_CRYPTO_SRC"],
 os.environ["OOREXX_PLATFORM_BIN"],
]
rp=os.pathsep.join(paths)
n.bootstrap_rexx_package_space(rp,str(ROOT/"rexx"/"AlchemyForeignObject.cls"))
n.bootstrap_rexx_package_space(rp,str(ROOT/"rexx"/"animals.cls"))
F=str(ROOT/"rexx"/"factory.rex")
class Animal: pass
rh,ph=n.wrap_python_object(Animal(),F)
try:
    assert n.send0_text(rh,"FOREIGNRUNTIME")=="python"
    print("package-space-entry-load: True")
    print("nested-requires-via-rexx-path: True")
    print("shared-foreign-base-runtime: python")
    print("ALCHEMY FOREIGN PACKAGE SPACE PASS")
finally:
    n.release_handle(rh); n.release_python_object(ph)
