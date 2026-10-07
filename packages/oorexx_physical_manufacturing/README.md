# ooRexx Physical Manufacturing v0.1-dev7

A process/tooling/transformation layer that treats manufacturing commands as inputs to finite physical machinery.

Dev7 preserves a finite extrusion as a sequence of deposited material elements.  The path is measured from actual nozzle/workpiece motion while deposition occurs.  Commanded feed length is retained separately, allowing stretching, compression, stationary accumulation and reversal to emerge as evidence rather than labels.

The current reduced-order machine still commits the completed bead into the growing workpiece as one thermal/mechanical section at its mass-weighted resolved coordinate.  Dev7 deliberately preserves the richer element path so subsequent deformable-material work can replace that reduction without reconstructing what happened.

## dev9 — manufacturing history is physical structure

The element-resolved path no longer collapses a finite bead to one centroid body. Every finite deposition interval becomes a separate mass-bearing Mechanics body with its own ThermalNode. Neighbouring elements are connected through the existing compliant manufactured-section chain, so later machine acceleration acts on the geometry and mass distribution actually produced by prior motion.

This is still a reduced-order bead model, not a continuum polymer solver. Element box cross-section is declared by the process; actual longitudinal motion, mass, timing, reversal and temperature history remain measured evidence. Stationary extrusion does not invent travel distance.


## dev9 standards/object-language review

The 2026-09-27 standards pass removes arithmetic `+ 0` coercion idioms and a non-short-circuit `&` conditional. Numeric validity remains enforced by the domain comparisons and strict argument contracts; values are not rewritten merely to force representation. The review also adopts the object-responsibility lesson from `family.rex`: manufactured elements retain their own material, thermal, geometry and history state, while process objects orchestrate operations rather than type-switching over flattened records.
