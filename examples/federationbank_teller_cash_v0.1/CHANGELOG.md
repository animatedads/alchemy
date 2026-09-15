# Changelog

## v0.1

- Initial FederationBank counter-cash orchestration module.
- Added `CASH_WITHDRAWAL` and `CASH_DEPOSIT` Staff Channel policy fixtures.
- Require exact Staff Authority evidence before cash-to-Core translation.
- Deterministically translate authorised counter cash to an ordinary Core `TRANSFER` against a branch/internal settlement account.
- Bind physical Till work to the exact translated Core command.
- Keep customer monetary truth and physical cash custody truth in separate authorities.
- Preserve `COMPENSATION_REQUIRED` and `RECONCILIATION_REQUIRED` instead of collapsing them into generic failure.
- Distinguish Core transport/delivery failure from institutional Core rejection.
- Resume already-prepared Till work on exact Core retry; do not mistake Till submit idempotency for execution retry.
- Added durable Teller Cash instruction snapshot/Queue Fabric persistence with an unambiguous terminal marker for empty optional approval fields.
- Explicitly exclude ATM and direct Ledger semantics.
