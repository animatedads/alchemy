# Initech NotNotes TPS Help Desk v0.1-dev5

A two-tier ooRexx support system for Initech's live NotNotes TPS application.

```text
employee chat
  -> Help Desk purpose / conversational handling
  -> live NotNotes discovery on every turn
  -> NotNotes application semantics / Intention Service
  -> authoritative NotNotes documents, reports and relationships
```

The Help Desk does **not** copy the TPS application into a static chatbot tool catalogue.
It re-discovers the installed report definitions and document formats for every turn and
uses the live NotNotes object graph for application meaning and feasibility.

## dev2 — management review application integration

This increment rebases the inner application tier on the supplied
`notnotes_management_review_dev8_delivery` application/data state. That state contains:

- the linked 12-report TPS baseline;
- `MRS-0001` Management Review Selection and its 12 linked selection items;
- `MCR-0001` Management Consultant Report;
- Time-and-Motion and Synergy consultant profiles;
- twelve linked Management Consultant Finding documents;
- persisted management-review and consultant saved reports.

Because saved reports are discovered live, ordinary chat requests such as:

```text
show the Management Review Selection Report
show the Report by the Management Consultants
```

run the installed NotNotes reports without adding dedicated help-desk commands.

### Linked consultant evidence

A request such as:

```text
what did the consultants find about TPS-2026-102 and what did they recommend?
```

is resolved through live NotNotes relationship semantics.

The Help Desk does not carry a TPS-number -> finding table. It inspects installed user
formats for a `DOCUMENT_REFERENCE` targeting `TPS Report`, discovers readable finding /
recommendation fields on that related format, and follows the stored document reference.
For the supplied management-review data that resolves `TPS-2026-102` to `TR-0002` and
then to `MCF-0002`.

A specific TPS evidence request wins over a broad report-name match. If the application
understands the TPS document but no live related finding exists, the result is
`INFEASIBLE` rather than pretending the intention was unknown.

## dev3 — the Help Desk TPS reports become support evidence

A Help Desk session TPS report is no longer merely write-only audit output. A later
Help Desk session discovers the ordinary live `TPS Report` and its linked
`TPS Report Review` through the installed NotNotes document-reference metadata.

Examples:

```text
show my successful Help Desk TPS processes
show failed Help Desk TPS sessions
what happened in TPS-HD-20261007-151234
```

The first two requests filter live TPS process records by owner and review rating.
The third follows the live `TPS Report Review -> TPS Report` relationship and returns
the authoritative review evidence. No separate support audit database or startup-only
index is introduced.

The same generic document-reference traversal now underpins consultant evidence lookup,
so management-review and Help Desk review both use the NotNotes relationship model rather
than separate hard-coded relationship implementations.

## Existing Help Desk behaviour retained

- dynamic report and format discovery on every chat turn;
- personal TPS report filtering through authoritative `User` fields;
- durable Business Log documents;
- NotNotes Intention Service as the inner semantic/application tier;
- optional LLM recognition fallback through the existing API Client contract;
- no LLM authority over NotNotes execution or persistence.

## Mandatory TPS process accounting

Every Help Desk session writes a real TPS Report when it closes, followed by a linked
TPS Report Review that records `SUCCESS` or `FAILURE` for the support process. The review
stores the stable TPS document reference rather than presentation text.

Thus the Help Desk itself participates in the TPS system it supports, and those session
TPS records immediately become ordinary live NotNotes business data for later sessions.

## Run

```sh
./run_helpdesk.sh alice
```

## Qualification

With ooRexx 5.3.0 r13196:

```sh
OOREXX_ROOT=/path/to/extracted-r13196 ./tools/run_environment_test.sh
```

See `QUALIFICATION.md` and the supplied environment qualification log.

## dev4 — consume NotNotes' live semantic application projection

The inner tier is now rebased to Mini NotNotes v0.1-dev16 / NoSQLServer v0.87.
The Help Desk no longer reconstructs application discovery by walking internal
report and document-definition collections. Each turn asks
`MiniNotesApp~semanticApplicationProjection` for the current renderer-neutral
application model and derives its visible formats/reports from that contract.

This matters because the Help Desk now consumes the same live semantic surface
as native/Windows renderers and other non-CLI consumers. A format/report added
at runtime is therefore discovered through NotNotes' own application contract,
not through a parallel chatbot catalogue.

The Help Desk also consumes `semanticDocumentProjection` for support questions
about current feasibility. For example:

```text
what can I do with BL-0001?
can I approve BL-0001?
```

A DRAFT document reports `SUBMIT: AVAILABLE` while `APPROVE` remains understood
but is reported as `INFEASIBLE` with NotNotes' authoritative reason (`Document
is not pending approval`). Meaning is not collapsed into availability.

`what reports are available?` is likewise answered from the current semantic
application projection and immediately sees reports installed after session
startup.

Relationship traversal is now cardinality-aware: reverse discovery accepts both
single and first-class MANY `DOCUMENT_REFERENCE` values introduced by Mini
NotNotes dev12.

### Consumer-discovered NotNotes dev16 projection repair

The Initech consumer probe exposed one dev16 defect in
`semanticReportDescriptors`: report `TOTALS` are an Array of binding names, but
the projection attempted to copy them as report-column Directories. Any live
saved report containing totals therefore raised `93.924` while building the
semantic application projection. This delivery carries the minimal consumer
repair (`definition["TOTALS"]~copy`) and regression coverage through the normal
Help Desk discovery path. No report execution semantics were changed.

## dev5 — live operational specialist discovery through Instrumentation Intentions

The outer Help Desk now consumes the common read-only
`instrumentation.intentions/0.1` specialist over the current Instrumentation
Mesh rather than learning a private NotNotes metric vocabulary.

Each Help Desk turn still starts with fresh application discovery. The same
discovery snapshot now includes provider-owned specialist surfaces. For the
NotNotes application the Help Desk publishes a fresh `MiniNotesInstrumentationSource`
snapshot into a bounded local Mesh collector and asks
`InstrumentationIntentionProvider` to assess the user's request against that
current evidence.

Examples include:

```text
show NotNotes health and metrics
how is NotNotes doing; show its telemetry
```

The returned evidence is explicitly read-only. The Instrumentation specialist
has no NotNotes workflow mutation or service-control authority. Business,
report and document intentions retain first refusal so the fact that a TPS
object is instrumented cannot steal ordinary TPS business requests.

Qualification proves freshness rather than startup discovery: the Help Desk
reads `notnotes.documents.total`, creates a real Business Log document through
NotNotes, asks for instrumentation again, and observes the increased document
gauge from a newly published snapshot.

The delivery vendors the current `oorexx_instrumentation_mesh_v0.1-dev7` and
`oorexx_instrumentation_intentions_v0.1-dev1` specialist contracts. Mini
NotNotes remains authoritative for application/workflow facts; Instrumentation
Mesh remains authoritative for snapshots/history/series; the Help Desk only
routes and presents the evidence.

### Qualification harness isolation

The retained Mini NotNotes tests now receive explicit isolated
`MININOTES_TEST_ROOT` / `MININOTES_DB_ROOT` roots. This fixes a qualification
harness defect where successive tests could otherwise fall back to the package
working directory and contaminate one another's durable tables. The aggregate
suite also exercises SUCCESS and FAILURE Help Desk TPS accounting, management
review relationships and instrumentation in one end-to-end consumer session.
