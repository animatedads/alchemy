import _rexxpython_poc as native
from objects import OMITTED

class Receiver:
    def receive_slots(self, *values):
        labels = (
            "OMITTED" if values[0] is OMITTED else "BAD",
            "NIL" if values[1] is None else "BAD",
            "EMPTY" if values[2] == "" else "BAD",
            "VALUE:" + values[3],
        )
        print("rexx-slots->python:", "|".join(labels))
        print("python-types:", ["OMITTED", type(values[1]).__name__, type(values[2]).__name__, type(values[3]).__name__])
        return "|".join(labels)

receiver = Receiver()
h = native.retain_python_object(receiver)
try:
    result = native.rexx_slots_to_python(h, OMITTED)
    assert result == "OMITTED|NIL|EMPTY|VALUE:hello"
    print("REXX -> PYTHON OMITTED != NIL != EMPTY POC PASS")
finally:
    native.release_python_object(h)
