# Validation summary — Staff Banking v0.3

Qualification runtime: ooRexx 5.3.0 r13196 Internal Test Version.

Qualification roll-up: `oorexxapis(20260828-191958).zip`, SHA-256 `5885f1906dc5ae7307e6fc7d557b88d1770b0c401f5a62063b999834222d5d66`.

| Staff Banking scope | Result |
|---|---:|
| Staff Authority v0.2 | 10/10 |
| Staff Authority Service v0.2 | 9/9 |
| Intermediary Staff Authority v0.1 | 6/6 |
| Staff Channel v0.1 compatibility | 8/8 |
| Staff Channel Service v0.1 compatibility | 9/9 |
| RID Wire UI with Wire UI Server v0.17 / Crypto v0.5 | 4/4 |
| Actual browser → WebSocket/Web Gateway → Queue Fabric → RID Wire UI | 1/1 |
| Staff Method Permissions v0.1 | 7/7 |
| **Staff Banking v0.3 total** | **54/54** |

Supporting generic dependency qualification (not double-counted above):

| Dependency scope | Result |
|---|---:|
| ooRexx Access Permissions v0.1 against Crypto v0.5 | 6/6 |

Additional checks:

- `FederationBankStaffMethodPermissions.cls` compiled with `rexxc`.
- `FederationBankStaffMethodPermissionsRuntimeModule.cls` compiled with `rexxc`.
- Staff Method Permissions `TestSupport.cls` compiled with `rexxc`.
- Staff Method Permissions package `MANIFEST.sha256` verifies fully.
- Staff Channel Service `test_runtime_module.rex` was rerun separately and passed after a prior outer combined-run timeout; no product assertion failed.
