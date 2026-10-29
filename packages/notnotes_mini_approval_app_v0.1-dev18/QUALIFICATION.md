# dev18 SQLite default — acceptance status

**NOT QUALIFIED FOR RELEASE**. This package is a derived candidate and must not be conflated with the historical dev17 qualification below. Current draft: https://github.com/animatedads/alchemy/pull/66

- Native ooRexx 5.3.0 r13196 syntax for adapter and migration: PASS in source development workspace.
- Native mocked SQLite provider adapter contract: PASS. Actual SQLite I/O: NOT EXECUTED because librexxsql.so unavailable.
- Isolated 10,002-key native sort algorithm: PASS; real MiniNotesApp integrated sort script pending.
- Real SQLite transaction/round-trip, copied-corpus migration/reopen, complete inherited run_tests.sh, 954-/10k-document benchmarks and cryptographic policy: NOT QUALIFIED.
- Vendored NoSQL `crypto.cls` now carries the latest SLAM-found `rx_mod_inverse` invalid-input guard from main (Git blob `e9e55d3a2090fab604454283144380b547092f70`). This is a correctness fix, not a cryptographic signature provider.
- Historical dev17 source retained verbatim. See ../notnotes_mini_approval_app_v0.1-dev17/ and the Gopher sphere candidate evidence.

---

# Mini NotNotes v0.1-dev17 qualification

Dev17 adds persistent temporal authority evidence to the dev16 Time Service/ConnectSelector field path. A deterministic gateway regression checks persistence/projection independently of transport; the pre-existing dev16 test remains responsible for real Time Service civil/DST semantics.

Dev17 evidence acceptance:
- DATE evidence retains CIVIL_DATE + canonical value;
- zoned DATETIME evidence retains zone, resolved POSIX instant, tzdb edition and resolution;
- blank temporal values do not invent evidence or an instant;
- semantic document projection exposes accepted evidence beside the field policy;
- evidence survives restart before a Time Service gateway is installed;
- a later temporal mutation without Time Service fails closed and leaves prior accepted evidence unchanged;
- app-owned strict standards check for the local dev17 implementation: 25 files, 0 errors, 0 warnings;
- native dev17 regression was not executed in the current ChatGPT container because the indexed r13196 Library packages had no materialisable backing file in this session; do not infer a native PASS from the static gate.


Dev16 adds DATE/DATETIME validation through Single Time Service v0.3 and routes zoned resolution through ConnectSelector v0.1-dev2. The Time Service suite and the Mini NotNotes temporal regression were run under ooRexx 5.3.0 r13196.

Temporal acceptance evidence:
- ConnectSelector chooses DIRECT for `time.resolveIsoLocal`: PASS;
- strict civil DATE validation: PASS;
- floating DATETIME validation without implicit timezone: PASS;
- Europe/London unique zoned datetime resolution: PASS;
- spring-forward gap rejected: PASS;
- fall-back fold rejected without policy: PASS;
- fall-back fold accepted with explicit EARLIER policy: PASS;
- timezone and ambiguity metadata persist across restart: PASS;
- temporal mutation without an injected Time Service boundary fails closed: PASS.


Dev15 integrates Mini NotNotes with the common `instrumentation.mesh/0.1` observation contract while preserving application/domain authority boundaries.

The NotNotes core does not `::requires` Instrumentation Mesh. `MiniNotesApp` exposes an optional generic observation sink and emits only facts it already owns. `MiniNotesInstrumentationSource` is the separate mesh adapter. The bundled NoSQLServer is upgraded to v0.87 and uses its own `NoSQLServerInstrumentationSource`, so database query/materialisation metrics stay owned by the database layer rather than being duplicated by NotNotes.

