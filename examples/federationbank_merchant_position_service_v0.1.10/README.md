# FederationBank Merchant Position Service v0.1.10

Read-only Merchant Banking position enquiry for arm's-length channels such as the FederationBank Java ATM.

## Regulatory boundary

This service belongs to the Merchant Bank perimeter.  It does not query or mutate the Retail/Core Ledger and it exposes no trade, exercise, close, collateral, cash-transfer or settlement command.

A Retail Bank `bankSessionId` / `customerId` / `terminalId` is identity context only.  An injected trusted linkage authority must bind that exact context to a permitted Merchant relationship.  The caller cannot nominate a brokerage relationship, portfolio, trade or Retail account.

## ATM contract

Request schema: `federationbank.brokerage.atm.request/0.1`

Operation: `GET_MERCHANT_POSITION_SUMMARY`

Response schema: `federationbank.brokerage.atm.response/0.1`

The response intentionally matches the Java ATM v0.1.9 `BROKERAGE_POSITION_CONTRACT.md` fields and contains integer minor units only.

`netMarketValueMinor`, `collateralMinor` and `availableMarginMinor` are Merchant Bank facts.  They are never Retail `availableBalanceMinor` and cannot increase ATM withdrawal availability.

The service does not cache the last good valuation.  If linkage or current Merchant position data is unavailable, the enquiry fails rather than presenting an old value as current.

## Transport trust context

The JMS gateway passes provider/source/header/property context to the injected linkage authority. A production linkage implementation can therefore bind the Retail session/customer assertion to the authenticated transport principal/source instead of trusting JSON fields alone.

## Valuation freshness

The service does not rewrite stale or indicative marks as current. Successful non-current projections use status-specific response codes such as `MERCHANT_POSITION_STALE` and retain `valuationStatus` in the data.


## v0.1.6 qualification

Requalified unchanged read-only position-enquiry semantics against Merchant Bank v0.8.  Versioned hedge-equivalence evidence remains an internal Merchant risk fact; the ATM still receives only the bounded summary contract and acquires no trading, collateral or settlement authority.


## v0.1.10 qualification

Dependency-only requalification against Merchant Bank v0.13 execution-evidence semantics. The ATM-facing read-only brokerage contract is unchanged.

## v0.1.9 qualification

Dependency-only requalification against reconciled Merchant Bank v0.12.  No
channel semantics change: the service remains a bounded, read-only summary
projection and does not expose instrument attestation, market-structure event,
hedge remediation, trading, collateral or settlement authority to the ATM.
