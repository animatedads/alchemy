# Missing work / continuation gates

This file is deliberately conservative. A missing item is not implied complete merely because a dependent package references Instrumentation Mesh.

## Source publication

1. Publish the complete qualified Instrumentation Mesh v0.1-dev8 runtime source tree as a first-class `packages/oorexx_instrumentation_mesh/` package. GitHub currently contains consumers that `::requires "InstrumentationMesh.cls"`, but no first-class owned runtime package was found during the 2026-10-23 repository check.
2. Preserve exact dev8 source and qualification evidence; do not reconstruct the implementation from this sphere.
3. Add package-level release/provenance metadata linking the qualified archive SHA-256 `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`.

## Wire3D / Keynote reconciliation

4. Reconcile the inspected dev29.23 Keynote/NOC correlation implementation with the later `dev29.25 collector-join` package referenced by repository design material. Do not overwrite later Wire3D work with dev29.23.
5. Source-control the non-vendored Keynote/NOC integration classes, web projection and tests in the current Wire3D owner tree after that reconciliation.
6. Keep static/deployment topology and operational relationships as separate graph layers.

## Runtime qualification still required

7. Run a live multi-node QueueRexx/XTP MANAGEMENT-route qualification for Instrumentation publication/query/command against the current QueueRexx head. Earlier packages qualified the service-route contract and underlying Queue Fabric behavior, but this sphere does not claim a new 2026-10-23 live two-node run.
8. Requalify current producers after source publication: Queue Fabric, Memory Fabric, Storage Fabric, SMTP, IMAP, LDAP, HTTPS, RexxOS MU/MI, MVS Alchemy, SIP/RTP, NoSQLServer and deployment/application observers.
9. Add a production retention/compaction policy for bounded metric, relationship and event history. Retention is observation policy, never service-state authority.
10. Add explicit capacity/load qualification for a large estate and high-rate producers. Do not emit one Queue message per protocol frame or byte.

## Correlation and incident boundary

11. Keep correlation explicit. Time, site, topology proximity or shared host must never fabricate causation.
12. If an incident/change/case service consumes correlated evidence, that service owns incident/change lifecycle. Instrumentation may carry references but must not invent incident authority.
13. Preserve the detailed forensic evidence boundary in Alchemy Log; Instrumentation remains a bounded operational projection and must not become a replacement audit/logging system.

## Security/privacy

14. Continue excluding payload bodies, credentials, mailbox names, LDAP DNs, arbitrary customer identifiers and raw private correlation IDs unless an owning service explicitly publishes a governed opaque projection.
15. Remote management remains gated by authenticated peer identity, Instrumentation authorizer and target-service authority checks. Rendering in Keynote grants no management rights.
