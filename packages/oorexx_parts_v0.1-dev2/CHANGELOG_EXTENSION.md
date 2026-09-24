# Parts catalogue extension

The catalogue now includes four useful non-electronic engineering parts:

- `BOLT-M6X30-8.8`
- `PLATE-AL6061T6-100X50X3`
- `BEARING-608-2RS`
- `HEATSINK-TO220-12KW`

They retain dimensions, material roles and manufacturing metadata rather than
being anonymous labels. `tests/test_extension_catalog.rex` proves their family,
ratings and deterministic reference values. The existing Rexx-tronics factory
tests remain green with Rexx-tronics v0.1-dev15.
