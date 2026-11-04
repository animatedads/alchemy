# ED209 RTO2 candidate3 — R-11

The old MU wrapper discarded the native error class. On failure, this revision preserves the exit code and emits only an allowlisted diagnostic classification. In particular `RTO2_MI_CONTROLLER_GRANT_ABSENT_OR_STALE` is distinguished from `RTO2_MI_RESPONSE_NOT_QFXTP` and `XTP_RESPONSE_AUTH_FAILED`. No raw unauthenticated payload or commissioning secret is logged. Existing controller receipt admission, XTP execution and guest image code remain unchanged.

Local target tests of the complete candidate3 ZIP: 4/4 new wrapper tests, 6/6 guest preflight, 2/2 overlay. The original full synthetic 20-MI test rerun exceeded its execution limit and is not claimed as a fresh pass. Live 20/20 and R-10 cryptographic MI-origin signature remain unqualified.
