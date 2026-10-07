import os
from pathlib import Path
import _rexxpython_poc as _bootstrap_native
_ROOT = Path(__file__).resolve().parents[1]
_required = ["ALCHEMY_OBJECTS_SRC","ALCHEMY_CRYPTO_SRC","OOREXX_PLATFORM_BIN"]
_missing = [k for k in _required if not os.environ.get(k)]
if _missing: raise RuntimeError("test requires package-space environment: " + ", ".join(_missing))
_rp = os.pathsep.join([str(_ROOT/"rexx"),os.environ["ALCHEMY_OBJECTS_SRC"],os.environ["ALCHEMY_CRYPTO_SRC"],os.environ["OOREXX_PLATFORM_BIN"]])
_bootstrap_native.bootstrap_rexx_package_space(_rp,str(_ROOT/"rexx"/"animals.cls"))
import _rexxpython_poc as native
from pathlib import Path

FACTORY = str(Path(__file__).resolve().parents[1] / "rexx" / "factory.rex")

class PythonTarget:
    def pythononly(self):
        return "PYTHON-ONLY"

    def unknown(self):
        return "PYTHON-LITERAL-UNKNOWN"

target = PythonTarget()
ph = native.retain_python_object(target)
rh = native.create_unknown_collision(FACTORY)
try:
    before = native.send0_text(rh, "SOMETHINGELSE")
    print("before-projection-fallback:", before)
    assert before == "ORIGINAL-UNKNOWN:SOMETHINGELSE:0"

    alias = native.install_unknown_projection(rh, ph, "PYTHONONLY UNKNOWN")
    print("relocated-original-unknown:", alias)

    known = native.send0_text(rh, "KNOWN")
    projected = native.send0_text(rh, "PYTHONONLY")
    fallback = native.send0_text(rh, "SOMETHINGELSE")
    print("known-rexx-method:", known)
    print("projected-python-method:", projected)
    print("post-projection-fallback:", fallback)

    assert known == "REXX-KNOWN"
    assert projected == "PYTHON-ONLY"
    assert fallback == "ORIGINAL-UNKNOWN:SOMETHINGELSE:0"
    print("EXISTING UNKNOWN RELOCATION + RESERVED-SELECTOR POC PASS")
finally:
    native.release_handle(rh)
    native.release_python_object(ph)
