import _rexxpython_poc as native
from objects import PythonArgumentReceiver, OMITTED, FACTORY

receiver = PythonArgumentReceiver()
py_handle = native.retain_python_object(receiver)
array_handle = native.create_slot_array(FACTORY)

result = native.rexx_slots_to_python(py_handle, array_handle, OMITTED)
print("rexx-slots->python:", result)
print("python-types:",
      ["OMITTED" if v is OMITTED else "NoneType" if v is None else type(v).__name__
       for v in receiver.last])

assert receiver.last[0] is OMITTED
assert receiver.last[1] is None
assert receiver.last[2] == ""
assert receiver.last[3] == "hello"
assert result == "OMITTED|NIL|EMPTY|VALUE:hello"

print("REXX -> PYTHON OMITTED != NIL != EMPTY POC PASS")
