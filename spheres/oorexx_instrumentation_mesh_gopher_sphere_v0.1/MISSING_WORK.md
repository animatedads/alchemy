# Missing work / continuation gates

This file is deliberately conservative. A missing item is not implied complete merely because a dependent package references Instrumentation Mesh.

## Completed source-publication gate — 2026-10-27

The previous source-publication gap is closed on `main` by commit `311d31608c7ab48fc55a4df9d0b97d54ec00b7a7`:

- exact delivery: `oorexx_instrumentation_mesh_v0.1-dev8.zip`;
- archive SHA-256: `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`;
- archive digest and every `SHA256SUMS.txt` entry verified before import;
- exact runtime source, tests, package metadata and qualification evidence published under `packages/oorexx_instrumentation_mesh/`;
- source imported from the qualified archive, not reconstructed from sphere prose.

This completes source availability/provenance only. It does **not** manufacture a new r13196/current-estate runtime qualification.

## Current producer compatibility closed statically — 2026-10-29

The committed compatibility gate now verifies:

- Instrumentation Intentions v0.1-dev2 uses byte-identical Mesh dev8 core/analysis/correlation sources;
- Library Storage Instrumentation v0.1-dev8 pins the exact Mesh dev8 version/hash and passes its Mesh/static boundary checks;
- Git Storage Instrumentation v0.1-dev9 is newer than the materialized Library dev8 and still pins the exact Mesh dev8 contract;
- HTTPS Server v0.4.8 retains the Instrumentation adapter and `instrumentationSnapshot()` source shape;
- LDAP Identity v0.1-dev22 retains the Mesh/correlation adapter surface without credential/password/mailbox publication fields;
- RexxOS RTO2 Grid v0.1-dev16 identity increment passes its five static contract tests and does not replace/modify the Grid Instrumentation producer path.

Evidence: `qualification/CURRENT_PRODUCER_COMPATIBILITY_2026-10-29.md`.
Reusable checker: `qualification/check_current_producers.py`.

These are static/source compatibility results. They do not relabel package-owned NOT-RUN runtime gates as passes.

## Wire3D / Keynote reconciliation

1. Reconcile the inspected dev29.23 Keynote/NOC correlation implementation with the later `dev29.25 collector-join` package referenced by repository design material. The 2026-10-29 Library recheck still does not resolve that exact archive.
2. Preserve or consciously supersede the dev29.23 Keynote behavior: freshness separate from health, expected-service visibility, separate static/deployment and operational graph layers, operational timeline, explicit correlation/causation, and read-only NOC authority.
3. Source-control the reconciled non-vendored Keynote/NOC files and tests in the current Wire3D owner tree. Do not overwrite later Wire3D work with dev29.23.
4. Keep Wire3D work in its existing Rasen Falcon lane. Instrumentation must not seize Wire3D ownership.

## Runtime qualification still required

5. Run a fresh source-level Instrumentation dev8 qualification under an exact ooRexx 5.3.0 r13196 environment after publication. GitHub issue #60 owns this fresh execution gate. The current 2026-10-29 container did not have a materializable r13196 runtime; that absence is evidence, not a pass/fail verdict.
6. Run a live multi-node QueueRexx/XTP `MANAGEMENT`-route qualification for Instrumentation publication/query/command against the current QueueRexx head.
7. Runtime-requalify remaining producer paths against the published source: Queue Fabric, Memory Fabric, SMTP, IMAP, MVS Alchemy, SIP/RTP, NoSQLServer and application/deployment observers. LDAP dev22, HTTPS 0.4.8 and the current RTO2 identity increment have only the static/source compatibility evidence recorded above; their live/runtime package gates remain owned by those components.
8. Add a production retention/compaction policy for bounded metric, relationship and event history. Retention is observation policy, never service-state authority.
9. Add explicit capacity/load qualification for a large estate and high-rate producers. Do not emit one Queue message per protocol frame or byte.

## Correlation and incident boundary

10. Keep correlation explicit. Time, site, topology proximity or shared host must never fabricate causation.
11. If an incident/change/case service consumes correlated evidence, that service owns incident/change lifecycle. Instrumentation may carry references but must not invent incident authority.
12. Preserve the detailed forensic evidence boundary in Alchemy Log; Instrumentation remains a bounded operational projection and must not become a replacement audit/logging system.

## Security/privacy

13. Continue excluding payload bodies, credentials, mailbox names, LDAP DNs, arbitrary customer identifiers and raw private correlation IDs unless an owning service explicitly publishes a governed opaque projection.
14. Remote management remains gated by authenticated peer identity, Instrumentation authorizer and target-service authority checks. Rendering in Keynote grants no management rights.
