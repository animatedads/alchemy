# Architecture

Dependency floor: ooRexx 5.3 + Units v0.1-dev4.

`MaterialDefinition` is stable material identity plus named `MaterialProperty`
records. A property carries value, UnitDefinition, condition and provenance.

`PhysicsMaterialProjection` is an adapter only. Physics World remains behaviour
authority. A physical manufactured instance may evolve independently of its
catalogue definition; heating, wear, fracture or machining never mutates the
catalogue entry.

Parts should refer to material IDs/definitions rather than duplicating physical
constants.
