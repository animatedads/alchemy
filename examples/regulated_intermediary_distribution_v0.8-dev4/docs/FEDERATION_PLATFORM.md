# Federation regulated intermediary platform — v0.7 executable surface

## Home dashboard

The home surface is a regulated work dashboard, not an inbox. It shows exact current provider/work truth under server-owned filters/sorts and result revisions.

Primary attention groups:

- **Overdue** — Queue Fabric TTL expired while action remains outstanding;
- **Action required** — a concrete intermediary action follows from current provider/work state;
- **Waiting on provider** — provider is processing and no intermediary action is currently due;
- **Complete** — no outstanding intermediary obligation in the current work policy.

A row exposes product/provider truth, next action, priority/deadline, representative and exact provider event sequence. Historical provider/evidence/work progress is available in the case timeline.

## Security context visible to the desktop

The server shell projects the authenticated principal reference, presentation role and Access Control decision reference. These fields explain the operating context but do not themselves grant authority.

The server controls whether actions are presented using a Permission-policy preview. Every action is re-authorised on invocation against the exact object and method plus Security Effect.

Examples:

- VIEWER can enter/read but is not offered ACK/sign controls;
- ADVISER can be permitted ACK/signing;
- COMPLIANCE/ADMIN profiles can have different exact method policies;
- a browser that re-enables a hidden control still cannot invoke a denied method.

## Result freshness

Wire UI Server v0.17 means “same selected case” is no longer sufficient command authority.

If CASE-100 is selected at provider state `APPROVED`, then a signed provider event changes it to `DECLINED`, the server publishes a new result revision. A command prepared against the APPROVED result is rejected even when query/scope/order/selection revisions have not changed.

The user must act against the current authoritative result.

## Mortgage example

```text
Provider status: APPROVED
Attention:       ACTION_REQUIRED
Next action:     REVIEW_MORTGAGE_APPROVAL
```

A later signed `DECLINED` event updates that same semantic case row, supersedes approval work, advances the result revision and invalidates commands captured from the old result.

## All Japan example

```text
Provider:        ALL_JAPAN_INSURANCE_CO_LTD
Provider status: QUOTED
Attention:       ACTION_REQUIRED
Next action:     PRESENT_INSURANCE_QUOTE_AND_SIGN
Completion:      SIGNATURE
```

Signing requires current workspace/result authority, exact signing-method Permission and the existing sealed one-time challenge.

If All Japan reports `BOUND` before required distribution signing is complete, RID still renders `BOUND` as provider truth and raises critical `REVIEW_UNSIGNED_PROVIDER_COMPLETION` work.

## Digital execution

The case/signing surface shows:

- document semantic identity/version;
- digest;
- immutable storage reference;
- durable-medium reference;
- required signer/role/purpose;
- authentication and consent evidence;
- envelope/signature state and completion evidence.

Routine print-sign-scan is not the platform design.

## Federation employee use

The supplied Federation Staff Authority/Intermediary Staff Authority components are a separate business-authority path for Federation employees. Future employee `INTRODUCE`, `ADVISE` or `ARRANGE` actions should require their INSTITUTIONAL staff authority **and** the employee-to-RID representative binding **and** normal RID regulatory authority. That is additional to platform Access Control and exact method Permission, not a replacement for either.
