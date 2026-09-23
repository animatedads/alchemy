import _rexxpython_poc as native
from objects import FACTORY

class PythonProjection:
    def __init__(self):
        self.calls = []

    def pythononly(self):
        self.calls.append("pythononly")
        return "PYTHON-ONLY"

    # Deliberate collision with ooRexx's protocol method name.
    def unknown(self):
        self.calls.append("unknown")
        return "PYTHON-LITERAL-UNKNOWN"

target = PythonProjection()
pyh = native.retain_python_object(target)

# Profile names are Rexx-message canonical names for this bounded POC.
rh = native.create_existing_unknown(FACTORY, pyh, "PYTHONONLY UNKNOWN")

# Before overlay: prove the class's existing UNKNOWN is live.
before = native.send0_text(rh, "SOMETHINGELSE")
print("before-projection-fallback:", before)
assert before == "ORIGINAL-UNKNOWN:SOMETHINGELSE:0"

alias = native.install_unknown_projection(rh)
print("relocated-original-unknown:", alias)
assert alias.startswith("!PYBRIDGE_ORIGINAL_UNKNOWN_")

known = native.send0_text(rh, "KNOWN")
projected = native.send0_text(rh, "PYTHONONLY")
fallback = native.send0_text(rh, "SOMETHINGELSE")
literal_unknown = native.send0_text(rh, "UNKNOWN")

print("existing-known:", known)
print("python-projected:", projected)
print("original-unknown-fallback:", fallback)
print("literal-python-unknown:", literal_unknown)
print("python-calls:", target.calls)

assert known == "REXX-KNOWN"
assert projected == "PYTHON-ONLY"
assert fallback == "ORIGINAL-UNKNOWN:SOMETHINGELSE:0"
assert literal_unknown == "PYTHON-LITERAL-UNKNOWN"
assert target.calls == ["pythononly", "unknown"]

print("EXISTING UNKNOWN RELOCATION + FORWARDING POC PASS")
