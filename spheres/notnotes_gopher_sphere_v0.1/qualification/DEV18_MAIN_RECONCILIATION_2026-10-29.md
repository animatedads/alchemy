# NotNotes dev18 current-main reconciliation — 29 October 2026

## Source
- dev18 application tree: draft PR #77 head cd3c797475447a5a0be57f1d129266bbeb44ca75.
- integration base: current main at branch creation.
- database provider: consumed from existing main DatabaseBackendSelector/RexxSQL source; no copy inside NotNotes.

## Added app-owner repair
Legacy persisted field specifications with a tenth empty reserved slot are accepted; current nine-slot temporal metadata is preserved; malformed/unknown non-empty trailing data fails closed.

## Executed evidence
- ooRexx 5.3.0 r13196.
- field-spec compatibility regression PASS.
- Project Alchemy v0.5 corpus reload PASS: 872 documents, 8 user formats.
- exact Library Single Time Service v0.10 + ConnectSelector dev8 DIRECT temporal-field regression PASS.

## Still gated
Real RexxSQL SQLite/WAL transaction durability, full clean-checkout suite, 954/10k integrated benchmarks, Crypto signing policy, and authenticated LDAP/HTTPS/XTP remote routes remain unqualified.
