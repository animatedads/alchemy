# AJI Wire UI Web v0.2 handover

Current AJI authority baseline: `all_japan_insurance_v0.10.zip`.
Current UI baseline: `all_japan_insurance_wire_ui_web_v0.2.zip`.
Current API roll-up: `oorexxapis(20260828-191905).zip`.

v0.2 closes the v0.1 missing-bootstrap gap. The canonical local live command is
`./start.sh --live`; it starts the ooRexx authoritative development application,
Queue Fabric bridge, Web Gateway/bootstrap on 8090 and browser shell on 8082.

The authoritative service owns `ALL-JAPAN-INSURANCE-OPERATIONS` /
`AJI-DEV-SESSION` / `AJI-WEB`, binds exact compiled release
`ALL_JAPAN_INSURANCE_OPERATIONS@2`, and projects a clearly identified
`AUTHORITATIVE_DEVELOPMENT_FIXTURE`. It is not a production AJI repository.

Important recovered defect: v0.1's Builder release used server primitives
`SUMMARY` and `TIMELINE`, which Alchemy Wire UI JS v0.4-dev4's semantic adapter
cannot render. v0.2 corrects these to supported primitives and tests the real JS
renderer, not only Builder->Server binding.

Next work:
1. Replace development fixture lookup with an AJI v0.10 application/service
   query adapter while retaining exact Wire UI authority boundaries.
2. Introduce server-owned v0.17 workspace query/selection/result state for large
   policy, billing and claims books.
3. Add staff authentication attribution, Access Control, Permissions and
   Security Effect before any mutation commands.
4. Add evidence timelines and immutable rating/billing/claim/accounting refs from
   the real AJI service objects.
5. Keep Federation Intermediaries UI in its separate workstream.
