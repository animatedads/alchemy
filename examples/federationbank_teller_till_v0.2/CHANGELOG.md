# v0.1

Initial teller till/cash-custody domain: opening/closing custody, denomination-counted bundles, cash-in/out, thresholds, exact-action checker binding, discrepancy handling and runtime boundary.

## v0.2
- Adds explicit internal branch-cash instructions and approvals.
- Adds `applyInternalCash` for till replenishment, skim and till-to-till custody movements without customer `CASH_IN` / `CASH_OUT` semantics.
- Adds exact transfer binding and idempotent internal-transfer receipts on the till.
