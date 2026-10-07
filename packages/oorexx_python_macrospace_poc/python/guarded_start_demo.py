from time import monotonic
from objects import GuardedAnimal

obj = GuardedAnimal.new("Monty")
print("python-created-rexx-guarded-object:", obj.name)
print("initial-gate-state:", obj.gate_state())

started = monotonic()
value = obj.guarded_value()
elapsed = monotonic() - started

print("guarded-return:", value)
print("elapsed-seconds:", f"{elapsed:.3f}")
print("final-gate-state:", obj.gate_state())

assert value == "Monty released after 4 ticks", value
# Four 0.10s Rexx-side sleeps should make a truly waiting Python->Rexx call
# visibly non-immediate, while leaving generous scheduler tolerance.
assert elapsed >= 0.20, elapsed
assert obj.gate_state().startswith("1:4"), obj.gate_state()
print("PYTHON -> GUARDED REXX METHOD + START LOOP POC PASS")
