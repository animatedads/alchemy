# All Japan Insurance v0.10 architecture

## Authority perimeter

```text
Federation Group ownership
          |
          v
All Japan Insurance
  |-- product-definition / product-program authority
  |-- rate-book + executable rating-function authority
  |-- underwriting authority
  |-- policy / contract-release authority
  |-- policy-transaction authority
  |-- premium billing + credit-control authority
  |-- producer commission settlement/recovery authority
  |-- premium-tax settlement/recovery authority
  |-- claims assessment + claims-payment authority
  `-- insurance operational/technical truth
          |
          | accounting.event/0.1
          v
AJI executable accounting policies
          |
          v
Accounting Core v0.7
          |
          v
AJI-STAT durable JPY AccountingBook
```

Federation ownership is not runtime authority inheritance. Federation Intermediaries remains a separate workstream.

## Immutable insurance release graph

```text
ContractVersion
   | allowed product/rating identities
   v
ProductRatingProgram
   | definitionRef
   | coverage -> exact ratePlanRef
   v
RatingPlan -> exact executable ratingFunctionRef
   v
ProductRatingResult -> Quote -> PolicyContractLock
                               |
                               +-- exact contract/payout function
                               `-- exact rating/product program evidence
```

Existing terms never re-resolve current rules for claims or ordinary mid-term pricing.

## Mid-term state transition

```text
Bound/current ExposureSnapshot
        |
        +-- ExposureChange (must branch from current)
        |       |
        |       +-- BEFORE --+
        |       |            | exact bound ProductRatingProgram
        |       `-- AFTER ---+ same transaction proration
        |                    |
        |                    v
        |          signed PremiumAdjustmentCalculation
        |                    |
        |                    v
        |             authorised Endorsement
        |                    |
        `--------------------+--> new current ExposureSnapshot
```

This prevents current-rate drift and concurrent stale exposure branches.

## Billing subledger

```text
Initial schedule / authorised premium adjustment
                 |
                 v
         immutable billing item
          DEBIT or CREDIT
                 |
        +--------+---------+
        |                  |
        v                  v
schedule revision     cash / credit source
(reversal + new       allocation
 debit items)              |
        |                  v
        +----------> open debit / arrears
                           |
                           `--> unapplied cash / customer credit
```

Schedule revision is not a premium calculation. It must reverse the exact open future amount it replaces and issue the same total as new debits. Premium changes must come from the rating/policy transaction path.

Allocation is deterministic under `AJI.BILLING.ALLOCATE.OLDEST_DUE/1`. Receipt-time allocation evidence is frozen so later allocation cannot rewrite historical cash accounting.

## Coverage cancellation/reinstatement

Cancellation remains both a financial and coverage event. Only no-gap reinstatement is supported. The cancellation return and reinstatement restoration become distinct billing credit/debit items, which can offset without inventing new cash.

## Settlement/recovery separation

Cash does not imply business authority:

- premium receipt requires billing authority and bank evidence;
- claim payment requires claims-payment authority;
- producer payment/recovery requires commission-settlement authority;
- tax remittance/recovery requires tax-settlement authority;
- policyholder refund requires billing authority plus an accounting credit position.

Accounting validates its posted state independently of upstream operational records.

## Durable replay boundary

```text
AccountingEvent
    |
    +-- existing source ref + same fingerprint -> historical journal DUPLICATE
    +-- existing source ref + changed fingerprint -> SOURCE_EVENT_CONFLICT
    `-- new source ref -> effective AJI accounting policy -> immutable journal/store
```

Recovery rebuilds the source-event index before current policy dispatch.

## External seams

- Federation Relationship CRM / Case: explicit references/projections only.
- FederationBank: bank-attributed payment evidence adapter; never a shared insurer ledger.
- Queue Fabric: future durable insurance commands/events/projections.
- Legal Effect / Institutional Policy: product/rate/authority evidence integration.
- Wire UI: semantic actions/projections, never direct state mutation.
- Accounting Core v0.7 tax/scope/settlement: generic infrastructure only; AJI policy remains responsible for jurisdictional meaning.
- VMM: explicit arm's-length counterparty only if later required.
