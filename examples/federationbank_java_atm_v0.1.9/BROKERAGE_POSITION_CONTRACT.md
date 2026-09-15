# FederationBank ATM Brokerage Position Enquiry Contract v0.1

## Purpose

This contract adds a read-only Merchant Bank derivatives-position enquiry to the FederationBank Java ATM.

The derivatives position is **not** FederationBank retail Ledger truth.  It comes from a separate brokerage / merchant-bank authority across an explicit cross-perimeter enquiry boundary.

The hard invariant is:

> Merchant-bank position information may be displayed by the ATM but cannot alter retail-bank available balance unless a separate arm's-length settlement has completed and the retail Ledger has posted the resulting money.

## Authority separation

```text
ATM customer session
      |
      +--> FederationBank retail ATM gateway
      |      account/balance/cash/deposit/holds
      |
      +--> Brokerage position enquiry perimeter
             relationship resolution
             current derivatives valuation
             margin/collateral summary
```

The ATM does not choose a brokerage account identifier and does not query the retail Ledger for derivatives information.

A production deployment may front the brokerage source with a retail-bank-owned relationship/linkage resolver, but the position values remain brokerage-owned truth.

## Read-only operation

The only v0.1 operation is:

```text
GET_MERCHANT_POSITION_SUMMARY
```

There is deliberately no trade, close-position, exercise, margin-transfer, cash-transfer or settlement operation in this ATM interface.

## Request destination

Recommended JMS destinations are separate from the retail ATM command queue:

```text
FB.BROKERAGE.ATM.REQUESTS
FB.BROKERAGE.ATM.REPLIES.<terminalId>
```

The brokerage enquiry may use a separate JMS provider entirely.  The Java client therefore has a separate `BrokerageNetwork` and independent JNDI/JMS configuration.

## Request envelope

Schema:

```text
federationbank.brokerage.atm.request/0.1
```

Example:

```json
{
  "schema": "federationbank.brokerage.atm.request/0.1",
  "commandId": "BRKPOS-...",
  "operation": "GET_MERCHANT_POSITION_SUMMARY",
  "terminalId": "ATM-IOM-001",
  "bankSessionId": "SESSION-...",
  "customerId": "CUST-002",
  "requestedAt": "2026-08-26T08:21:00.000Z"
}
```

Notably absent are:

```text
retail accountId
brokerage accountId
positionId
tradeId
cash amount
withdrawal amount
```

The customer/session values are cross-perimeter identity context.  Brokerage or its authorised linkage service owns the mapping to a Merchant Bank retail relationship and must not accept a brokerage relationship selected by the terminal.

## Response envelope

Schema:

```text
federationbank.brokerage.atm.response/0.1
```

A successful response contains a narrow summary projection:

```json
{
  "schema": "federationbank.brokerage.atm.response/0.1",
  "commandId": "BRKPOS-...",
  "operation": "GET_MERCHANT_POSITION_SUMMARY",
  "terminalId": "ATM-IOM-001",
  "ok": true,
  "code": "MERCHANT_POSITION_CURRENT",
  "detail": "Current brokerage derivatives position summary",
  "brokerageTime": "2026-08-26T08:21:00.100Z",
  "data": {
    "relationshipId": "BRK-RET-0002",
    "currency": "AUD",
    "valuationTime": "2026-08-26T08:21:00.000Z",
    "netMarketValueMinor": 7244000,
    "unrealisedPnlMinor": 321500,
    "realisedPnlMinor": 84000,
    "collateralMinor": 950000,
    "marginRequiredMinor": 538000,
    "availableMarginMinor": 412000,
    "positionCount": 2,
    "valuationStatus": "CURRENT",
    "sourceAuthority": "FEDERATION_BROKERAGE_POSITION_AUTHORITY"
  }
}
```

All money is integer minor units.  These values describe the Merchant Bank derivatives relationship; none is a retail-bank `availableBalanceMinor`.

The ATM intentionally does not receive individual trades, CFDs, options, strikes, expiries or notionals in v0.1.  A future "View positions" feature would require its own deliberately scoped channel contract.

## No linked relationship

A customer with no permitted linked retail brokerage relationship receives:

```text
ok   = false
code = NO_LINKED_BROKERAGE_ACCOUNT
```

The ATM displays a neutral no-linked-relationship message and does not attempt account discovery itself.

## Availability and caching

The v0.1 feature is online-only.

If the brokerage source is unavailable, the ATM does not display an earlier position as current.  Brokerage outage is independent of retail-bank availability: balance, withdrawal and deposit operations continue when the retail bank remains reachable.

The ATM transaction journal must not store the derivatives valuation.  That journal exists for physical-cash recovery and monetary idempotency, not as a brokerage cache.

## Display semantics

The terminal labels the result as:

```text
Merchant Bank - Derivatives Position Summary
```

and includes both valuation time and valuation status.  It also prints:

```text
Market prices may have changed.
This is NOT a Retail Bank balance and does not change cash available to withdraw.
```

This wording is functional, not merely cosmetic: the implementation must never map `netMarketValueMinor`, `collateralMinor` or `availableMarginMinor` into retail-bank cash availability.

## Security boundary

The brokerage enquiry principal should be read-only and restricted to the terminal's reply destination.  A deployment should grant no brokerage trading or settlement queues to the ATM principal.

The brokerage service must validate the retail customer/session context through the agreed cross-perimeter trust mechanism and resolve the relationship server-side.  A bare customer-supplied identifier is not sufficient authority.
