# Brokerage endpoint handoff for FederationBank Java ATM v0.1.9

The Java ATM side is ready for a separate brokerage / Merchant Bank position source.

## Required server operation

```text
GET_MERCHANT_POSITION_SUMMARY
```

Request schema:

```text
federationbank.brokerage.atm.request/0.1
```

Response schema:

```text
federationbank.brokerage.atm.response/0.1
```

Recommended destinations:

```text
FB.BROKERAGE.ATM.REQUESTS
FB.BROKERAGE.ATM.REPLIES.<terminalId>
```

The brokerage service (or an explicit bank-owned cross-perimeter linkage gateway in front of it) must resolve the authenticated Retail Bank customer to a permitted brokerage retail relationship. The terminal sends **no brokerage account ID** and must not be allowed to choose one.

Successful `data` fields expected by the client:

```text
relationshipId
currency
valuationTime
netMarketValueMinor
unrealisedPnlMinor
realisedPnlMinor
collateralMinor
marginRequiredMinor
availableMarginMinor
positionCount
valuationStatus
sourceAuthority
```

Money is integer minor units. `positionCount` is a non-negative integer. `valuationTime` is ISO-8601 UTC time.

If there is no linked permitted relationship:

```text
ok=false
code=NO_LINKED_BROKERAGE_ACCOUNT
```

## Deliberately absent

The ATM v0.1.9 contract has no:

```text
trade placement
trade cancellation
position close
option exercise
margin transfer
cash transfer
settlement instruction
individual position/trade details
brokerage account selection
```

It is a read-only projection only.

## Required security invariant

Merchant-bank valuation and margin values can never become Retail Bank cash availability merely because the ATM displayed them. Any money moving from Merchant Bank to Retail Bank must complete the normal arm's-length settlement and appear in Retail Bank Ledger truth before the ATM balance changes.

The server must treat `bankSessionId` / `customerId` as cross-perimeter identity context under the agreed trust mechanism, not as an arbitrary caller-supplied authority. Production deployments should bind the request to the authenticated JMS principal and/or a bank-issued linkage assertion.

## Client qualification already present

Java tests prove that:

- the request contains no Retail Bank account ID or brokerage account ID;
- relationship linkage is source-owned;
- a derivatives position much larger than the Retail Bank balance does not change withdrawable funds;
- the position is not written into the ATM cash-recovery journal;
- after one successful position read, taking brokerage offline causes the next enquiry to fail rather than return the old value as current;
- brokerage outage does not prevent Retail Bank balance enquiry.

A live brokerage JMS end-to-end qualification remains pending the actual brokerage endpoint/provider deployment.
