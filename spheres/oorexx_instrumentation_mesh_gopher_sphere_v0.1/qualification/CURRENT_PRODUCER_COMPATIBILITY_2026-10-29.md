# Instrumentation Mesh current-producer compatibility — 2026-10-29

This is a **post-release compatibility check** for the source-published
`oorexx_instrumentation_mesh_v0.1-dev8` contract. It is not a new Mesh runtime
release and it is not a substitute for the still-open fresh r13196/live-mesh gate.

## Mesh baseline

- archive: `oorexx_instrumentation_mesh_v0.1-dev8.zip`
- SHA-256: `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`
- API: `instrumentation.mesh/0.1`
- exact source is present on GitHub under `packages/oorexx_instrumentation_mesh/`.

The compatibility checker re-verifies the archive digest and these exact core
source hashes before checking consumers/producers:

- `InstrumentationMesh.cls` — `18b798b082754cb722e1e0ba3e9a99e49e153e68a563e966315d0c181cc99370`
- `InstrumentationAnalysis.cls` — `69db791016f0479641cea3aafd771cc29a41b8ddea5e5ea2b15015a60d02ff9a`
- `InstrumentationCorrelation.cls` — `1b0be4a8dfc65caf7728cae70677a03aa5c70631b2d628eea67d152934739f0f`

## Library heads checked

### Instrumentation Intentions v0.1-dev2 — PASS

The dev2 delivery vendors byte-identical Mesh dev8 `InstrumentationMesh.cls`,
`InstrumentationAnalysis.cls`, and `InstrumentationCorrelation.cls`. Its read-side
source remains `instrumentation.intentions/0.1` and exposes events/correlation,
relationships and freshness without exposing Mesh command authority.

### Storage Fabric Instrumentation Mesh v0.1-dev8 — PASS

The materialized Library dev8 package pins Mesh version `0.1-dev8`, archive
SHA-256 `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`,
and explicit producer-supplied correlation semantics. Its package
`static_mesh_dev8_test.py` and core static boundary test both pass.

Git is ahead of that Library artifact: default-branch
`packages/oorexx_storage_fabric_instrumentation_mesh_v0.1-dev9/` adds the verified
StoragePeer repair-source path and still pins the same exact Mesh dev8 version/hash.
That Git inspection is source-contract evidence, not a claim that dev9 was executed here.

### HTTPS Server v0.4.8 — PASS static contract

The current HTTPS source still provides `HttpsInstrumentationAdapter`, immutable
`registerInstrumentation()`, and `instrumentationSnapshot()`. Its packaged
`test_instrumentation_adapter_static.sh` passes. The package itself explicitly says
fresh v0.4.8 r13196 runtime execution is not claimed; this sphere preserves that boundary.

### LDAP Identity v0.1-dev22 — PASS static contract

`LdapIdentityInstrumentationSource` still declares `instrumentation.mesh/0.1`,
`instrumentation.correlation/0.1`, `InstrumentationEventObserver` source events,
and the Mesh/service-adapter dependencies. The compatibility checker also guards
against credential/password/mailbox fields in executable adapter text.

LDAP dev22's own qualification states that its new Rasen Falcon deployment/service
boundary was source/static qualified but fresh ooRexx r13196 and live LDAPS acceptance
were not run in that construction container. This check does not widen that claim.

### RexxOS RTO2 Grid v0.1-dev16 identity increment — PASS scope isolation

The dev16 identity increment is a small authorization seam over the dev15 Grid line.
Its static five-test contract passes here. The changed Grid classes contain no
Instrumentation Mesh dependency or replacement producer path, so the increment does
not alter the existing Grid observation contract.

## Commands executed

The committed `qualification/check_current_producers.py` performs the cross-package
contract/hash checks. Additional package-owned static gates run during this review:

```text
PASS Instrumentation Mesh dev8 pin and explicit-correlation boundary
PASS static storage instrumentation boundary-hook contract
PASS HTTPS Instrumentation Mesh adapter static contract
PASS RTO2 dev16 identity increment static unittest suite (5 tests)
PASS Intentions exact vendored Mesh source hashes
PASS LDAP dev22 Mesh/correlation adapter surface and credential-field guard
```

## Not claimed / still required

- fresh execution of Mesh dev8's full ooRexx suite against an exact mounted r13196 runtime;
- live multi-node QueueRexx/XTP `MANAGEMENT` route publication/query/command;
- live LDAPS/HTTPS deployment acceptance;
- runtime requalification of the remaining producers (Queue, Memory, SMTP, IMAP,
  MVS Alchemy, SIP/RTP, NoSQLServer and application/deployment observers);
- Wire3D/Keynote dev29.25 collector-join reconciliation in the Wire3D owner lane.

The absence of a fresh runtime in the current container is recorded as an evidence
boundary, not converted into a PASS or a failure.
