# Mini NotNotes Approval Desk v0.1-dev17

## New in dev17: retained temporal authority evidence

DATE/DATETIME writes still use the injected Single Time Service boundary and zoned DATETIME resolution still goes through ConnectSelector. Dev17 retains the Time Service evidence that established the accepted meaning instead of keeping only the human civil string. For non-empty temporal fields NotNotes can persist and project the temporal kind, canonical civil value, zone, resolved POSIX instant, tzdb edition and UNIQUE/FOLD resolution where supplied by Time Service. Blank temporal fields remain blank and do not invent an instant.

The evidence is stored separately from the user field value in the NotNotes application store. A fresh process can inspect the previously accepted temporal meaning without contacting Time Service; changing that value still requires a live Time Service gateway and fails closed when none is available. ConnectSelector remains the transport-selection boundary: NotNotes does not select DIRECT, RPC or Queue Fabric itself.



## New in dev16: Time Service temporal fields through ConnectSelector

`DATE` and `DATETIME` fields now use the Single Time Service v0.3 semantic boundary. Civil dates are validated as calendar values without inventing instants; floating datetimes remain floating; zoned datetimes resolve through ConnectSelector. The qualified route is DIRECT today. RPC and Queue Fabric remain transport choices owned by ConnectSelector when corresponding Time Service adapters are published.

A zoned `DATETIME` may declare `TIME_ZONE` and an optional `AMBIGUITY_POLICY` (`EARLIER` or `LATER`). DST gaps fail closed. DST folds fail closed unless an ambiguity policy is explicitly declared. Temporal writes fail closed when no Time Service gateway is installed.


## New in dev15: common instrumentation and telemetry

Mini NotNotes now exposes optional operational observations through the estate-wide `instrumentation.mesh/0.1` contract. The NotNotes semantic core still has no hard dependency on Instrumentation Mesh: `MiniNotesApp` accepts an optional observation sink, while `MiniNotesInstrumentationSource` translates application-owned facts into the common mesh vocabulary.

NotNotes owns only application/workflow observations such as document-state gauges, query counts, persistence/batch activity, schema evolution and submit/decision outcomes. The bundled NoSQLServer has been upgraded to v0.87 and keeps database query/materialisation telemetry in its own independent instrumentation source. NotNotes does not duplicate those database metrics, and neither source places business document values in metric dimensions.

The adapter can be registered with an `InstrumentationRegistry`, sampled by an `InstrumentationPublisher`, and collected by the common bounded-history collector without giving the collector or a NOC mutation authority over NotNotes.

## New in dev14: renderer-neutral semantic application projection

NotNotes now exposes its application presentation semantics as native ooRexx objects rather than requiring each renderer to infer business navigation and workflow rules. `semanticApplicationProjection`, `semanticCollectionRange` and `semanticDocumentProjection` expose dynamic views/formats/reports, stable document identities, field meaning/capabilities, relationships, subviews and currently feasible lifecycle actions. Collection windows are bounded to 100 rows for virtualised native renderers.

Dev14 also fixes the underlying field-definition composition path: live documents now preserve semantic type, cardinality, aliases, intention read/write/search flags, process owner and computed status from their exact document definition. This was discovered by the Windows-client consumer probe and fixed in NotNotes core rather than hidden in a renderer.


## New in dev13: additive document-format evolution

Installed user document formats can now be improved without rebuilding them from scratch. `ALTER <format>` / `IMPROVE <format>` opens the existing definition, protects all existing field contracts, and permits additive fields/subviews. Existing documents are migrated with typed blank values for newly added fields, while their existing values, lifecycle state and stable identities are preserved. `SET <field> = <value>` edits writable fields on an existing selected user document and uses normal NotNotes persistence. Non-additive field removal/type/relationship changes are refused in this increment.

Example:

```text
ALTER TPS Report
I need a field for the Department
SAVE
SELECT TR-0001
SET Department = Operations
```

## New in dev12: first-class multi-document references

`DOCUMENT_REFERENCE` fields now support `CARDINALITY=MANY` as a first-class NotNotes relationship. The designer accepts phrases such as `I need many TPS Reports`; completion accepts comma-separated identifiers/keys; NotNotes stores stable document identities, persists relationship cardinality, dereferences every target, traverses MANY relationships in saved reports, and treats membership correctly when a subview links back through a multi-reference field.

Selected documents can be edited after creation with `LINK <reference field> TO <document>` and `UNLINK <reference field> FROM <document>`. These are ordinary NotNotes domain mutations and persist through the same authority/storage path as other document changes.


## New in dev11: bounded batch persistence

