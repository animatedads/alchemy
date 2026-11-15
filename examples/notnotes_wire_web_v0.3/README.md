# NotNotes Web / Wire v0.3 — runnable local integration

**11 November 2026. Development qualification, not production certification.**

This revision extends the functional v0.2 integration and is explicitly a consumer-side development candidate, not an accepted Mini NotNotes release. The UI is a renderer of an authoritative **ooRexx** MiniNotesApp; neither NotNotes business state nor Intention Service decisions are implemented in JavaScript.

## Run

Linux x86-64, Node.js 22+, `dpkg-deb`, and a normal local web browser are required. A matching ooRexx 5.3.0 r13196 Debian package is bundled and unpacked without root permissions on first launch.

```bash
cd notnotes_wire_web_v0.3
bash notnotes_wire_demo/run-demo.sh
```

The launcher prints the actual local HTTP URL (`http://127.0.0.1:<assigned-port>/live.html`) and runs the real queue-facing ooRexx application, Wire UI Server, Queue Fabric backend, gateway, and Alchemy browser renderer. Stop with Ctrl-C.

Documents now persist by default under `$HOME/.local/share/notnotes-wire-demo`. Override for a private/test database:

```bash
NOTNOTES_DATA_DIR=/path/to/notnotes-db bash notnotes_wire_demo/run-demo.sh
```

On an existing ooRexx installation, specify `OOREXX_HOME=/path/to/prefix` if required. The five sample records are inserted **only for an empty database**. Do not point this development application at a production database.

## Available operations

- Select a document from the real Wire collection to view its fields, identity, risk and workflow status.
- Create an `Approval Document`, `Purchase Request`, `Security Review`, or `Release Authorization` by entering its exact document type, title, amount, risk (LOW/MEDIUM/HIGH), and optional existing dependency key(s). The ooRexx application assigns a durable document key and applies its ordinary workflow.
- Edit the selected document's title, amount, and risk using the authoritative NotNotes document API, and save explicitly.
- Submit, approve, and reject through NotNotes workflow operations. Invalid operations report **REFUSED** with the domain reason; clicking Approve on an already approved document does not silently pretend to succeed.
- Send a request to the **actual Intention Service**, e.g. `show views` or `from notnotes set title to Revised order on PR-1003`. Reads are handled immediately; writes require explicit confirmation (`yes` or `no`). Feasibility, authority and write admission remain with Intention Service / NotNotes.
- View a live result/status message for actions and intention admission; the header differentiates `Transport connected` from `View ready`.

The browser forms are generated from server-owned Wire `FORM` definitions and ordinary metadata bindings. The only browser-runtime adaptation is a generic optional `submitLabel` field for accurate form labels. No NotNotes business rules were added to JavaScript.

## New in v0.3 — real document/schema/report operations

The browser now uses server-owned Wire forms for these operations, all delegated to ooRexx MiniNotesApp:

- **Define document format**: give a format name and up to 16 semicolon-separated typed field specs, `NAME|Label|TYPE` (e.g. `OWNER|Owner|TEXT;COST|Cost|MONEY`). Types accepted in this cut: `TEXT`, `NUMBER`, `MONEY`, `USER_REFERENCE`, `DOCUMENT_REFERENCE`. For document references, append `|Existing Target Format|ONE` or `|Existing Target Format|MANY`. Schema edits are additive in core but not yet exposed in this browser cut; duplicate/reserved fields and unknown reference types are refused.
- **Complete user-defined document**: specify a saved format and values as `FIELD=value;FIELD=value`. A real domain document, key and persistent fields are created; invalid reference targets are refused.
- **Edit typed field**: set a field on the selected user-format document, with domain validation (e.g. nonnumeric MONEY refused).
- **Link/unlink** references: select a user-format document, enter its DOCUMENT_REFERENCE field and an existing target key. Domain cardinality and target-format restrictions apply.
- **Design saved report**: choose name, source format, and up to 16 columns, `Label=BINDING;Label=BINDING`; domain resolves exact field/report bindings.
- **Run saved report**: execute through MiniNotesApp and display text and row count from the resulting report definition. No PDF export is exposed in the browser yet.

The format and report catalogue is a Wire projection from `userFormatNames` and `reportDefinitionNames`. The v0.2 semantic action-response inversion was fixed: accepted actions now return `WireUIResult~success`; refused actions return `WireUIResult~failure` with visible reason.

## Regression and acceptance

```bash
bash notnotes_wire_demo/test-demo.sh
```

This launches the **real ooRexx backend** and actual Queue Fabric WebSocket edge, using both Alchemy `MemoryRenderer` and `BrowserRenderer` (instrumented DOM). It verifies selection, approval, creation, editing, Intention Service read/confirmed write, custom format creation, user document completion, typed-field edit, link/unlink, saved-report creation and execution, refusal feedback, and a fresh interpreter reload of formats, fields, references, reports, and document approval.

## Fixes from the first handover

1. The first deliverable only exposed select/approve/reject in the Wire view, despite richer domain APIs. v0.2 wires creation, editing, saving, submission and intention input to ooRexx and creates server-defined forms.
2. The initial host emitted a separate view revision for every changed UI field, causing rapid clicks to be rejected as stale. v0.2 binds a derived **group projection** so each accepted domain action emits **one atomic view revision**.
3. On action refusal, the host previously discarded any error projection because it drained outbound messages only after successful actions. v0.2 drains authoritative patches on both success and refusal.
4. The inherited NotNotes domain intention interrogator matched generic values such as `0`, which could select an unrelated first document. The recovered intention adapter now prioritises exact document keys / stable IDs and only then sufficiently long titles; it never uses numeric or generic field values to guess a target.
5. The old launcher deleted its temporary database when stopped. v0.2 uses a persistent user-owned database directory by default.

## Boundaries / remaining product work

This is **not** yet the full NotNotes product. The browser does not yet expose complete schema evolution, general typed-field widgets, visual relationship designers, report export, complex queries, replication management, account/LDAP integration, multiuser session isolation, production HTTPS/WSS, or operational deployment. This release runs with a single local development identity and development-only bridge token, bound to 127.0.0.1. Do not expose the services externally.

Full independent Chromium acceptance is **not qualified** here: Chrome's policy denied navigation to the local URL with `net::ERR_BLOCKED_BY_ADMINISTRATOR`. The DOM tests exercise the actual Wire browser renderer and actual WebSocket gateway, but use a test DOM. Browser appearance and operator usability should still be qualified in a normal local browser.

The matched code base uses MiniNotesApp dev13, Wire UI Server v0.17, Queue Fabric Web Gateway v0.2, Alchemy Wire UI JS v0.4-dev6, Alchemy Objects v0.8, and recovered `AlchemyNotNotesIntentionRuntime` dev15 with Intention Service v0.1-dev11. All sources and the r13196 installer are included for reproducibility. The patched intention source is included separately from the source-of-truth lineage; it is not a silent claim that upstream has incorporated the fix.

## Rasen Falcon sphere/ownership status (2026-11-11)

- New `notnotes-wire-web` lane exists for this consumer app; no ownership of Mini NotNotes persistence or Wire shared runtime internals is implied.
- `alchemy-notnotes` sphere v0.1 provides domain authority context; `wire-ui-builder` v0.2 and `wire-ui-runtime` v0.4 are separately resolved.
- This package still pins MiniNotesApp dev13. The current NotNotes Git lineage reaches dev18. A tested, explicit compatibility migration is required; no automatic data-store migration, SQL default, LDAP authentication or external HTTPS admission is claimed.
- Production HTTPS/WSS and signed application admission remain **NOT QUALIFIED**.
