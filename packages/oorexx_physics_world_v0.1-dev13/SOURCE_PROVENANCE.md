# Source provenance — ooRexx Physics World v0.1-dev10

## Immediate baseline

Dev9 is based directly on generated Physics World v0.1-dev8:

- `oorexx_physics_world_v0.1-dev8.zip`
- SHA-256 `08f6a7c40b27c8b0612df7e5e8ec5def8369725a0379e4aaec9aea5610121c07`

Dev8 itself is based on the user-supplied dev7 tree and introduced reciprocal electromechanical transduction. Dev9 retains that code and all earlier optics, mechanics, deformable, fluids, free-surface and acoustic behavior, then adds continuous driven radiation and thermal state.

## External authorities retained

- user-supplied ooRexx Maths v0.8 — SHA-256 `a28fdc39d375b5fa871fd229ee30ddcf2cdc3f2ee0c4e65861ad4907876d0793`;
- user-supplied ooRexx Units v0.1-dev4 — SHA-256 `b0916df3d8b68f1681f219e0e8770e490a6f7c00165cc5959b84d14354d4fa46`;
- ooRexx 5.3.0 r13196 remains the qualification runtime baseline.

## Dev9-authored work

Dev9 adds:

- `rexx/DrivenAcoustics.cls`;
- `rexx/Thermal.cls`;
- continuous actual-mechanics radiating-patch history and retarded pressure rendering;
- lumped thermal nodes, explicit heat-power evidence, conduction, convection and radiation;
- focused qualification fixtures and two examples;
- documentation/manifest/validation updates.

No Python physics solver is part of the delivered package. Physics continues to consume, not fork, Maths and Units.


## Dev10 merge provenance

Dev10 is based directly on the user-supplied current Physics authority:

- `oorexx_physics_world_v0.1-dev9(1).zip`
- SHA-256 `89b83dee9fda3566291ac41b4a097db1ce3afbc318c3daf47762b346b8c0e5bd`

That dev9 tree is retained for optics, rigid/deformable mechanics, contact, acoustics, driven acoustics, thermal, electromechanics, fluid foundations, one-axis free-surface behavior and vessel dynamics. Dev10 merges only the parallel two-axis slosh work into that authority:

- `rexx/FreeSurfaceFluids2D.cls`;
- `examples/sloshing_tank_2d.rex`;
- five focused `test_free_surface_2d_*.rex` fixtures;
- documentation, manifest and validation updates.

The source of those files is the previously generated parallel Physics slosh branch `oorexx_physics_world_v0.1-dev9.zip` (SHA-256 `954658888862b27bba47dd4e68568da41961cfafcd959966a2b30532a98909e9`). No existing dev9 Physics source module was replaced to perform the merge.


## dev11
Derived directly from the reconciled Physics World v0.1-dev10.1 authority (SHA-256 `936737a18d2c96a627e86d322b3dbf6bda06134a2410fc7eafb58c750cf6cc3c`). Adds fracture-aware fluid containment while retaining Maths v0.8 and Units v0.1-dev4 as external authorities.


## dev12
Derived directly from Physics World v0.1-dev11 (SHA-256 `5a06eeec80396c655ecafbbb341858ec5a1801139098036349ca29ef299f9478`). Adds conservative external escaped-fluid parcel mechanics; Maths v0.8 and Units v0.1-dev4 remain external authorities.


## dev13
Derived directly from Physics World v0.1-dev12 (SHA-256 `0227307d965d62122e49133197e04e4153b05da57b61897970f4cb02f2d1f627`). The uploaded Parts v0.1-dev1 package was inspected for boundary context only; dev13 does not copy or absorb the parts catalogue. Maths v0.8 and Units v0.1-dev4 remain external authorities.
