from pathlib import Path
import _rexxpython_poc as native

ROOT = Path(__file__).resolve().parent.parent
FACTORY = str(ROOT / "rexx" / "foreign_factory.rex")

class PythonAnimal:
    def __init__(self, name, species):
        self.name = name
        self.species = species
        self.calls = 0
    def describe(self):
        self.calls += 1
        return f"{self.name} is a Python {self.species}"

class RexxHandle:
    def __init__(self, handle): self.handle = handle
    def close(self):
        if self.handle:
            native.release_handle(self.handle)
            self.handle = None

collection = RexxHandle(native.create_object_collection(FACTORY))
py_animal = PythonAnimal("Monty", "parrot")
proxy_handle, py_handle = native.wrap_python_object(py_animal, FACTORY)
proxy = RexxHandle(proxy_handle)

try:
    count = int(native.send1_handle(collection.handle, "ADD", proxy.handle))
    assert count == 1
    # Crucial path: Python asks only the collection.  ooRexx retrieves its stored
    # proxy and sends CALL('describe') to it; PYCALL then reaches Python.
    answer = native.send2_index_string(collection.handle, "CALLAT", 1, "describe")
    print("rexx-collection-count:", count)
    print("rexx-calls-python-object:", answer)
    print("python-method-call-count:", py_animal.calls)
    assert answer == "Monty is a Python parrot"
    assert py_animal.calls == 1
    print("OBJECT REVERSAL POC PASS")
finally:
    # The Rexx proxy is no longer used before releasing Python ownership.
    proxy.close()
    collection.close()
    native.release_python_object(py_handle)
