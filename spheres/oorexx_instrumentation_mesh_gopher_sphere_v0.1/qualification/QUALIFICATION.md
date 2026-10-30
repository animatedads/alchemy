# Qualification record

Date: 2026-10-29

This sphere separates **release qualification**, **source publication**, and **current producer compatibility**. It does not convert one into another.

## Mesh release/source evidence

- archive: `oorexx_instrumentation_mesh_v0.1-dev8.zip`
- SHA-256: `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`
- API: `instrumentation.mesh/0.1`
- exact source: `packages/oorexx_instrumentation_mesh/`
- source publication commit: `311d31608c7ab48fc55a4df9d0b97d54ec00b7a7`
- carried runtime evidence: ooRexx 5.3.0 r13196, package evidence dated 2026-10-11.

## 2026-10-29 current producer compatibility

See `CURRENT_PRODUCER_COMPATIBILITY_2026-10-29.md`.

PASS source/static compatibility for:

- Instrumentation Intentions v0.1-dev2 exact Mesh dev8 vendored source hashes;
- Library Storage Instrumentation v0.1-dev8 exact Mesh dev8 pin and boundary tests;
- HTTPS Server v0.4.8 Instrumentation adapter/source-shape contract;
- LDAP Identity v0.1-dev22 Mesh/correlation adapter surface and credential-field guard;
- RexxOS RTO2 Grid v0.1-dev16 identity increment five-test static contract and scope isolation.

Repository inspection additionally finds
`packages/oorexx_storage_fabric_instrumentation_mesh_v0.1-dev9/`, newer than
the materialized Library dev8 package, still pinned to the exact Mesh dev8
version/hash. That is repository compatibility evidence, not an execution claim.

## Keynote / Wire3D

Last directly inspected consumer in this sphere:

- `oorexx_wire3d_v0.1-dev29.23-instrumentation-correlation.zip`
- SHA-256 `dd34cdca59399b6bc95aef87adf69eb7f21b97793016298be45cc152ccfcb821`

The exact `dev29.25 collector-join` archive still did not resolve in the
2026-10-29 Library search. Reconciliation remains in the separate Wire3D owner lane.

## NOT CLAIMED

- fresh 2026-10-29 full Mesh suite under an exact mounted r13196 runtime;
- fresh live multi-node QueueRexx/XTP MANAGEMENT-route qualification;
- live LDAPS/HTTPS deployment acceptance;
- runtime requalification of Queue, Memory, SMTP, IMAP, MVS Alchemy, SIP/RTP,
  NoSQLServer and remaining application/deployment producers;
- Wire3D dev29.25 runtime inspection.

The compatibility environment had no materializable exact r13196 runtime. That
absence is recorded as an evidence boundary, not converted into a PASS or failure.
