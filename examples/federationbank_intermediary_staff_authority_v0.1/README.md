# FederationBank Intermediary Staff Authority v0.1

Employee-side authority and attribution bridge between FederationBank Staff Authority and the Regulated Intermediary Distribution (RID) domain.

It requires a positive **INSTITUTIONAL** Staff Authority envelope and an effective-dated bank-employee ↔ RID representative binding, then binds that employee authority to one exact intermediary request: product semantic identity, product family, jurisdiction, activity, advice mode and case.

It deliberately does **not** duplicate RID authority. RID remains independently authoritative for active firm/representative status, regulatory permission, Federation appointment, representative competence, product distribution approval, regulated journey rules and customer demands/needs evidence.

The staff operations are exact:

- `INTERMEDIARY_INTRODUCE` ↔ `INTRODUCE`
- `INTERMEDIARY_ADVISE` ↔ `ADVISE`
- `INTERMEDIARY_ARRANGE` ↔ `ARRANGE`

A `CUSTOMER` Staff Authority envelope is rejected and this component has no Core Banking or Ledger execution path.
