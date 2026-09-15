# FederationBank Branch Day v0.1

Policy-driven branch opening, closing and end-of-day physical-cash certification.

Branch Day is a coordinating authority over evidence. It does **not** own vault balances, teller-drawer truth, customer accounts or Ledger state. It accepts typed evidence from custody and cash-control authorities and determines whether a branch business day can be certified open or closed.

## Key rules

- Opening requires balanced OPEN vault/till evidence, at least one vault, no branch discrepancy, no cash in transit and no outstanding reconciliation work.
- Opening and closing require exact-action independent approval.
- Closing requires CLOSED and balanced endpoint evidence.
- Closing is blocked by cash in transit, unresolved reconciliation work, or any physical discrepancy.
- End-of-day control totals must explain the closing physical position from opening custody plus customer cash, external cash movements and separately-authorised adjustments.
- A nonzero balancing adjustment cannot exist without an explicit adjustment authority reference.

Branch-internal replenishments/skims/till-to-till movements are custody changes and therefore net to zero at branch level; customer counter cash and external bank-cash shipments explain changes in total branch physical custody.
