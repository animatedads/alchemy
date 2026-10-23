# Memory Fabric XTP candidate changelog

## Candidate2 — 2026-10-23
- Rebased design and native qualification on Memory Fabric dev10, XTP dev25, Operational Planner dev5, Storage Fabric dev23.
- Added authoritative block and replica verification gate; fixed planning aggregate overcommit.
- Added per-domain operational capacity tickets and actual dev25 rate-limited named-service send adapter.
- Added tests for emergency, contraction, epoch, revocation, class/peer mismatch, and live XTP/UDP pacing.
- Created separate source-level Gopher Memory Fabric sphere v0.1 and identified canonical Gopher qualification still missing.

## Candidate1 — 2026-10-16
- Added two-replica planning semantics, XTP FIRST control seam, dev23 registration patch and architecture draft.
