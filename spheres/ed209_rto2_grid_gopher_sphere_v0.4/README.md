# ED209 RTO2 Grid Gopher Sphere v0.4

This sphere records implementation boundaries, field evidence, controller design, identity/authorization integration and acceptance criteria for the ten-MU / twenty-MI RexxOS ED209 Grid.

Use `gopher --profile ed209-rto2-grid context ed209-rto2-grid --full` after installing the sphere profile and pack.

**Status:** the generic RexxOS controller line is evidenced through Grid dev15 plus the dev16 Identity Directory authorization increment. ED209 remains the distinct ten-MU/twenty-MI field estate, and there is still **no confirmed live 20/20 RTO2 run** and no accepted service-first XTP dev30 end-to-end ten-MU deployment.

## Delivered since v0.3

- ED209 RTO2 candidate3, including the redacted typed R-11 MU wrapper failure classification, is published directly on GitHub main at commit `5c6e9d0e7abed38e5e2b2cdb9e3fbf0acd052532` under `packages/ed209_rto2_20mi_candidate3`.
- Grid dev16 identity increment is published directly on main at commit `d7f3de97d8d8d12d120ac6cdd77c71b0ab8c6b30` under `packages/rexxos_rto2_grid_v0.1-dev16-identity-increment`.
- The dev16 increment consumes the neutral ooRexx Identity Directory/LDAP model and ACL authority. It does not implement Bind, credentials, TLS, placement, transport selection or serialization.
- Library LDAP Identity dev22 is the inspected identity source for this seam. Its archive SHA-256 is `697c301c37ad1d77252a34db9028420c4c9a3e3dbe5c60de9be6fc91940341fc`.
- GitHub XTP dev30 is the current source line. ED209 candidate3 still uses the older segmented QFXTP field-compatible path; dev30 FIRST/KEY/DATA is not thereby field-qualified.

## Controller and identity boundary

- MU and MI remain first-class ooRexx estate objects; an MU is not automatically a compute slot.
- Grid owns estate identity, membership and observation. Job placement, WLU, Storage, Memory, XTP route selection, economics and failover promotion remain separate authorities.
- LDAP Bind/authentication is not Grid authorization. An approved authentication layer attributes a principal; Identity Directory ACL then decides the exact Grid service action.
- The Grid service resource is `rexxos://<GRID_ID>/service/rexxos.grid/0.1` with resource type `REXXOS_GRID`.
- Current read actions are `GRID.ESTATE.READ` and `GRID.MANAGEMENT.READ`. Missing attribution fails as `UNAUTHENTICATED`; missing ACL authority fails closed as `PERMISSION_DENIED`.
- ConnectSelector remains connector authority, RpcServiceCore remains explicit service dispatch, and serialization remains a binding/SerializationSelector concern.

## Transport and field boundary

- Operator SSH through `sshnode.sh` reaches owning MUs only; MI work must traverse authenticated Grid/Queue/XTP paths.
- MI↔owning MU remains XTP L2 EtherType 0x817D in the field design; non-Google MU↔MU uses raw IPv4 protocol 36; Google-involving routes use the approved UDP fallback.
- XTP dev30 fixes and hardening are source/local evidence, not field acceptance for the ten-MU estate.
- R-10 MI-only result attribution remains open. Candidate3's MU-held symmetric authentication plus durable receipt does not prove an MI-only signature.
- Reboot persistence, failover promotion and live 20/20 remain unaccepted.

## Provenance

- Grid dev15 archive SHA-256 `e94ba156182567752e7e3b86e88b6a0e8a25fb8710648bb373a4c33271226543`.
- Grid dev16 identity increment archive SHA-256 `4c817b5f8d8efff7d37e1f28064235040d08fbf5f452a2bf84cd79b0300d85b2`.
- LDAP Identity dev22 archive SHA-256 `697c301c37ad1d77252a34db9028420c4c9a3e3dbe5c60de9be6fc91940341fc`.
- Candidate2 field/source reference SHA-256 `940ee1835f9dd53ceea42a14e0eb7880e4dc374d6813cfbc686972debe23b4e1`.

## Acceptance gate

A single run ID must still produce twenty distinct authenticated and locally committed RTO2 receipts, one from each assigned MI route, all computing `500500`. Synthetic fixtures, source publication, LDAP authorization tests and XTP local tests do not substitute for that field gate.

Tracking: https://github.com/animatedads/alchemy/issues/17

## 29 October 2026 runtime qualification

Grid dev17 now passes two native r13196 LDAP Identity/RPC tests and five static tests; malformed service contexts fail with UNAUTHENTICATED rather than an opaque internal fault. This is not a field 20/20 RTO2 result.
