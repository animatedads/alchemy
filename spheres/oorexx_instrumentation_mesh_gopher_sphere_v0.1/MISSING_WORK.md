# Missing work / continuation gates

This file is deliberately conservative. A missing item is not implied complete merely because a dependent package references Instrumentation Mesh.

## Completed source-publication gate — 2026-10-27

The previous source-publication gap is closed on the publication branch:

- exact delivery: `oorexx_instrumentation_mesh_v0.1-dev8.zip`;
- archive SHA-256: `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`;
- archive digest verified before import;
- every archive entry covered by `SHA256SUMS.txt` verified before import;
- exact runtime source, tests, package metadata and qualification evidence published under `packages/oorexx_instrumentation_mesh/`;
- the source was imported from the qualified archive, not reconstructed from sphere prose.

This completes source availability/provenance only. It does **not** manufacture a new 2026-10-27 r13196/current-estate runtime qualification.

## Wire3D / Keynote reconciliation

1. Reconcile the inspected dev29.23 Keynote/NOC correlation implementation with the later `dev29.25 collector-join` package referenced by repository design material. The 2026-10-27 Library recheck still did not resolve that exact archive.
2. Preserve or consciously supersede the dev29.23 Keynote behavior: freshness separate from health, expected-service visibility, separate static/deployment and operational graph layers, operational timeline, explicit correlation/causation, and read-only NOC authority.
3. Source-control the reconciled non-vendored Keynote/NOC files and tests in the current Wire3D owner tree. Do not overwrite later Wire3D work with dev29.23.
4. Keep Wire3D work in its existing Rasen Falcon lane. Instrumentation may request read-only verification/reconciliation evidence but must not seize Wire3D ownership.

## Runtime qualification still required

5. Run a fresh source-level Instrumentation dev8 qualification under the current exact ooRexx 5.3.0 r13196 environment after publication. The imported package carries qualified 2026-10-11 evidence; this sphere does not relabel source publication as fresh execution.
6. Run a live multi-node QueueRexx/XTP MANAGEMENT-route qualification for Instrumentation publication/query/command against the current QueueRexx head. Earlier packages qualified the service-route contract and underlying Queue Fabric behavior, but this sphere does not claim a new live two-node run.
7. Requalify current producers against the published source. The 2026-10-27 Library has advanced at least:
   - Instrumentation Intentions v0.1-dev2 — read-only events/correlation plus relationships/freshness qualification PASS;
   - Storage Fabric Instrumentation Mesh v0.1-dev7 — current Storage observation line consuming exact Instrumentation dev8.
   Continue with Queue Fabric, Memory Fabric, SMTP, IMAP, LDAP, HTTPS, RexxOS MU/MI, MVS Alchemy, SIP/RTP, NoSQLServer and deployment/application observers.
8. Add a production retention/compaction policy for bounded metric, relationship and event history. Retention is observation policy, never service-state authority.
9. Add explicit capacity/load qualification for a large estate and high-rate producers. Do not emit one Queue message per protocol frame or byte.

## Correlation and incident boundary

10. Keep correlation explicit. Time, site, topology proximity or shared host must never fabricate causation.
11. If an incident/change/case service consumes correlated evidence, that service owns incident/change lifecycle. Instrumentation may carry references but must not invent incident authority.
12. Preserve the detailed forensic evidence boundary in Alchemy Log; Instrumentation remains a bounded operational projection and must not become a replacement audit/logging system.

## Security/privacy

13. Continue excluding payload bodies, credentials, mailbox names, LDAP DNs, arbitrary customer identifiers and raw private correlation IDs unless an owning service explicitly publishes a governed opaque projection.
14. Remote management remains gated by authenticated peer identity, Instrumentation authorizer and target-service authority checks. Rendering in Keynote grants no management rights.
