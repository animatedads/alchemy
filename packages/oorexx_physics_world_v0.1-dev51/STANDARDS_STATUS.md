# ooRexx standards status

Physics treats the ooRexx standards enforcer as a qualification gate, not a formatter.

The 2026-09-27 portfolio standards report for the dev47.1 merge recorded 181 ERROR and
164 WARN findings across inherited Physics source. The largest hard class was 117
PLUS_ZERO findings. In ooRexx, `x + 0` is a dispatched `"+"(0)` message, not a
primitive numeric cast. An object may override that message, mutate itself, return a
different object, raise a condition, or otherwise attach domain behaviour.

Policy from dev50.1 onward:
- arithmetic operators are used only when the physical or mathematical operation is intended;
- arithmetic is never used merely for coercion, copying, validation or canonicalisation;
- a standards finding is not silenced by replacing `+0` with another operator trick;
- caller-owned rich values retain object semantics until an owning Units/Maths/Foreign boundary explicitly converts them;
- adversarial objects are valid qualification fixtures for detecting accidental operator sends.

Dev50.1 removes the canonical `PhysicalWorld~simulationTime=` PLUS_ZERO coercion and adds
an adversarial regression. Remaining inherited findings are open debt; this document
does not claim package-wide standards PASS.
