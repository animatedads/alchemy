from pathlib import Path
import _rexxpython_poc as native
ROOT = Path(__file__).resolve().parent.parent
ANIMAL_FACTORY = str(ROOT / "rexx" / "factory.rex")
FOREIGN_FACTORY = str(ROOT / "rexx" / "foreign_factory.rex")

class PythonAnimal:
    def __init__(self, name, species, sound):
        self.name, self.species, self.sound = name, species, sound
        self.describe_calls = 0
    def describe(self):
        self.describe_calls += 1
        return f"{self.name} is a Python {self.species}"
    def speak(self):
        return f"{self.name} Python-says {self.sound}"

rex_animal = native.create_animal(ANIMAL_FACTORY, "Mog", "cat", "miaow")
collection = native.create_collection(ANIMAL_FACTORY)
py_animal = PythonAnimal("Monty", "parrot", "squawk")
py_proxy, py_handle = native.wrap_python_object(py_animal, FOREIGN_FACTORY)
try:
    assert int(native.send1_handle(collection, "ADD", rex_animal)) == 1
    assert int(native.send1_handle(collection, "ADD", py_proxy)) == 2
    # AnimalCollection itself performs animal~describe for every member.
    # Member 1 is a genuine ooRexx Animal. Member 2 is a Rexx proxy retaining
    # the identity of the live Python object and calls back into its method.
    text = native.send0(collection, "DESCRIPTIONTEXT")
    print("mixed-oorexx-collection:", text)
    print("python-describe-call-count:", py_animal.describe_calls)
    assert text == "Mog is a cat | Monty is a Python parrot"
    assert py_animal.describe_calls == 1
    print("MIXED OBJECT COLLECTION POC PASS")
finally:
    native.release_handle(py_proxy)
    native.release_handle(collection)
    native.release_handle(rex_animal)
    native.release_python_object(py_handle)
