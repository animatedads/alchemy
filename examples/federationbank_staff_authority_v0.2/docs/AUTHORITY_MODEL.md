# Staff Authority Model

## Normal role assignment

A role assignment is an organizational fact with provenance and an effective period. Its `roleClass` is resolved through Staff Authority policy; the assignment itself does not contain executable banking permission.

## Delegation

Delegation is temporary authority granted to a named staff member. It must have authority evidence and an end time. It may further restrict operation/branch/amount scope, but cannot raise the policy ceiling for the delegated role.

## Elevation

Elevation is separate from delegation and is intended for explicit short-lived exceptional authority such as a cash override. A rule may require a named elevation class. The elevation must be active, evidence-backed and in scope for the action.

## Maker/checker

A rule contains a maker ceiling and, where applicable, a checker ceiling/class/count. Actions above the maker ceiling return an approval-required decision rather than being silently denied when the policy permits an independent checker route.

Every approval:

- names the approver staff/session;
- names the approval class;
- is bound to the action's semantic identity;
- has evidence and time;
- is revalidated against the approver's own staff context;
- can be rejected when policy requires a distinct maker/checker.

## Exact action binding

The action contains both business data and institutional context: command/idempotency identity, actor/session, operation, customer, source/target accounts, amount/currency, branch/desk, optional relationship case and request time.

The positive envelope is therefore an authority for **one exact action**, not a bearer capability for a whole role.
