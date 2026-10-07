from pathlib import Path
import _rexxpython_poc as native

ROOT = Path(__file__).resolve().parent.parent
FOREIGN_FACTORY = str(ROOT / "rexx" / "foreign_factory.rex")

class PythonAnimal:
    def __init__(self, name):
        self.name = name
        self.calls = []
        self.friend = None

    def feed(self, food, count):
        self.calls.append(("feed", food, count, type(count).__name__))
        return f"{self.name} ate {count} {food}s"

    def makeFriend(self):
        self.calls.append(("makeFriend",))
        return self.friend

    def identity(self):
        self.calls.append(("identity",))
        return f"{self.name}:{id(self)}"

monty = PythonAnimal("Monty")
polly = PythonAnimal("Polly")
monty.friend = polly

proxy, monty_handle = native.wrap_python_object(
    monty, FOREIGN_FACTORY, {"MAKE_FRIEND": "makeFriend"}
)
friend_proxy = None
try:
    fed = native.send2_string_int(proxy, "FEED", "biscuit", 2)
    assert fed == "Monty ate 2 biscuits"
    assert monty.calls[0] == ("feed", "biscuit", 2, "int")

    # Python returns Polly, not a string. The native callback retains Polly and
    # returns an identity handle; Rexx UNKNOWN turns that into a new ordinary
    # PythonObjectProxy, which we retain here as a Rexx object handle.
    friend_proxy = native.send0_handle(proxy, "MAKE_FRIEND")
    identity = native.send0(friend_proxy, "IDENTITY")
    expected = f"Polly:{id(polly)}"
    assert identity == expected
    assert polly.calls == [("identity",)]

    print("argument-marshalling:", fed)
    print("python-feed-call:", monty.calls[0])
    print("returned-python-object:", identity)
    print("python-object-identity-preserved:", identity == expected)
    print("ARGUMENT + RETURN OBJECT POC PASS")
finally:
    if friend_proxy is not None:
        native.release_handle(friend_proxy)
    native.release_handle(proxy)
    native.release_python_object(monty_handle)
