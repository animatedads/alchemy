# ooRexx Instrumentation Mesh / Keynote NOC Gopher Sphere v0.1

Authoritative engineering continuity for the estate-wide operational observation plane implemented by **Instrumentation Mesh** and consumed first by **Wire3D / Keynote 3D NOC**.

This sphere exists because many component spheres reference `instrumentation.mesh/0.1`; it owns continuity for that common observation language without taking authority from the services that publish into it.

## Verified implementation baseline

- Instrumentation Mesh: `oorexx_instrumentation_mesh_v0.1-dev8.zip`
- Instrumentation archive SHA-256: `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`
- API: `instrumentation.mesh/0.1`
- Exact dev8 source tree: `packages/oorexx_instrumentation_mesh/`
- Source provenance: imported from the qualified dev8 archive after verifying the archive digest and every entry in its `SHA256SUMS.txt`.
- Qualification carried by that delivery: Open Object Rexx 5.3.0 r13196 Internal Test Version, evidence dated 2026-10-11.
- **No new 2026-10-27 runtime qualification is implied by the source publication.** Current producer/live-mesh requalification remains an explicit gate.

## Current Library reconciliation — 2026-10-27

- `oorexx_instrumentation_intentions_v0.1-dev2` is present and its qualification retains the read-only/non-authority boundary while adding events/correlation and relationships/freshness coverage.
- `oorexx_storage_fabric_instrumentation_mesh_v0.1-dev7` is present. Its current line consumes the exact Instrumentation Mesh dev8 contract and continues the AFTER-success Storage observation boundary.
- The exact `oorexx_wire3d_v0.1-dev29.25-collector-join` archive still was not resolved by the Library search performed for this update. Wire3D dev29.23 therefore remains the last Keynote/NOC package inspected by this sphere, **not** a claim that dev29.23 is globally latest.
- Wire3D reconciliation is coordinated through its existing Rasen Falcon lane rather than by editing that component from the Instrumentation lane.

## Verified Keynote/NOC consumer

- Package: `oorexx_wire3d_v0.1-dev29.23-instrumentation-correlation.zip`
- SHA-256: `dd34cdca59399b6bc95aef87adf69eb7f21b97793016298be45cc152ccfcb821`
- Status: last package directly inspected in this workstream; later collector-join reconciliation remains open.

## Governing boundary

Instrumentation is **observation and management carriage**, not service authority.

The estate service/fabric owns operational truth. Instrumentation owns common observation vocabulary, publication fencing, bounded retention/query, explicit correlation grouping and the authenticated management envelope. Queue Fabric/XTP owns transport and peer authentication. Wire3D/Keynote owns projection only.

Rendering, grouping, freshness assessment or correlation never grants the NOC authority to mutate the observed object. Instrumentation does not replace Alchemy Log, incident/change authority, deployment authority, topology authority, or service-specific control.

## Rasen Falcon coordination

The owning project lane is `instrumentation-mesh`, authenticated as `CHATGPT`. The Wire3D/Keynote implementation remains in its existing separate lane; cross-component work is coordinated by immutable requests rather than taking ownership of that lane.

## Start here

Read the sphere articles in this order:

1. `instrumentation-mesh.authority`
2. `instrumentation-mesh.contract`
3. `instrumentation-mesh.keynote-noc`
4. `instrumentation-mesh.continuation`
5. `qual.instrumentation-mesh.current`

Source publication and remaining runtime/reconciliation gates are tracked explicitly in `MISSING_WORK.md`.
