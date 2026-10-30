# ooRexx Instrumentation Mesh / Keynote NOC Gopher Sphere v0.1

Authoritative engineering continuity for the estate-wide operational observation plane implemented by **Instrumentation Mesh** and consumed first by **Wire3D / Keynote 3D NOC**.

This sphere owns continuity for the common `instrumentation.mesh/0.1` observation language without taking authority from the services that publish into it.

## Verified implementation baseline

- Instrumentation Mesh: `oorexx_instrumentation_mesh_v0.1-dev8.zip`
- Instrumentation archive SHA-256: `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`
- API: `instrumentation.mesh/0.1`
- Exact dev8 source tree: `packages/oorexx_instrumentation_mesh/`
- Source publication commit: `311d31608c7ab48fc55a4df9d0b97d54ec00b7a7`
- Source provenance: exact qualified archive, archive digest and all `SHA256SUMS.txt` entries verified before import.
- Carried qualification runtime: Open Object Rexx 5.3.0 r13196 Internal Test Version, evidence dated 2026-10-11.
- **A fresh 2026-10-29 full r13196 Mesh run is not claimed.** The current container did not contain a materializable r13196 runtime.

## Current Library/Git reconciliation — 2026-10-29

- `oorexx_instrumentation_intentions_v0.1-dev2`: exact vendored Mesh dev8 core source hashes verified; read-only events/correlation, relationships and freshness boundary retained.
- Library `oorexx_storage_fabric_instrumentation_mesh_v0.1-dev8`: exact Mesh dev8 version/hash pin and explicit-correlation contract PASS. Git is ahead with `packages/oorexx_storage_fabric_instrumentation_mesh_v0.1-dev9/`, which still pins the same exact Mesh dev8 contract and adds the StoragePeer repair-source path.
- `oorexx_ldap_identity_v0.1-dev22`: Mesh/correlation adapter surface PASS static compatibility; its own fresh r13196/live LDAPS deployment gates remain unclaimed.
- `oorexx_https_server_v0.4.8`: Instrumentation adapter/source-shape static contract PASS; its package likewise does not claim a fresh v0.4.8 r13196 runtime run.
- `rexxos_rto2_grid_v0.1-dev16-identity-increment`: five static identity-contract tests PASS; the increment does not alter the existing Grid Instrumentation producer contract.
- Exact `oorexx_wire3d_v0.1-dev29.25-collector-join` still does not resolve in the Library search. Wire3D dev29.23 remains the last Keynote/NOC package directly inspected by this sphere, not a claim that it is globally latest.

Detailed evidence and a reusable checker are under `qualification/CURRENT_PRODUCER_COMPATIBILITY_2026-10-29.md` and `qualification/check_current_producers.py`.

## Verified Keynote/NOC consumer

- Package: `oorexx_wire3d_v0.1-dev29.23-instrumentation-correlation.zip`
- SHA-256: `dd34cdca59399b6bc95aef87adf69eb7f21b97793016298be45cc152ccfcb821`
- Status: last package directly inspected in this workstream; later collector-join reconciliation remains open in the Wire3D owner lane.

## Governing boundary

Instrumentation is **observation and management carriage**, not service authority.

The estate service/fabric owns operational truth. Instrumentation owns common observation vocabulary, publication fencing, bounded retention/query, explicit correlation grouping and the authenticated management envelope. Queue Fabric/XTP owns transport and peer authentication. Wire3D/Keynote owns projection only.

Rendering, grouping, freshness assessment or correlation never grants the NOC authority to mutate the observed object. Instrumentation does not replace Alchemy Log, incident/change authority, deployment authority, topology authority, or service-specific control.

## Rasen Falcon coordination

The owning project lane is `instrumentation-mesh`, authenticated as `CHATGPT`. The lane links both `oorexx_instrumentation_mesh` and `oorexx_instrumentation_mesh_gopher_sphere`. Wire3D/Keynote remains in its separate existing lane; cross-component work is coordinated by immutable requests rather than taking ownership of that lane.

## Start here

Read the sphere articles in this order:

1. `instrumentation-mesh.authority`
2. `instrumentation-mesh.contract`
3. `instrumentation-mesh.keynote-noc`
4. `instrumentation-mesh.continuation`
5. `qual.instrumentation-mesh.current`

Remaining runtime/reconciliation gates are tracked explicitly in `MISSING_WORK.md`.
