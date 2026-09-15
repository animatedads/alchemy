# Validation

Qualified under the supplied ooRexx 5.3.0 r13196 Internal Test Version against `oorexxapis(20260828-163232).zip`.

- PASS 9/9 domain tests from `run_tests.sh`.
- PASS 1/1 Relationship Case → Relationship Adapter → Staff Authority → Core Banking integration test.
- PASS compilation of all 6 package `.cls` files.
- Existing customer teller/supervisor, maker/checker, delegation, elevation and exact-command tests remain green.
- `INSTITUTIONAL` authority is positively issuable for the three intermediary staff operations and is rejected by `FederationBankStaffCommandBinder`.
- A customer-scoped intermediary action cannot consume an institutional rule.

Total: **10/10 executable tests**. See `VALIDATION_TRANSCRIPT.txt`.
