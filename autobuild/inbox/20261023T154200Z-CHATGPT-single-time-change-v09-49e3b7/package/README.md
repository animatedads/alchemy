# Single Time Service — change publication projection v0.9

A standalone, provider-neutral ooRexx projection over `single.time.impact/0.1` records. It is designed to integrate with Single Time Service v0.8 and later but has no runtime hard dependency on the service or ConnectSelector.

* `src/TimeChangePublication.cls` emits zero or more `single.time.change/0.1` advisory records.
* Bound: at most 366 changes, with schema and provenance checks.
* Carries both authority revision witnesses and mandatory snapshot identities for cross-provider comparisons.
* Emits a collision-unambiguous length-prefixed idempotency key. This is not a cryptographic signature.
* No implicit transport, Queue Fabric dispatch, event execution, acknowledgement or clock read.

This is a **development candidate**. New native ooRexx execution is unqualified in the originating environment because the executable runtime was unavailable; tests are included for the Alchemy receiver. Python static contract tests do not replace execution of the native test.

Run: `REXX_PATH=src rexx tests/change_publication.rex`.

The complete v0.9 Single Time Service source ZIP is maintained separately from this first, minimal GitHub component submission; this component submission is **not** a claim that the entire earlier v0.1–v0.8 service has been backfilled into GitHub.