Large application-construction/import workloads can bracket ordinary NotNotes mutations with `beginBatch` / `endBatch`. Domain state changes happen immediately, but automatic persistence is coalesced until the outermost batch closes. Batches may nest; a fresh process cannot observe deferred mutations before the outer commit. Existing lifecycle commands and explicit normal persistence semantics are unchanged.

This capability is exercised by the Project Alchemy documentation corpus, which now constructs 96 linked documents and three saved registers without performing a full NoSQL snapshot after every individual format/document/report mutation.

## New in dev9: management-review fixture and live lifecycle projection

The management-review delivery is now a product acceptance fixture rather than a one-off working copy. Dotted subview/report bindings resolve human display labels to canonical stored field names, large imported document sets persist by insert/update in place, and list-mode lifecycle actions refresh the selected row immediately so `SUBMIT`, `APPROVE`, and `REJECT` do not display stale status cells.

Qualification loads the real management-review dataset and proves multi-linked TPS selections, consultant findings, subview traversal, calculated selected cost, saved management reports, and immediate/fresh-process lifecycle state.

## New in dev8: linked-dataset relationship compatibility

Mini NotNotes now consumes and persists the external `relationships` table used by
`TPS-enabled-NotNotes-data-linked-v1`. A persisted `DOCUMENT_REFERENCE` field
without an embedded `REF_TARGET` is enriched from authoritative relationship
metadata on load. Saving regenerates relationship rows from live user-format
definitions, so real document links survive save/restart.

Qualification includes the exact linked TPS dataset and proves
`TPS Report Review.TheTPSReport -> TPS Report` resolves by stable `DocKey` before
and after save/reload. The supplied dataset has no legacy `subviews` table; dev8
does not invent or migrate one.

A real text-mode NotNotes application using ooRexx CLI UI dev8 for semantic
screen, table, detail, form and prompt models. Application/domain truth remains
in NotNotes; CLI UI is only the renderer/controller boundary.

The app still seeds the five dependency-linked approval documents from dev2 and
retains the approval, reject, query, free-text search and view workflows.


## New in dev7: submit lifecycle

User-created documents now have an explicit durable workflow transition:

```text
DRAFT --SUBMIT--> PENDING APPROVAL --APPROVE/REJECT--> APPROVED/REJECTED
```

`SAVE` persists the current document state; it does not imply submission. `SUBMIT [note]`, `submit this document`, `submit this TPS report`, and `send for approval` all invoke the same NotNotes lifecycle operation. Submission creates the first-class approval/referral evidence required by the existing approval path, persists it, and reloads correctly after restart.

## New in dev7: relationships, embedded subviews and calculations

User-described document fields can be real `DOCUMENT_REFERENCE`s. A bare phrase such as `I need a Customer` defaults to a document reference (and may name a target format that is installed later). The stored value is the stable target document key; the UI dereferences it when displaying the parent document.

A document designer can also insert an embedded subview, for example:

```text
insert subview Sales Lines from Sales Line linked by Order
subview column Product
subview column Product.Price as Price
subview column Quantity
row calculated Total = Product.Price * Quantity
column calculated Order Total = SUM(Total)
```

Row calculations are named per-row computed values. Column calculations are named aggregate values over the subview rows. Both are recomputed from authoritative documents and survive restart because their definitions, not derived values, are persisted.


## New in dev7: report on TPS reports

Persisted TPS documents are now a reporting source. `REPORT TPS` presents a register in the CLI UI, while `REPORT TPS TO <file.pdf>` builds a landscape PDF through ooRexx PDF v0.1-dev3 using its flowed table renderer. The report includes total/status counts and a table of document key, TPS number, user, summary and status.

Examples:

```text
REPORT TPS
REPORT TPS TO tps-register.pdf
get me a report on my TPS reports
```

## Fixed in dev4: one controller for every entry point

`run_ui.sh`, `run_interactive.sh`, and `run_codex_script.sh` now drive the same
`MiniNotesCliUi` application state machine. The dev3 delivery accidentally left
the two line-oriented entry points on the older `MiniNotesTextUi` command
implementation, so the documented DESIGN/COMPLETE wizard existed in ANSI/headless
tests but was unreachable from the shipped scripted interface. Dev4 removes that
divergence.

The exact documented TPS transcript is now an executable regression test in
`tests/test_tps_entrypoint.sh`.

## New in dev3: application design from inside the application

Codex (or a human) can now create a real NotNotes `DocumentDefinition` from the
running application.

Run the ANSI UI:

```sh
REXX_HOME=/path/to/usr/local ./run_ui.sh
```

