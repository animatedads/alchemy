# Architecture

Authority boundary:

- Maths: numerical authority.
- Units: dimensional/quantity authority.
- Physics World: physical-law and physical-state authority.
- Materials: reusable substance/property catalogue authority.
- Common Parts: reusable part identity/configuration/rating catalogue authority.
- Rexx-tronics: electrical/electromechanical behaviour authority.
- Physical Manufacturing model: process/tooling/transformation authority.

A PartDefinition is therefore descriptive. It may identify material roles, geometry/package facts and manufacturing descriptors, but it does not implement Ohm's law, semiconductor equations, fracture, cutting, heat flow, or material removal.

## Manufacturing projection

`materials`, `geometry`, and `manufacturing` are explicit independent projections so a manufacturing model can resolve the same part definition into stock, package, leads, assembly/process and geometry without inventing a second part identity. A manufactured instance may change geometry/state/provenance while retaining the catalogue definition from which it originated.

## Fail closed

Unknown parameters raise an error. Unsupported Rexx-tronics families raise an error. A catalogue entry must never silently choose a behavioural model that the consumer does not support.
