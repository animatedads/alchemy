# NotNotes Wire Web — consumer application continuity (candidate v0.1)

**2026-11-11. Scope: NotNotes browser application on the renderer-neutral Wire UI runtime.**

Ownership lane on Rasen Falcon: `notnotes-wire-web` (CHATGPT). This is a **consumer** lane; it does not own MiniNotesApp's persistence implementation, the shared Wire UI Server, Queue Fabric, Intention Service, LDAP, HTTPS or product admission authority.

## Local executable delivery

Artifact: `notnotes_wire_web_v0.3_20261111.zip`
SHA-256: `0187ea35a47f8055bdf4ff046aeb5afce28b29ec620dec9fe0235a1794af66ed`
Release type: **local development qualification**, not accepted production product or live deployment.

The complete runnable artifact is held in the originating ChatGPT delivery. The 18-file consumer-only source tree and exact dependency provenance are published on GitHub draft PR #144 (branch `notnotes-wire-web-v0.3-20261111`, head `d2b1056846083e02354fb49c6b66d6896b1346aa`). This is **not yet merged or an accepted product source closure**. Its executable entry is `notnotes_wire_web_v0.3/notnotes_wire_demo/run-demo.sh`. It includes a pinned ooRexx 5.3.0 r13196 installer and the dependency sources needed for isolated local qualification.

## Actual native qualification

A clean ZIP extraction verified **206/206 manifest entries**. The full local `bash notnotes_wire_demo/test-demo.sh` passed under the bundled r13196 interpreter, exercising real `MiniNotesApp` via `WireUIApplication` / Wire UI Server v0.17 / ObjectQueueManager / Queue Fabric Web Gateway v0.2 / Alchemy Wire UI JS v0.4-dev6.

Results confirmed via the actual WebSocket gateway and instrumented Alchemy BrowserRenderer DOM (not mocked business logic):
- select/reselect; approve; create and edit a standard document;
- Intention Service read and explicitly confirmed write, with exact document target;
- define typed user document format `Purchase Checklist`, complete `PC-0001`;
- update MONEY field to 175, link to PR-1002 and unlink PR-1001;
- author and run saved report `Checklist totals`, returning one real row for Casey/175;
- explicit refusal of duplicate format, invalid numeric field, invalid reference, missing report, repeat approval, and empty-title creation;
- fresh **separate ooRexx interpreter** reloaded the custom format, document, typed field, relationship and saved report.

Development backend receipt: 19 handled accepted requests; six explicit domain refusals; **zero unexpected server errors**. One authoritative grouped Wire view revision per accepted action. Corrected inherited action-result inversion: accepted operation produces success, refused operation produces failure and visible status.

Local launcher HTTP /live.html and /wire-ui/bootstrap both returned HTTP 200; browser automation with instrumented DOM passed. **Independent human Chromium interaction was NOT qualified**, and is an outstanding user-acceptance gate.

## Scope and controlled gaps

The v0.3 consumer still runs against **MiniNotesApp dev13** from the original October 2026 functional line. Rasen Falcon `notnotes-core` points to later Mini NotNotes dev18; the two MUST be reconciled against persistence schema, indexed RexxSQL SQLite provider selection, signed state, migrations and renderer-neutral semantics before product promotion.

No implementation or qualification of LDAP/mTLS multiuser admission, production HTTPS/WSS, encrypted/signed deployment, independent server sessions, full schema evolution, visual relationship designer, report export, replicated document management or 10k-corpus bounded query plan is claimed. The local development authority tuple/token and loopback-only HTTP server MUST NOT be exposed as an externally reachable service.

## Relevant existing spheres

- `alchemy-notnotes` v0.1: domain / approval authority.
- `wire-ui-builder` v0.3: builder / source reference; includes a NotNotes Web article.
- `wire-ui-runtime` v0.4: readiness / runtime conformance. Production HTTPS/WSS remains NOT_QUALIFIED.
- `wire-ui` v0.1: renderer-neutral authoritative presentation semantics.

## 2026-11-15 — dev18 native boundary investigation

