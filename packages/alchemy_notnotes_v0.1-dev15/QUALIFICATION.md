# dev15 qualification

Run `tests/run_all.sh` with the exact dependency paths described in `DEPENDENCIES.md`.
The suite includes semantic field propagation, dev7 feasibility assessment, provider-
neutral intention dispatch, referrals, replication, scripting, approvals, and the
sealed dev4 RTO clustered-node contract.

The dev15-specific feasibility test proves:

- field metadata survives application snapshot/install;
- aliases canonicalise to authoritative field names;
- ordinary intention-writable fields can be changed through normal NotNotes save/revision;
- computed fields remain understood but are assessed INFEASIBLE;
- process-owned fields remain understood but generic SET_FIELD is assessed INFEASIBLE;
- missing authority is reported independently as structured assessment evidence; and
- known-infeasible NotNotes plans are not dispatchable through the adapter.
