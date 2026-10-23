# ooRexx Instrumentation Mesh / Keynote NOC Gopher Sphere v0.1

Authoritative engineering continuity for the estate-wide operational observation plane implemented by **Instrumentation Mesh** and consumed first by **Wire3D / Keynote 3D NOC**.

This sphere exists because many component spheres now reference `instrumentation.mesh/0.1`, but the observation plane itself previously had no owning continuity sphere in source control.

## Verified implementation baselines

- Instrumentation Mesh: `oorexx_instrumentation_mesh_v0.1-dev8.zip`
- Instrumentation SHA-256: `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`
- API: `instrumentation.mesh/0.1`
- Verified Keynote/NOC consumer: `oorexx_wire3d_v0.1-dev29.23-instrumentation-correlation.zip`
- Wire3D dev29.23 SHA-256: `dd34cdca59399b6bc95aef87adf69eb7f21b97793016298be45cc152ccfcb821`
- Qualification runtime used by the delivered packages: Open Object Rexx 5.3.0 r13196 Internal Test Version.

A later Wire3D `dev29.25 collector-join` is referenced by repository design material dated 2026-10-19, but that archive was not resolvable in the Library check performed for this sphere update. Therefore dev29.23 is the last package inspected here, not a claim that dev29.23 is globally latest.

## Governing boundary

Instrumentation is **observation and management carriage**, not service authority.

The estate service/fabric owns operational truth. Instrumentation owns common observation vocabulary, publication fencing, bounded retention/query, explicit correlation grouping and the authenticated management envelope. Queue Fabric/XTP owns transport and peer authentication. Wire3D/Keynote owns projection only.

Rendering, grouping, freshness assessment or correlation never grants the NOC authority to mutate the observed object.

## Start here

Read the sphere articles in this order:

1. `instrumentation-mesh.authority`
2. `instrumentation-mesh.contract`
3. `instrumentation-mesh.keynote-noc`
4. `instrumentation-mesh.continuation`
5. `qual.instrumentation-mesh.current`

The runtime package is not duplicated by this sphere. Source publication status and remaining gates are tracked explicitly in `MISSING_WORK.md`.
