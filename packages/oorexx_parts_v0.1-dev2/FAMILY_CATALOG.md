# Parameterised common-part families

This increment keeps `PartDefinition` as the catalogue identity. The
`CommonPartFamilies` helper only constructs existing `PartDefinition` objects;
it does not simulate them or mutate them.

Representative families currently covered are:

- metric fasteners M2 through M12, with 4.8/8.8/10.9/12.9 material classes;
- metric nuts and washers;
- deep-groove bearings 608, 6000–6002 and 6200–6204, with seal variants;
- round shafts, helical compression springs and derived spring rate;
- structural plates, involute spur gears, copper hookup wire, DIP packages and AA batteries.

Geometry is represented with `Units` quantities. Capacities, spring rate,
wire resistance, pitch diameter and stock mass are model-derived values. The
catalogue records representative/provenance grades and leaves deformation,
wear, fracture, cutting, circuit and battery behaviour to Physics World,
Physical Manufacturing and Rexx-tronics.

`tests/test_family_catalog.rex` resolves every material role in the
representative catalogue through `CommonMaterials~byId`; an unresolved ID
fails the test.
