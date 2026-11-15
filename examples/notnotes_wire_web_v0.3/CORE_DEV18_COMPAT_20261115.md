# Mini NotNotes dev18 ↔ NotNotes Wire Web v0.3 — native compatibility investigation

Date: 2026-11-15. Status: **NOT QUALIFIED for a dev18 release or SQLite product default**.

This is consumer-owned evidence; the Mini NotNotes core and database provider
remain separately owned. No production database or persisted corpus was opened.
The v0.3 consumer's accepted baseline remains MiniNotesApp dev13.

## Exact source under test

| Input | Source identity |
| --- | --- |
| Wire v0.3 runnable ZIP | SHA-256 `0187ea35a47f8055bdf4ff046aeb5afce28b29ec620dec9fe0235a1794af66ed` |
| Git Mini NotNotes | `animatedads/alchemy`, `packages/notnotes_mini_approval_app_v0.1-dev18/` on `main`, inspected at `5f72fdced4a3` |
| `MiniNotesApp.cls` | Git blob `41ce8e206f8bd7f2a623c2564dfbedebf6ac4cbb`; SHA-256 `b88d2f63ae496079974cd76a998b557a4a817a6cfc7269975a89103dcf0e4ebe` |
| `MiniNotesPersistence.cls` | Git blob `9082b0838a18accb27c98a52f82e9328ea9bc569`; SHA-256 `73e683423d32b9afc84465f1364bcd7a1040f278c356e4103f76b390d6f7d7ca` |
| Interpreter | ooRexx 5.3.0 r13196, from v0.3's pinned Debian package |

## Native results

1. Unmodified v0.3 archive: both `acceptance-stack.mjs` and
   `acceptance-dom.mjs` PASS against real MiniNotesApp dev13 and Queue Fabric.
2. Exact Git dev18 overlay, `MININOTES_DB_BACKEND=file`: **FAIL** before Wire
   session startup at `MiniNotesApp.cls:799`, invalid `\\==` expression.
   Additional blocking source defects located at `MiniNotesApp.cls:59` and
   `:1207` (`\\` where unary `\` or inequality `\==` was intended), and
   `MiniNotesPersistence.cls:494` (`= \==` where `\==` was intended).
3. An isolated diagnostic overlay correcting **only those four expressions**
   and supplying published dev18 `ConnectSelector.cls`, `SingleTime.cls`,
   and `TzifZoneProvider.cls`: complete live Wire/Queue/application test **PASS**.
   Receipt: 19 accepted, six intentional refusals, zero server errors;
   persisted custom format, typed field (175), document reference, report,
   selected approval, confirmed intention write and fresh interpreter reload.
4. Explicit dev18 SQLite selection with the isolated new-store probe:
   **FAIL CLOSED**, because `DatabaseBackendSelector.cls` is absent from the
   test environment. No silent switch to FileDatabaseEngine; no new Wire access
   point. This does **not** establish actual SQLite I/O, migration or signing.

## Reproduce in an isolated test tree

```bash
bash examples/notnotes_wire_web_v0.3/notnotes_wire_demo/test-core-dev18-compat.sh \
  /absolute/path/notnotes_wire_web_v0.3_20261111.zip \
  packages/notnotes_mini_approval_app_v0.1-dev18
```

The first command deliberately exits nonzero against unmodified Git dev18.
For differential diagnosis **only**, append `--diagnostic-overlay`. The
overlay modifies a temporary extracted copy using
`diagnostic-dev18-syntax.patch`; it never patches the core checkout. It also
runs the isolated SQLite provider-availability probe. A diagnostic PASS is
not a product acceptance or permission to use that overlay in production.

## Owner gates

- `notnotes-core`: repair and native-qualify the four source expressions; add
  an app-loading regression that catches errors hidden in unexercised methods.
  Re-run this consumer harness **without** the diagnostic overlay.
- Core/provider owners: qualify the existing indexed Rexx/SQL SQLite selector
  and native extension, explicit verified migration, rollback/restart,
  954/10k workloads, temporal semantics, NULL/empty/CRLF integrity, security
  signatures and policies. Do not substitute dev13 file storage by default.
- Consumer/runtime owners: maintain renderer neutrality and then qualify
  actual Chromium interaction, multiuser isolation, LDAP/mTLS admission,
  HTTPS/WSS and deployment. None of these are covered by the pass above.

Keep PR #144 draft pending these gates. This is an additional test and handoff,
not a source upgrade of the v0.3 consumer to dev18.
