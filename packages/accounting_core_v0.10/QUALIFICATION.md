# Accounting Core v0.10 qualification

Qualified on 2026-09-01 using the user-supplied ooRexx 5.3.0 r13196 debug package (SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`) and consolidated roll-up `oorexxapis(20260901-112242).zip` (SHA-256 `9f95981d13a9cf6b51aaa032f6c7c401615b3f53609b4a240268bccd13cd5d63`).

Optional reporting cryptography is qualified against ooRexx Crypto v0.8.3 from that roll-up: source ZIP SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`; vendored `crypto.cls` SHA-256 `924d4baa9e5d536f3b1433ccaf73edb1aee3e35c31c860f8ee35d350f1b396b6`.

## Full suite

- ooRexx assertions: **388/388**
- deterministic Companies House projection assertions: **10/10**
- new reporting lifecycle assertions: **27/27**
- retained reporting attestation/submission assertions: **27/27**
- Crypto v0.8.3 reporting-adapter assertions: **7/7**
- retained sealed-reporting assertions: **30/30**
- packaged examples: **11/11**

## v0.10 lifecycle locks

- `accounting.reporting.filing/0.1` binds exact snapshot, boundary and attestation-set identities
- amendments/corrections bind the exact predecessor filing ID/fingerprint and a non-empty reason reference
- one lifecycle series has one original filing; additional versions explicitly descend from an already registered predecessor
- lifecycle events form an exact previous-event fingerprint chain
- submission/resubmission events bind exact `AccountingReportingSubmissionEvidence` and its attestation set
- regulator `ACKNOWLEDGED`, `ACCEPTED` and `REJECTED` observations require exact external reference + external evidence identity
- `RESUBMITTED` requires an exact earlier submission/resubmission event identity
- `SUPERSEDED` requires an exact successor filing that explicitly descends from the superseded filing
- a superseded filing cannot receive later workflow observations
- rejection/withdrawal/supersession do not mutate the original submission evidence status or erase the historical filing
- a stale original snapshot remains independently verifiable as the exact report previously approved/filed while a corrected filing proceeds through a new lifecycle
- Accounting Core records asserted actor/authority identity but does not decide legal permission, regulator semantics or submission transport

## Retained qualification

All v0.9 attestation/submission, v0.8 sealed-reporting, v0.7 settlement rounding, v0.6 tax determination, v0.5 scopes/reporting, v0.4 precision/persistence, event/policy, real Companies House/Civic and four-company tests remain green. All Accounting Core source packages retain `::OPTIONS DIGITS 50`.