Acceptance evidence:
- `tests/test_instrumentation_mesh.rex`: PASS under ooRexx 5.3.0 r13196;
- NotNotes snapshot schema is `instrumentation.snapshot/1` with stable service identity: PASS;
- document lifecycle gauges and submit/approve/query/persistence counters: PASS;
- NoSQLServer v0.87 emits independent `database.query.*` telemetry from the same backing database: PASS;
- NotNotes snapshot contains no database metrics and database snapshot contains no NotNotes metrics: PASS;
- InstrumentationRegistry + Publisher + Collector continuous publication retains both independent sources atomically and exposes a NotNotes document-count series by `semantic_ref`: PASS;
- business document text is not exposed through metric dimensions: PASS;
- adjacent base, persistence, relationship/subview/calculation, MANY-reference, additive-schema-evolution, semantic-projection, submit-lifecycle and batch-persistence tests: PASS in split qualification groups;
- COG `PLAN0011`: complete, return code 0, `COG_OOREXX_TESTS=1 FAILURES=0` after the final telemetry test update;
- application-owned strict standards gate: 24 files, 0 errors, 0 warnings, PASS.

The mesh remains observational. Continuous publication, history and NOC projection add no mutation authority; any future management operation must traverse the separate authenticated/authorised command path owned by the target service.

Dev14 adds a renderer-neutral semantic application projection so native Windows, CLI, mobile and future renderers can consume the same NotNotes application truth instead of inventing navigation, field meaning, lifecycle actions or list state.

The projection contract exposes dynamic document/view/format/report surfaces, a generic intention entry point, bounded document collection ranges with stable identities, typed field metadata, relationships/cardinality, semantic subviews and live lifecycle-action feasibility. Collection windows are capped at 100 rows so virtualised renderers never require an unbounded backing-state dump.

During qualification, the new projection test exposed a NotNotes core defect: `DocumentDefinition~compose` copied field name/source but dropped semantic type, cardinality, aliases, intention read/write/search flags, process owner and computed status. Dev14 fixes composition so live documents preserve the full field semantic contract. User-format definition installation now also carries declared field cardinality into the installed definition.

Acceptance evidence:
- `tests/test_semantic_application_projection.rex`: PASS under ooRexx 5.3.0 r13196;
- dynamic user-format surface discovery: PASS;
- stable document identity and bounded semantic collection window: PASS;
- field `IDENTIFIER` semantic type survives definition -> live document composition: PASS;
- live DRAFT/PENDING APPROVAL action feasibility changes: PASS;
- approval surface follows authoritative lifecycle state: PASS;
- range requests above 100 are rejected: PASS;
- adjacent CLI projection, relationships/subviews/calculations, MANY references, schema evolution and management-review regressions: PASS;
- base Mini NotNotes, query guard, CLI UI, TPS designer, NoSQL backend, submit lifecycle and nested-batch regressions: PASS;
- natural submit entrypoint, TPS exact transcript, save/PDF persistence, saved-report persistence and spreadsheet-export round trip: PASS when run separately;
- COG `PLAN0008`: complete, return code 0, `COG_OOREXX_TESTS=1 FAILURES=0`;
- strict standards gate over application/test/example sources plus the modified NotNotes semantic core: 23 files, 0 errors, 0 warnings, PASS.

The long YAML-backed suite continues to be run in split groups in this environment; completion claims above come from the individual passing executions, not an assumed aggregate result.


## 29 October 2026 main/provider + temporal/persistence reconciliation

- Source base: draft PR #77 head cd3c797475447a5a0be57f1d129266bbeb44ca75, transplanted onto current main so the shared database provider/selector exists in the same checkout.
- NotNotes does not vendor or fork the RexxSQL provider.
- Legacy field-spec compatibility regression: PASS under ooRexx 5.3.0 r13196.
- Actual Project Alchemy v0.5 file-store corpus reload with repaired decoder: PASS, 872 documents / 8 user formats.
- Exact Library Single Time Service v0.10 + ConnectSelector dev8 DIRECT DATE/DATETIME regression: PASS.
- Live RexxSQL SQLite/WAL, 954/10k integrated performance, Crypto signing and authenticated remote routes remain release gates.
