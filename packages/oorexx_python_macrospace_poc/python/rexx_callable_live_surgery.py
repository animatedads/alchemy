import os
from pathlib import Path
import _rexxpython_poc as n

ROOT = Path(__file__).resolve().parents[1]
rp = os.pathsep.join([
    str(ROOT / "rexx"),
    os.environ["ALCHEMY_OBJECTS_SRC"],
    os.environ["ALCHEMY_CRYPTO_SRC"],
    os.environ["OOREXX_PLATFORM_BIN"],
])
n.bootstrap_rexx_package_space(rp, str(ROOT / "rexx" / "animals.cls"))
FACTORY = str(ROOT / "rexx" / "factory.rex")

def state(handle):
    generation, present, wrapper = n.send0_text(handle, "TARGETSTATE").split(":", 2)
    return int(generation), present == "1", wrapper

h = n.create_live_rexx_target(FACTORY)
class Robot:
    pass

x = n.make_rexx_live_callable(h, "VALUE")
Robot.foo = x
r = Robot()

g1, present1, wrapper = state(h)
assert g1 == 1 and present1
assert r.foo() == "R1"
assert Robot.foo is x

n.send0_text(h, "SETR2")
g2, present2, wrapper2 = state(h)
assert (g2, present2, wrapper2) == (2, True, wrapper)
assert Robot.foo is x and r.foo() == "R2"

n.send0_text(h, "SETR3")
g3, present3, wrapper3 = state(h)
assert (g3, present3, wrapper3) == (3, True, wrapper)
assert Robot.foo is x and r.foo() == "R3"

# Semantic revocation is distinct from destroying the native object handle.
# The Python callable and Alchemy wrapper both survive, but the target cannot run.
n.send0_text(h, "REVOKEVALUE")
g4, present4, wrapper4 = state(h)
assert (g4, present4, wrapper4) == (4, False, wrapper)
assert Robot.foo is x
try:
    r.foo()
    raise AssertionError("semantically revoked callable unexpectedly ran")
except RuntimeError as e:
    assert "invocation failed" in str(e)

# Finally revoke native reachability too: the same Python callable now fails at
# handle admission, proving semantic revocation and lifetime revocation are separate.
n.revoke_rexx_handle(h)
try:
    r.foo()
    raise AssertionError("native-revoked callable unexpectedly ran")
except RuntimeError as e:
    assert "revoked Rexx callable" in str(e)

print("python-retains-same-callable-identity: True")
print("alchemy-wrapper-identity-stable-R1-R2-R3-revoked: True")
print("semantic-generations-1-2-3-4: True")
print("semantic-revocation-preserves-wrapper: True")
print("native-handle-revocation-remains-distinct: True")
print("REXX CALLABLE SHARED SEMANTIC TARGET PASS")
