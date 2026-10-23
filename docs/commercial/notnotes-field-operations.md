# NotNotes Business & Field Operations — customer-ready product definition, not customer-ready software

**Status: design target; not released.** Reference buyer: a 20-person maintenance firm wants a Lotus Notes/Domino-*style* business application without a development team. Office staff define their own document types and workflows. Field engineers on phones complete service reports with checklists, photos and signatures **offline**. LDAP/AD/Entra-backed login, audit, managed operation, updates, backup and human support are required.

The sellable promise is **“Define my documents and go”**, not “free software” or “a development platform you must implement yourself”. It does not claim native NSF compatibility.

## Proposed public offers (software list prices)

| Tier | Target USD/month | Hypothesis, up to 20 named users |
| --- | ---: | --- |
| Workspace | 149 | Document definitions, visual views/forms, approvals, directory identity and managed standard support |
| Field Operations | 299 | Workspace plus offline-capable mobile forms, local persistent writes, attachments, reconnect/merge and field workflows |
| Business Critical | 499 | Field tier plus defined recovery/governance and enhanced support following SLO acceptance |

All allowances, support hours, storage, regions, devices, identity variants and service levels are provisional and must be written into the accepted entitlement. No unlimited email, SMS, GPU, data transfer or expert engineering assistance.

## Candidate Alchemy composition

- NotNotes: versioned DocumentDefinition/ApplicationDefinition, document graph, relationship/view semantics and approval lifecycle. Existing Mini NotNotes demonstrations show textual creation of documents/views; not an accepted general-purpose browser designer.
- Wire UI/native/Android presentation: renderer remains separate from ooRexx-owned semantic truth.
- LDAP Identity Directory, Access Permissions and Institutional Policy for enterprise sign-in, authorization and group mappings.
- NoSQLServer/Storage Fabric for document state and attachments; Journal/Provenance Ledger for durable, traceable work; Observation for support-safe diagnostics.
- Connect Selector chooses direct invocation, RPC, or Queue Fabric as published and appropriate; WLU tracks work, Commerce mediates channel entitlement and billing.
- No extra assumption of CouchDB, Odoo, Appsmith or Directus, and no claim that those are incompatible with third-party workflows.

## Minimum one-purchase installation

1. Marketplace buyer accepts offer; show price, support, trial conversion and *separate* infrastructure/provider costs.
2. Resolve marketplace subscription identity to a tenant; read-only readiness check for region, directory, network, storage and delegated permissions.
3. Explicit scope authorization, provision, health probe and rollback where possible; no secret pasted into scripts or logs.
4. In browser, non-developer creates `Service Visit/1` with job, customer, asset, notes, checklist, photos, signature, timestamp, lifecycle and linked view; initial templates included.
5. Configure 20 user identities/roles and devices. Demonstrate real offline job assignment and save before marking product ready.
6. Trial dashboard shows remaining days, capped credit/WLU, spend and cancellation/export. Expiration adheres to specific cloud marketplace behaviour.
7. Managed monitoring, support and backup are operator-owned, contractually bounded services — not customer tasks hidden under one-click language.

## Acceptance requirements: 20-person field-service fixture

| Test | Must demonstrate |
| --- | --- |
| NN-01 | Business admin defines new document, form and view without editing program source |
| NN-02 | 20 roles/users authenticate against chosen directory, least privilege and revocation tested |
| NN-03 | Mobile client fetches approved assigned work with explicitly bounded offline data scope |
| NN-04 | Completely disconnected device creates/edits a report, stores photo and signature locally |
| NN-05 | Restart app/device while offline retains changes and enforces documented authorization expiry |
| NN-06 | Two disconnected authorized users change same record: deterministic detected conflict, governed resolution, no silent lost update |
| NN-07 | Connectivity flaps: resumable media/document transfer, deduplication and status/retry visibility |
| NN-08 | Directory change/revocation during disconnection follows documented lease/conflict policy (no false instant revocation) |
| NN-09 | Durable revision, actor and audit evidence without exfiltrating private customer payloads to telemetry |
| NN-10 | Restore/migration/retry does not double-apply document mutations or double-bill accepted work |
| NN-11 | Backup-restore, tenant export, cancellation, retention and safe removal demonstrated |
| NN-12 | Trial -> accepted work -> conversion/expiration/cancel -> settled bill matches published plan and credits |
| NN-13 | Non-developer repeats the process to define a second business form and workflow |
| NN-14 | Vendor support can investigate from bounded, consented evidence and published runbooks |

**Release blockers:** mobile offline persistence and sync contracts; merge/conflict strategy; UI designer; directory permission lease semantics; multi-tenant support and security; entitlement/meter integration; restore/drain/provisioning operations; evidenced cost and support capacity. Source prototypes in Library are not evidence of end-to-end completion.

## How to sell this

Sell the cost of avoiding a development team and patchwork integrations, not a percentage off an open-source license. Direct comparisons against AppSheet, Power Apps, Fulcrum, HCL Domino/Nomad or Directus must normalize user counts, offline sync semantics, SSO, support, hosting, backups, usage, training and contractual duration. **Do not advertise the $299 tier as available until the entire acceptance fixture passes.**
