# NotNotes Web v0.3 — actual Chromium/Wire acceptance, 2026-11-15

Status: **LOCAL_PASS for the listed real-browser journeys; identity stability FAIL**.
This is a loopback-only development test, not a production admission or a
complete independent human UX signoff.

## Executed environment and authority

- Real Chromium 156.0.8078.79 GUI on Linux/Xfce, not a mock DOM.
- ooRexx 5.3.0 r13196 from the pinned v0.3 package.
- `MiniNotesApp` dev13 -> Wire UI Server v0.17 -> ObjectQueueManager ->
  Queue Fabric Web Gateway v0.2 -> Alchemy Wire UI JS BrowserRenderer.
- `run-demo.sh` serving `live.html` and WebSocket on `127.0.0.1` only;
  a freshly created disposable local NotNotes database, not an estate store.
- No modification to application authority in browser JavaScript.

## Observed in the genuine browser

| Journey | Observed result |
| --- | --- |
| HTTP shell, WebSocket and authoritative Wire handshake | Header progressed from transport connected/loading to **View ready**, then rendered five server-owned documents. |
| Select document row `SEC-2001` | Selected key, title, risk and field projection switched to the security review. |
| Approve `PR-1002` | Status changed `PENDING APPROVAL` -> `APPROVED`; displayed document revision 3 -> 4; feedback `NOTNOTES.APPROVE : APPROVED`. |
| Create document via real HTML fields | Amount `42`, title `Chromium verified request`, type `Purchase Request` produced `PR-1003`; total documents 5 -> 6; selected new document and feedback `NOTNOTES.CREATE_DOCUMENT : CREATED`. |
| Read intention `show views` | `READY · SHOW_VIEWS · FEASIBLE` from the Intention Service. |
| Unsupported intent phrasing | `set title CHROME-INTENT-CONFIRMED on PR-1003` returned `UNKNOWN`, with no document mutation. |
| Confirmed intention write | `from notnotes set title to Chrome-confirmed on PR-1003` yielded `CONFIRM · SET_FIELD · FEASIBLE`; explicit `yes` yielded `READY` and projected title `CHROME-CONFIRMED`. |
| Stop service; restart fresh ooRexx backend with the *same* disposable database; reload Chromium at new loopback port | **View ready**, six documents, `PR-1002` still approved, `PR-1003` still amount 42 and title `CHROME-CONFIRMED`. |

These are observed browser action/reaction results, not only synthetic
`acceptance-dom.mjs` assertions. The service was shut down after testing.

## Distinct defect: transient `documentId` after persistence reload

The browser's row identity is projected directly from the authoritative
`document~documentId` (`NotNotesWebProjectionPort.cls`). The *same logical
documents* reopened from the persisted file store under different IDs:

| DocKey | Before shutdown | After fresh restart |
| --- | --- | --- |
| `PR-1001` | `MININOTES/DOC/2` | `MININOTES/DOC/1` |
| `PR-1002` | `MININOTES/DOC/3` | `MININOTES/DOC/2` |
| `REL-3001` | `MININOTES/DOC/5` | `MININOTES/DOC/3` |
| `SEC-2001` | `MININOTES/DOC/4` | `MININOTES/DOC/4` |
| `SUP-001` | `MININOTES/DOC/1` | `MININOTES/DOC/5` |

Root-of-contract observation: `MiniNotesPersistence.cls`'s `documents`
table stores `doc_key`, title, form, fields, workflow/status but *not*
`documentId`. `restoreDocumentRecord` composes a new document and restores
`DocKey` without restoring the original `documentId`. Identity allocation
therefore depends on the order returned by persistence. This is not fixed by
changing the HTML or calling DocKey an identity.

`notnotes_wire_demo/test-identity-restart.sh` independently proves the defect
with **two fresh ooRexx processes** and a temporary store:

```text
IDENTITY_CAPTURE=5
IDENTITY_DRIFT key=PR-1001 before=MININOTES/DOC/2 after=MININOTES/DOC/1
IDENTITY_DRIFT key=PR-1002 before=MININOTES/DOC/3 after=MININOTES/DOC/2
IDENTITY_DRIFT key=REL-3001 before=MININOTES/DOC/5 after=MININOTES/DOC/3
IDENTITY_DRIFT key=SUP-001 before=MININOTES/DOC/1 after=MININOTES/DOC/5
IDENTITY_REOPEN_MATCH=1 DRIFT=4 MISSING=0
```

Native exit code: **1 (FAIL by design)** under both the pinned dev13 and
the separately staged dev18 source with four diagnostic-only syntax corrections
and explicit `MININOTES_DB_BACKEND=file`. The regression never touches
production data; it does not attempt schema migration or mutate core source.

## Reproduce and boundaries

```bash
cd /path/to/extracted/notnotes_wire_web_v0.3
bash notnotes_wire_demo/test-demo.sh
bash notnotes_wire_demo/test-identity-restart.sh  # expected RED until core fix
bash notnotes_wire_demo/run-demo.sh              # inspect using local Chromium
```

The core owner needs to define and preserve a stable, authoritative document
identity across persistence and clustering, then revise the store contract
with migration/rollback and run this regression green. The consumer should
continue to project the authoritative identity, not manufacture a replacement.

This does **not** qualify full multiuser browser isolation, all format/report
controls in Chromium, accessibility, mobile/Firefox rendering, actual 10k-row
bounded demand, signing/LDAP, HTTPS/WSS or external deployment.
