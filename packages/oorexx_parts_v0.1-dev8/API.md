# API v0.1-dev2

`PartDefinition~new(id,family,description,parameters,materials,geometry,manufacturing,provenance,modelGrade)`

`PartDefinition~parameter(name)` — required named parameter, fail-closed.

`PartDefinition~material(role)` — material catalogue reference/name for a physical role.

`CommonParts~resistor(...)`, `~capacitor(...)`, `~diode1N4148`, `~diode1N4007`, `~ledRed5mm`, `~zener5V1`, `~standardBenchSet`.

The engineering extension adds `~metricBolt(size,length,materialId)`,
`~boltM6x30`, `~plateAl6061T6`, `~bearing608`
and `~heatsinkTO220`, each carrying dimensional, material and manufacturing
metadata suitable for deterministic downstream checks.

`RexxTronicsPartFactory~instantiate(definition,instanceId)` projects supported catalogue definitions into Rexx-tronics component objects. Behaviour remains owned by Rexx-tronics.


## Assembly API (dev6)

- `PartInterface`
- `AssemblyMember`
- `AssemblyConnection`
- `PartAssembly`
- `CommonPartInterfaces`
- `CommonAssemblies`
- `ManufacturedPartProjection`

An assembly composes existing definitions; it does not create a new physical-law
authority. `ManufacturedPartProjection` keeps the originating definition stable
while an external manufacturing/physics state reference evolves independently.
