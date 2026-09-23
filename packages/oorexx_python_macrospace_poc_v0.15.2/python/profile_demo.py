from pathlib import Path
import _rexxpython_poc as native
from projection import make_profile, wrap_projected

ROOT = Path(__file__).resolve().parent.parent
FOREIGN_FACTORY = str(ROOT / "rexx" / "foreign_factory.rex")

class PythonAnimal:
    def __init__(self, name):
        self.name = name

    def describe(self) -> str:
        return f"{self.name} is a Python animal"

    def feed(self, food: str, count: int) -> str:
        return f"{self.name} ate {count} {food}s"

    def makeFriend(self):
        return self.friend

    def identity(self) -> str:
        return self.name

monty = PythonAnimal("Monty")
polly = PythonAnimal("Polly")
monty.friend = polly
polly.friend = monty

# Same capability shape, different object identity.
monty_discovered = make_profile(monty)
polly_discovered = make_profile(polly)
assert monty_discovered["fingerprint"] == polly_discovered["fingerprint"]

# Normal case: discovery plus an explicit Rexx-facing spelling override.
proxy, handle, profile = wrap_projected(
    native, monty, FOREIGN_FACTORY,
    settings={"MAKE_FRIEND": {"python": "makeFriend", "returns": "object"}},
    mode="override",
)
try:
    assert native.send0(proxy, "DESCRIBE") == "Monty is a Python animal"
    assert native.send2_string_int(proxy, "FEED", "biscuit", 2) == "Monty ate 2 biscuits"
    friend_proxy = native.send0_handle(proxy, "MAKE_FRIEND")
    try:
        assert native.send0(friend_proxy, "IDENTITY") == "Polly"
    finally:
        native.release_handle(friend_proxy)
finally:
    native.release_handle(proxy)
    native.release_python_object(handle)

# Forced mode: expose only the manually declared projection, regardless of what
# else Python introspection can see.  This is the escape hatch for awkward APIs.
forced = make_profile(monty, {
    "WHO": {"python": "identity", "min_args": 0, "max_args": 0, "returns": "str"},
}, mode="forced")
assert list(forced["methods"]) == ["WHO"]
proxy2, handle2 = native.wrap_python_object(monty, FOREIGN_FACTORY, {"WHO": "identity"})
try:
    assert native.send0(proxy2, "WHO") == "Monty"
finally:
    native.release_handle(proxy2)
    native.release_python_object(handle2)

print("discovered-methods:", sorted(monty_discovered["methods"]))
print("profile-fingerprint:", monty_discovered["fingerprint"])
print("same-profile-different-objects:", monty_discovered["fingerprint"] == polly_discovered["fingerprint"] and monty is not polly)
print("override-MAKE_FRIEND:", profile["methods"]["MAKE_FRIEND"])
print("forced-methods:", sorted(forced["methods"]))
print("METHOD PROFILE DISCOVERY + OVERRIDE + FORCED POC PASS")
