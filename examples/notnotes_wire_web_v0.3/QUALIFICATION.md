# NotNotes Web / Wire v0.3 qualification — 2026-11-11

## Runtime

- Interpreter: ooRexx 5.3.0 r13196, Linux x86-64, recovered installer.
- Business authority: `MiniNotesApp` and the recovered `NotNotesWebProjectionPort`.
- Intentions: `AlchemyNotNotesIntentionRuntime` / Intention Service v0.1-dev11; `NOTNOTES` domain.
- Wire UI Server 0.17 -> ObjectQueueManager -> Queue Fabric Web Gateway 0.2 -> Alchemy Wire UI JS 0.4-dev6.
- Access point AP1, single loopback local session S1 (development only).

## Results

All checks below were executed against the actual interpreter and backend, with the genuine WebSocket gateway, not browser-side simulated business logic:

| Case | Result |
| --- | --- |
| Interpreter startup and backend session | PASS |
| Wire UI_HELLO / definition delivery / authoritative snapshot | PASS |
| Live selection of `SEC-2001`, then `PR-1002` | PASS |
| Approval of `PR-1002`, persisted status `APPROVED` | PASS |
| New `Purchase Request` creation (`PR-1003`) through a server-owned Wire form | PASS |
| Edit selected document title/amount/risk through a Wire form | PASS |
| `show views` through real Intention Service | PASS |
| `set title ... on PR-1003` returned `CONFIRM`; explicit `yes` produced `READY` and committed the intended document | PASS |
| Refusal on reapproving an approved document shows `REFUSED NOT_PENDING` | PASS |
| Blank document title shows `REFUSED TITLE_REQUIRED`, no record created | PASS |
| Fresh ooRexx interpreter reloads `PR-1003` with final `INTENT-ADJUSTED` title | PASS |
| One view revision per accepted action (derived grouped projection) | PASS |
| User format `Purchase Checklist` defined with TEXT/MONEY/DOCUMENT_REFERENCE MANY fields | PASS |
| User document `PC-0001` completed through Wire form and persisted | PASS |
| Numeric field `COST` changed to 175; invalid nonnumeric edit refused | PASS |
| Relationship link PR-1002 and unlink PR-1001, persisted in fresh ooRexx interpreter | PASS |
| Saved report `Checklist totals` designed, executed and returned 1 row (Casey, 175) | PASS |
| Duplicate format, unknown report, invalid reference | PASS — explicitly refused |
| Real Wire semantic action success vs failure results | PASS — inverted result branch repaired |
| Chromium navigation to loopback URL | BLOCKED BY ADMINISTRATOR — not a visual qualification |

## Repeat

```bash
OOREXX_HOME=/path/to/oorexx bash notnotes_wire_demo/test-demo.sh
```

See `notnotes_wire_demo/wire-test-result.json`, `notnotes_wire_demo/wire-dom-test-result.json`, `notnotes_wire_demo/backend-last.log`, and `test-evidence.txt` for machine-captured evidence.

## Outstanding qualification

No claim is made for full Chromium operator acceptance, production identity/LDAP, TLS, signed application admission, multiuser isolation, replication, all NotNotes modules, or complete user-format/document/report design. The hardcoded local development authority tuple must be replaced before deployment.

## Release scope / evidence distinction

The tests above use actual ooRexx MiniNotesApp, Wire Server and Queue Fabric/WS gateway, and both MemoryRenderer and an instrumented BrowserRenderer fake DOM. A real human browser acceptance is not claimed. The test database is temporary; no production stores are touched. This package is a downstream consumer built against dev13 APIs, **not** evidence that dev18 or the selected indexed RexxSQL SQLite default have been integrated.
