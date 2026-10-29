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
