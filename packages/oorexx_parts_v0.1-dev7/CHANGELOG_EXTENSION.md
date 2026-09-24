# Parts catalogue extension

The catalogue now includes four useful non-electronic engineering parts:

- `BOLT-M6X30-8.8`
- `PLATE-AL6061T6-100X50X3`
- `BEARING-608-2RS`
- `HEATSINK-TO220-12KW`

`boltM6x30(materialId)` now resolves a material definition and exposes the
reference `HEAD_SHEAR_STRESS` and `HEAD_SHEAR_CAPACITY` values. The bench set
contains steel 8.8, stainless 304 and aluminium 6061-T6 variants. The capacity
model is deliberately explicit: `0.6 * material_yield_stress * 138.56 mm2`.

They retain dimensions, material roles and manufacturing metadata rather than
being anonymous labels. `tests/test_extension_catalog.rex` proves their family,
ratings and deterministic reference values. The existing Rexx-tronics factory
tests remain green with Rexx-tronics v0.1-dev15.
