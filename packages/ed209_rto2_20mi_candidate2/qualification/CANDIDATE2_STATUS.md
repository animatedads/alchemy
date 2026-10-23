# Candidate2 acceptance boundary

- Route selection: use commissioned symbolic `GRID.MN.<ID>` identity, not destination MAC as RouteTable key.
- Old guest without controller grant: demonstrated `UNAUTHENTICATED:PEER_NOT_TRUSTED` plaintext; this yields `XTP_FRAME_INVALID` in candidate1. The live F source of framing failure is **not yet verified**.
- Corrected client preserves cryptographic fail-closed behaviour, diagnoses plaintext without treating it as authenticated.
- Additive Grid handler overlay preserves previously installed FAST and envelope-registration changes; source fingerprint receipt.
- MI image preflight checks embedded route, controller grant, derived key, handler branch and startup environment.
- RTO2 authenticated native local worker and captured `alchemy.rto/0.1` state: PASS.
- F/H actual 4/4 job return receipts: NOT TESTED with candidate2.
- 20-MI fleet live acceptance: NOT TESTED.
- XTP dev25 named-service latest-line federation: NOT CLAIMED by this dev18-compatible repair.
