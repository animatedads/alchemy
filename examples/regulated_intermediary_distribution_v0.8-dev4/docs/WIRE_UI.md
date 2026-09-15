# RID Wire UI v0.7

## Purpose

Server-authoritative regulated-intermediary surface showing exact provider status, required work, evidence/signing state and historical progress, with separate platform Access Control, exact method/object Permission and result-revision command authority.

## Compiled release

Operational definitions:

- `RID_APP_SHELL@1`
- `RID_SUMMARY@1`
- `RID_CASE_QUERY@1`
- `RID_CASE_TABLE@1`
- `RID_CASE_ROW@1`
- `RID_CASE_DETAIL@1`
- `RID_SIGNING_PANEL@1`
- `RID_CASE_TIMELINE@1`
- `RID_TIMELINE_ROW@1`

Compiled release: `FEDERATION_RID_INTERMEDIARY` / `2026.08.28.3`.

## Workspace and result authority

Workspace `RID.CASES` owns filter/query, sort/order, visible scope and semantic selection. v0.7 additionally publishes Wire UI Server v0.17 workspace result state.

The case table declares/binds:

```text
collectionRef filterRef sortRef anchorRef
windowOffset windowLimit windowTotalCount windowRevision
queryRevision scopeRevision orderRevision selectionRevision
resultRevision resultQueryRevision resultScopeRevision resultOrderRevision
```

Browser controls carry those server-issued revisions back with dependent actions. Undeclared patches trigger Alchemy resync; stale query/scope/order/selection/result context is rejected server-side.

## Security

The app cannot be built without a `RIDWireSecurityContext`. Runtime construction first requires positive Access Control for the access point.

Before every semantic action, RID maps the action to an exact protected object/class and calls Permission authority with a Security Effect assessment. Availability flags (`canAcknowledge`, `canPrepareSignature`, `canSubmitSignature`) are presentation projections only.

The application shell also projects `principalId`, `roleName` and `accessDecisionRef` for operator context/audit.

## Commands

- `DASHBOARD.REFRESH`
- `CASES.FILTER`
- `CASES.SORT`
- `CASES.SELECT`
- `CASE.OPEN`
- `WORK.ACK`
- `SIGNATURE.PREPARE`
- `SIGNATURE.SUBMIT`

All are exact Permission-gated; workspace-bound commands additionally require current Wire UI command/result context.

## Case timeline

Timeline rows retain exact semantic kind and evidence/source identity for case lifecycle events, accepted provider statuses, evidence and work outcomes. Current provider state remains the authoritative case projection and is not reconstructed from timeline prose.

## Signing

Signer/document/purpose/authentication/consent semantics are frozen by the one-time server challenge. The browser sees immutable document identity/version/digest/storage/durable-medium data and returns only permitted cryptographic response material. Signing action visibility and signing authority are separate; submit is re-permissioned against the challenge's exact work item.
