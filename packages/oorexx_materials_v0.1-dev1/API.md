# API

- `MaterialProperty`
- `MaterialDefinition`
- `MaterialBuilder`
- `CommonMaterials`
- `PhysicsMaterialProjection`

Important calls:
`CommonMaterials~catalog`, `~byId(id)`, `MaterialDefinition~property(name)`,
`~quantity(name)`, and Physics projections `~fluid`, `~thermal`, `~mechanical`,
`~optical`.

`PhysicsMaterialProjection.cls` is an optional adapter package and is deliberately
separate from the catalogue core so importing Materials alone does not import
Physics World.

The engineering extension adds reference definitions for `polycarbonate`,
`carbonFiberEpoxy` and `concreteC30`, including density, thermal and strength
properties with explicit units and reference-grade provenance.
