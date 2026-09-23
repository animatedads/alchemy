from pathlib import Path
import _rexxpython_poc as native

ROOT = Path(__file__).resolve().parent.parent
ANIMAL_FACTORY = str(ROOT / "rexx" / "factory.rex")
FOREIGN_FACTORY = str(ROOT / "rexx" / "foreign_factory.rex")

class PythonAnimal:
    def __init__(self, name, species):
        self.name, self.species = name, species
        self.calls = []

    def describe(self):
        self.calls.append("describe")
        return f"{self.name} is a Python {self.species}"

    # There is intentionally no corresponding method on PythonObjectProxy.
    def midnightSnack(self):
        self.calls.append("midnightSnack")
        return f"{self.name} wants a biscuit"

rex_animal = native.create_animal(ANIMAL_FACTORY, "Mog", "cat", "miaow")
collection = native.create_collection(ANIMAL_FACTORY)
py_animal = PythonAnimal("Monty", "parrot")
py_proxy, py_handle = native.wrap_python_object(py_animal, FOREIGN_FACTORY, {"MIDNIGHT_SNACK": "midnightSnack"})
try:
    assert int(native.send1_handle(collection, "ADD", rex_animal)) == 1
    assert int(native.send1_handle(collection, "ADD", py_proxy)) == 2

    # DESCRIPTIONTEXT sends DESCRIBE to each member.  The Python proxy has no
    # DESCRIBE method, so ooRexx invokes UNKNOWN and Python's describe().
    text = native.send0(collection, "DESCRIPTIONTEXT")
    assert text == "Mog is a cat | Monty is a Python parrot"

    # Send a completely arbitrary message directly to the Rexx proxy.  Again,
    # only UNKNOWN exists on the Rexx side.
    snack = native.send0(py_proxy, "MIDNIGHT_SNACK")
    assert snack == "Monty wants a biscuit"

    # Now let ooRexx itself evaluate ~~.  Python midnightSnack() returns a
    # string, but ooRexx ~~ must discard that result and return the original
    # PythonObjectProxy.  Rexx immediately sends DESCRIBE to that returned
    # receiver, proving identity/chaining survived the foreign UNKNOWN call.
    double_tilde = native.send0(collection, "DOUBLETILDEPROBE")
    assert double_tilde == "1|Monty is a Python parrot"
    assert py_animal.calls == ["describe", "midnightSnack", "midnightSnack", "describe"]

    print("mixed-oorexx-collection:", text)
    print("unknown-message-return:", snack)
    print("double-tilde-returned-receiver:", double_tilde)
    print("python-methods-called:", py_animal.calls)
    print("UNKNOWN + DOUBLE-TILDE POC PASS")
finally:
    native.release_handle(py_proxy)
    native.release_handle(collection)
    native.release_handle(rex_animal)
    native.release_python_object(py_handle)
