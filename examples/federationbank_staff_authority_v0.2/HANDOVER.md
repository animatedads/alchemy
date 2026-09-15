# Handover — FederationBank Staff Authority v0.2

Accepted continuation state: 10/10 executable tests green (9 domain + 1 Relationship/Core integration) and all package `.cls` files compile under ooRexx 5.3.0 r13196.

v0.2 separates employee authority into `CUSTOMER` and `INSTITUTIONAL`. Scope is bound into the semantic identity and durable state of the action, rule, decision and authority envelope. Legacy `/1` restore data defaults to CUSTOMER. The Core Banking binder explicitly rejects INSTITUTIONAL authority.

Illustrative institutional operations are exactly `INTERMEDIARY_INTRODUCE`, `INTERMEDIARY_ADVISE`, and `INTERMEDIARY_ARRANGE`. They are employee-side permissions only; RID independently determines regulated-distribution permission.
