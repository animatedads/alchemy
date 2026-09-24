# Materials catalogue extension

This working extension adds three deterministic engineering references:

- `PC-GENERIC` — density, heat capacity, conductivity, modulus and yield stress
- `CFRP-EPOXY-GENERIC` — density, thermal conductivity, modulus and expansion
- `CONCRETE-C30` — density, thermal conductivity, modulus and compressive strength

All values are explicitly marked as engineering references, not certificates.
`tests/test_extension_catalog.rex` proves identity, family and representative
property values through the Units v0.1-dev4 property path.
