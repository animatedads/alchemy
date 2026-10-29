# Local execution qualification record

- Python acceptance and negative tests: 7/7 PASS (last run, ~31.6 s).
- Native RTO2 local job with ooRexx 5.3.0 r13196: PASS, committed sum 500500.
- One authenticated QF/XTP request -> MI handler -> RTO2CountJob commit -> authenticated response: PASS (direct native execution during this build).
- A later repeated native HMAC fixture suite did not complete because the imported pure ooRexx SHA-512 fallback ran excessively slowly; its negative cases are NOT accepted as passed. The first authenticated exchange did pass previously. `ED209_EXTENDED_CRYPTO_TESTS=1` is optional, not part of the current green suite.
- Generated Grid guest-bootstrap C source: PASS strict `gcc -Wall -Wextra -Werror -fsyntax-only`; overlay generated as a separate directory.
- Python-based central acceptance / sorting with 20 fixture receipts: PASS; simulated only, NOT 20 live MIs.
- Deliberately missing 1 of 20: gate FAIL as expected.
- NO live ED209 host contacted, NO guest image rebuilt, NO private key changed, NO service changes, NO latest-XTP FIRST/KEY/DATA integration field acceptance.
