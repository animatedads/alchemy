# FederationBank Staff Authority v0.2

Policy-driven employee authority for FederationBank staff actions. v0.2 makes authority **scope** explicit: `CUSTOMER` for ordinary Core Banking customer actions and `INSTITUTIONAL` for employee actions performed under a separate institutional/regulatory authority.

The scopes are intentionally disjoint. `FederationBankStaffCommandBinder` only accepts `CUSTOMER` authority, so an institutional authority envelope cannot become a Core Banking payment or account command.

The supplied illustrative policy keeps the v0.1 teller/supervisor customer rules and adds employee-side institutional rules for `INTERMEDIARY_INTRODUCE`, `INTERMEDIARY_ADVISE`, and `INTERMEDIARY_ARRANGE`. Those rules do **not** grant regulated-distribution permission: the RID authority remains independently responsible for firm/representative/product/jurisdiction/activity/advice/case requirements.

Authority scope is included in the canonical identities and durable state of actions, policy rules, decisions and authority envelopes. Legacy `/1` restored actions/decisions/envelopes default to `CUSTOMER`; new objects emit `/2`.

## Boundaries

Staff Authority is not HR/IAM, Relationship authority, RID, Core Banking or Ledger. HR/IAM supplies staff context; Staff Authority determines employee authority; downstream domain authorities independently determine their own legal/business permission.

## Validation

`run_tests.sh` contains nine domain tests. `run_integration_tests.sh` adds the Relationship Case → Relationship Adapter → Staff Authority → Core Banking chain, for ten executable tests in the v0.2 authority package.
