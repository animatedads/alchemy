# API v0.1-dev7

Existing dev6 APIs remain available.

## Segmented deposition
- `DepositedPathElement`: start/end time and actual coordinate, mass, nominal feed length, material, temperature; derives actual/signed length, stretch ratio, line density and direction.
- `ResolvedDepositedBead`: ordered material elements; derives mass, actual/nominal path lengths, mass-weighted coordinate, extents and reversal count.
- `SegmentedDepositionBuilder`: deterministic builder from physical coordinate observations.
- `SegmentedFiniteDepositionProcess`: live bridge over `GrowingPrinterDynamics` + `ThermalDepositionProcess`.

`nominalLength` is command evidence only. It never replaces actual path geometry.

## dev8 element-resolved deposition

`ElementResolvedDepositionProcess~depositFor(...)` follows the finite deposition sampling contract of dev7 but commits each `DepositedPathElement` as a separate thermal/mechanical manufactured section. `sectionGroups` returns the physical section group corresponding to each retained bead.