Then type:

```text
create a new document format called TPS Report
I need a field for the 'TPS Number'
I need a user
SAVE
complete a tps report
TPS-2026-001
codex
```

The design wizard registers `TPS Report/1` on the live NotNotes node. The two
requested fields are real first-class fields:

```text
TPSNumber  semantic type IDENTIFIER
User       semantic type USER_REFERENCE
```

A real `TPS Reports/1` NotNotes view is also registered. The completion wizard
then composes a document from `TPS Report/1`, collects the values, saves the
new revision, opens the completed document in the CLI UI detail projection, and
makes the custom fields searchable.

User-created formats receive a small standard NotNotes envelope (`DocKey`,
`Title`, `Amount`, `Risk`, `DependsOn`, `Workflow`) so they remain compatible
with the generic document list/query/view surface. The user-requested fields are
kept distinct from that envelope.

## Existing approval desk

Seeded documents:

1. `SUP-001` supplier evidence — auto-approved.
2. `PR-1001` small purchase (£850) — depends on SUP-001, auto-approved.
3. `PR-1002` large purchase (£4200) — depends on SUP-001, human approval.
4. `SEC-2001` high-risk security review — depends on PR-1002, human approval.
5. `REL-3001` release authorization — depends on PR-1002 and SEC-2001.

Useful commands include:

```text
DOCUMENTS
QUERY gpu
QUERY purchase > 1000
VIEW release pending
SELECT PR-1002
READ
APPROVE reviewed
REJECT insufficient evidence
DESIGN TPS Report
COMPLETE TPS Report
QUIT
```

Natural forms `create a new document format called ...` and `complete a ...`
enter the same design/completion state machines as the explicit DESIGN and
COMPLETE commands.

## UI boundary

CLI UI dev8 supplies the real ooRexx ANSI binding plus renderer-neutral table,
detail, form, prompt and semantic-action models. It retains normal terminal
ownership: no alternate screen, mouse capture, or application-domain logic in
the native renderer.

The headless tests exercise the same `MiniNotesCliUi` state machine used by the
ANSI UI, so automation does not get a separate privileged implementation.

## Durable save and PDF print

Mini NotNotes uses the NoSQLServer v0.87 file backend for durable application data.
Document formats, completed documents and approval decisions survive process restart.

`SAVE` explicitly flushes the current application state. Mutating operations also
auto-persist. `PRINT` shows a text preview of the selected document;
`PRINT TO <file.pdf>` (or `PRINT <key> TO <file.pdf>`) renders a real PDF 1.4
file through the existing Alchemy ooRexx PDF `PdfNotNotesRenderer`. A missing
`.pdf` suffix is added automatically.

Example:

```text
QUERY TPS-2026-001
SELECT TR-0001
PRINT
PRINT TR-0001 TO TPS-2026-001.pdf
```

## New in dev7: user-designed saved business reports

Report definitions are now first-class durable application metadata. Codex can design a report from inside Mini NotNotes instead of relying on a hard-coded TPS report command.

Example:

```text
I need a TPS Summary Report
which has rows for each TPS Report
the name in column 1
status in column 2
TPS Number in column 3
user in column 4
cost in column 5
total cost
SAVE
```

The report definition is saved in the NoSQLServer-backed application store. It can be run in a fresh process:

```text
REPORT TPS Summary Report
REPORT TPS Summary Report TO tps-summary.pdf
```

Column requests are resolved against the actual TPS Report document definition. A requested field that does not exist is rejected rather than invented. A cost report therefore requires a real Cost/Amount field on the source format. PDF output uses the exact ooRexx PDF v0.1-dev3 flow/table engine.

## dev10 — Accounts spreadsheet export

Mini NotNotes can project any saved report into Spreadsheet Intentions dev6 `SpreadsheetTableData` and publish a new XLSX, ODS, CSV or TSV artifact. NotNotes remains authoritative for document selection, relationship traversal, calculations and business meaning; Spreadsheet owns tabular serialization and workbook creation.

Example:

```text
EXPORT Accounts Management TPS TO accounts-management-tps.xlsx
```

The export preserves ordered report columns, inferred business value types such as `MONEY`, and native Rexx provenance references to the source Mini Notes application and saved report definition. It deliberately does not edit arbitrary existing workbooks.


## dev14 renderer-neutral semantic application projection

Dev14 exposes application surfaces, bounded document collection ranges, document field semantics, live lifecycle action feasibility, subviews, saved reports and a generic intention entry point as native ooRexx objects. Renderers consume this contract rather than inventing NotNotes business navigation or lifecycle rules.
