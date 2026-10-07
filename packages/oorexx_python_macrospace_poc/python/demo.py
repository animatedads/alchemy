from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import _rexxpython_poc

class PythonAlarmReceiver:
    def __init__(self):
        self.events = []

    def on_alarm(self, message):
        print(f"python-object-method: PythonAlarmReceiver.on_alarm({message!r})")
        self.events.append(message)
        return f"ACK:{len(self.events)}"

receiver = PythonAlarmReceiver()
result = _rexxpython_poc.run_demo(
    receiver,
    "on_alarm",
    str(ROOT / "rexx" / "demo.rex"),
    str(ROOT / "rexx" / "pyalarm.rex"),
)
print("bridge-result:", result)
assert receiver.events == ["The animals would like breakfast"]
assert result["result"] == "DEMO_OK"
print("POC PASS")
