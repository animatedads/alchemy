# FederationBank External / Branch Cash Adapter v0.1

Narrow authority bridge between External Cash shipment authority and the real Branch Cash vault.

The adapter converts an exact External Cash shipment/authority into the neutral Branch Cash v0.3 external-custody instruction. It then requires a separately registered `FederationBankBranchCashExternalControl` matching the **current vault custodians**, exact shipment identity and upstream External Cash authority.

It cannot invent that vault control.

```text
External Cash authority
        |
        v
exact shipment
        |
        v
External/Branch adapter
        |
        +---- requires current vault dual-custody control
        |
        v
Branch Cash v0.3 vault truth
```

This preserves two independent decisions: whether the external shipment is authorised, and whether current branch custodians may physically release/accept it.
