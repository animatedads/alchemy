# Wire UI Windows — implementation and activation sphere
Date: 2026-10-29
Component lane: `wire-ui-windows`
Owner/principal: CHATGPT
Repository: `animatedads/alchemy`

## Authority and scope
This lane owns the Windows native renderer and its NotNotes desktop adapter, not the common Wire semantics, LDAP authority, HTTPS service, mail transport, or ED209 internode network. The renderer must consume semantic projections and emit semantic events; ooRexx owns business behavior, dynamic intentions, document authority and persistence.

## Reconciliation
Git `main` currently contains `packages/wire_ui_windows_v0.1-dev5`. The independently delivered NotNotes Windows client package reached `notnotes_windows_client_v0.1-dev7.zip`, SHA-256 `8b8522e211e64be2db5fa20371483774ae16c92ac12ae9b8bbd253cc50a25ac9`. That archive is **not** yet an accepted Git package. Do not mistake the version suffixes for equivalent source trees.

## Work and evidence
- Dev7 local qualification: 35 source/contract tests passed, 5 legacy tests skipped. No native Win64 build or runtime qualification.
- Dev7 changes: thread-queue ownership for pending events during F5 reprojection, CR/LF projection guard, updated source-level tests.
- Git's existing dev5 renderer still posts `WM_QUIT` on every `WM_DESTROY` and its thread pump has no F5 interception. This is an explicit baseline defect, not proof of dev7 integration.
- Real NotNotes bounded document list, selected-document detail, persistence and complete intention session are not yet accepted on Windows.

## Estate critical path
The Windows UI is a consumer of, not a substitute for, native HTTPS, LDAP identity, durable SMTP/IMAP, and XTP MU↔MI communication. Do not implement separate Windows business or security policy to bypass missing services. The service-activation programme must install and qualify those upstream providers independently.

## Required acceptance
1. Import the complete newer Windows source via the repository's prescribed two-commit Autobuild submission protocol. Autobuilder is currently stopped; preserve submission as pending, not accepted.
2. Build on Win64 against the actual ooRexx portable SDK.
3. Run snapshot, text intention, document persistence, TPS session close and F5 reprojection tests in a real native process.
4. Record source/staged/installed/running status separately; no production cutover without approval.

## Coordination
Rasen Falcon mailbox lane `wire-ui-windows`; request `REQ-00001073` notified COORDINATOR of dev7 qualification and deployment gate.

## 2026-11-11 implementation increment
The Git baseline's `wide()` helper allocated `n-1` UTF-16 code units then passed `n` to `MultiByteToWideChar`, allowing a one-code-unit write past the buffer end. Commit `0d5ee6e` now allocates the complete converted size including the terminating NUL, validates conversion and then removes the terminator. Commit `9b0b323` adds a regression source check. This is a concrete renderer memory-safety repair, not Win64 runtime qualification. The dev7 archive is present in the conversation workspace but has not been imported into Git as a complete package; direct Git from this runtime cannot resolve github.com, and the connected Git provider accepts individual file writes.

## 2026-11-11 Rasen Falcon sphere reconciliation
Checked Rasen Falcon sphere.list: no discoverable sphere for Windows; the closest published shared contract is `wire-ui-runtime` v0.4. Its `ref.wire-ui-runtime.renderer-conformance` article requires ten canonical transcript gates: exact definitions, approved ResourceRef, revision commitment, stable collection identity, bounded RangeRequested, UI_ACTION with event-time renderedRevision/workspaceContext, semantic activation, positive-list observation, and fail-closed deauthorisation/resync. The Windows source is **not** qualified against this transcript; do not count these gates as PASS.

The shared sphere also requires exact source/hash reconciliation before promotion and warns against confusing an independently delivered package with a Git-accepted version. This branch is not part of the live Rasen Falcon sphere index until published/accepted by the catalogue pipeline.

Lane verified via Rasen Falcon `project.lanes.search wire_ui_windows`: `wire-ui-windows`, linked artifacts `wire_ui_windows` and `notnotes_windows_client`. Rasen Falcon unread mailbox has no incoming coordinator replies as of this check.