The v0.3 acceptance harness was rerun under exact ooRexx r13196: baseline dev13 PASS. Against published Mini NotNotes `dev18` Git source, the **unmodified** source FAILS before Wire startup at `src/MiniNotesApp.cls:799` (invalid `\\==`). The same Git tree has three additional invalid expressions: `MiniNotesApp.cls:59`, `:1207`, and `MiniNotesPersistence.cls:494`. Source identities: MiniNotesApp Git blob `41ce8e206f8bd7f2a623c2564dfbedebf6ac4cbb`; persistence blob `9082b0838a18accb27c98a52f82e9328ea9bc569`.

A *disposable test-only four-expression repair* plus the exact dev18 ConnectSelector/SingleTime/TzifZoneProvider sources completed the live Wire/Queue/NotNotes journey in explicit `MININOTES_DB_BACKEND=file` mode: **19 accepted, six expected refusals, zero server errors, persisted formats/fields/references/report and intention confirmation/restart PASS**. That is conditional evidence only, **not** a raw dev18 qualification. The separate SQLite startup probe failed closed because `DatabaseBackendSelector.cls` was unavailable: native indexed SQL, 954/10k corpus, signing, migration and production admission remain **NOT_QUALIFIED**.

The reproducible exact-source vs diagnostic-overlay harness and full matrix are on draft PR #144 at `examples/notnotes_wire_web_v0.3/notnotes_wire_demo/test-core-dev18-compat.sh` and `CORE_DEV18_COMPAT_20261115.md`, commit `8a71be4a03c2bb621315c0c14b9f81ce7c382cd8`. Core owner notified in Rasen Falcon `REQ-00003609`; await its accepted source fix, then rerun without test-only modifications. No core files or production stores were changed by this consumer lane.

## 2026-11-15 — real Chromium action/restart acceptance and identity regression

A local Xfce Chromium 156 GUI was connected to the actual loopback-only v0.3 Wire host with a disposable database. The browser reached **View ready** after authoritative definitions and snapshot, then successfully selected SEC-2001; approved PR-1002 (revision 3→4); created PR-1003 (amount 42, document count 5→6); completed a `show views` intention; refused an unknown phrasing without editing; and required explicit `CONFIRM` then `yes` to change PR-1003 title to `CHROME-CONFIRMED`. A fresh ooRexx interpreter restart, new Wire session and browser reload retained six documents, PR-1002 approval, PR-1003 amount and confirmed title. This is genuine Chromium renderer **LOCAL_PASS for the observed subset**, not an instrumented DOM simulation, full human UAT or production approval.

**New blocker:** persisted `DocKey` data survives restart, but several authoritative `documentId` values do not. PR-1001 `MININOTES/DOC/2→/1`, PR-1002 `/3→/2`, REL-3001 `/5→/3`, SUP-001 `/1→/5`; SEC-2001 remains `/4`. Two separate native ooRexx processes reproduce `IDENTITY_CAPTURE=5`, `DRIFT=4`, `MISSING=0`, exit 1, on dev13 and on the dev18 syntax-corrected diagnostic file backend. The persistence record stores DocKey but not documentId and restore composes a new document. This is a **core-owned identity persistence/revision contract issue**; the browser must not invent its own ID to conceal it. Core request `REQ-00003639` records the exact keys and source paths.

The consumer source, actual-browser acceptance matrix and expected-RED identity regression are committed to draft [PR #144](https://github.com/animatedads/alchemy/pull/144) at `d2b1056846083e02354fb49c6b66d6896b1346aa`, notably `REAL_CHROMIUM_QUALIFICATION_20261115.md` and `notnotes_wire_demo/test-identity-restart.sh`. Previous dev18 raw syntax blockers remain in `REQ-00003609`; SQL, full format/report GUI, mobile, HTTPS/LDAP and multiuser tests are still open. Local testing stopped its services; no live deployment or estate store was changed.

**Status:** real Chromium selected workflow LOCAL_PASS, native identity stability FAIL (4/5 drift), raw dev18 startup BLOCKED, SQL/migration/security/production NOT_QUALIFIED. PR #144 draft/unmerged. GitHub PR #144 stays draft and unmerged.
