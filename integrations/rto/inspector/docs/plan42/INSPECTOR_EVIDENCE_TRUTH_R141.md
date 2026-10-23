# RTO Inspector evidence truth — r141

**Status:** Static-qualified importer candidate; no live RTO/ooRexx runtime assertion.

`tools/rto_inspector_import.py` separates three types of statement:

- **Configured** — a project trace-request JSON exists. Configuration is not an installed rule.
- **Receipt-declared** — a deterministic receipt with the expected Inspector schema, matching filename/request identity, successful load status, and positive installed rule count declares class coverage. This is not evidence that a method was called.
- **Snapshot-observed** — objects in a snapshot with the expected Inspector schema identify classes observed at the capture point. This is not evidence that a command was authorized or dispatched.

The former r140 importer scanned arbitrary serialized JSON text to infer class coverage. This could interpret a warning, filename, or explanatory example as evidence of a live RTO object. r141 uses only structured fields and refuses symlink evidence, invalid receipts, zero-rule receipts, and malformed JSON. It treats invalid imported evidence as a failing comparison, not as a successful but empty scan.

The output schemas are `alchemy.rto.inspector-live-import.v2` and `alchemy.rto.inspector-live-compare.v2`. Legacy r140 fixture artifacts are test specimens, not attested runtime evidence. The full RTO authority path remains unchanged: `RTOOperationSecurityContext` is the governing authority; the Inspector/Plan42 stack is observational.

## Library/estate reconciliation, 23 October 2026

The Library contains a more recent standalone Inspector Clouseau package, with `addRoot`, `attach`, `refreshObservation`, and `snapshot`; it is independent of FUSE/Storage. It also contains the Plan42 estate handoff 0.1-dev2 dated 15 October 2026, which explicitly warns that a local Alchemy framework registration is **not** Runtime Registry publication. Neither external candidate is silently overlaid into the r140 framework import. Their exact package dependencies, integrity pins, and live compatibility must be qualified separately.

## Evidence acceptance

```
python3 tests/rto_v105r140_inspector_live_import_static.py
python3 tests/rto_v105r141_inspector_evidence_truth_static.py
python3 tools/rto_inspector_import.py --root . --live-dir reports/inspector/live --json
```

The test suite includes deliberately forged narrative class claims, unsuccessful receipts, request/file identity mismatches, linked files, and empty installations. Passing these tests does **not** establish runtime Inspector installation. Runtime acceptance needs receipts and real snapshots from the intended deployed version, together with authenticated transport/provenance if stronger evidentiary guarantees are required.