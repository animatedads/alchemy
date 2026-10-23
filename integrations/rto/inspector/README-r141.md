# RTO Inspector / Plan42 — r141 GitHub handoff

This is a **bounded integration handoff** in `animatedads/alchemy`, not a wholesale replacement of the existing repository. RTO runtime source is delivered separately in the user-facing full ZIP.

## Implemented in full ZIP

- Inspector importer hardened to accept structured, schema-qualified evidence only.
- Successful receipt requires matched request identity and positive loaded-rule count.
- Snapshot observation and installed tracing are reported separately.
- Symlink/invalid/contradictory evidence fails closed.
- Negative regression tests exercise false textual class claims, failed receipts, identity mismatch, linked files, and zero installed rules.
- Plan42 spec updated to live-import v2.
- RTO-specific sphere documentation kept distinct from the preexisting unrelated `rto` transport sphere.

**Archive SHA-256:** `a0a1a50d86ba9131b6a1958c395e237319f7c01e9be1b78fbe70ab941bd047ae`.

## Library reconciliation

The October 2026 standalone Inspector package is general-purpose, no FUSE/Storage requirement. Plan42 estate dev2 warns that a local Alchemy `runner.rex` registration does not constitute Runtime Registry publication. Neither was overlaid without provenance/compatibility qualification.

## Validation performed

`bash -n rto`; Python compile; r125/r128/r132/r133–r141 static regression tests; Plan42 verifier; positive/negative synthetic Inspector evidence. No real ooRexx runtime or live Clouseau attach executed.

## Blocking backlog

- GitHub full RTO source reconciliation, exact branch and file manifest.
- Live ooRexx/Inspector qualification and dependency path guard.
- Source and snapshot provenance attestation.
- Optional LLM Gopher sphere publication after authority approval.

The RTO command membrane and `RTOOperationSecurityContext` are never bypassed by this instrumentation.
