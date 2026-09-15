# Architecture

`FederationBankBranchCashVault` is physical custody truth for a branch vault. `FederationBankBranchCashTransfer` is the immutable internal movement intent. `FederationBankBranchCashApproval` binds checker approval to the exact transfer semantic identity. `FederationBankBranchCashPosition` aggregates vault/till endpoint projections while retaining in-transit cash separately.

The module has no UI and no Core Banking / Ledger route.


## v0.2 transfer authority boundary

`FederationBankBranchCashAuthorityIssuer` is the single translation point from proposed transfer + checker approval + policy decision to a downstream-capable exact-action authority envelope. The authority binds the whole `FederationBankBranchCashTransfer.semanticIdentity`, branch/source/destination, amount/currency, requesting employee, upstream Staff Authority reference, checker identity, and Branch Cash policy result.
