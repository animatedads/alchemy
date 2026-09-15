# VMM accounting boundary v0.11

## Authority split

```text
VMM operational/legal authority                       VMM accounting authority
-------------------------------                       ------------------------
Premium / collateral / funding event      --event-->  AccountingEngine~transact()
Close-out finalization                    --event-->  effective VMM policy
Direct or master-netting cash settlement  --event-->  VMM AccountingBook
Segregated-IM custody return               --event-->  VMM AccountingBook
XVA evidence                               --event-->  VMM AccountingBook
```

The arrow is one-way. Accounting Core records an authoritative VMM event; a journal never edits the source trade, contract, default, dispute, valuation, collateral transfer, close-out, netting set or settlement.

The book legal entity is always `VECTOR_MERIDIAN_MARKETS_LTD`. FederationBank and institutional clients may be retained as counterparty/evidence dimensions but never as book authority.

## APIs

- VMM adapter: `vmm.accounting/0.11`
- Accounting Core event API: `accounting.event/0.1`
- Accounting Core transaction API: `accounting.transaction/0.1`
- Accounting Core posting API: `accounting.posting/0.2`
- Accounting Core store API: `accounting.store/0.1`
- Accounting Core scope API: `accounting.scope/0.1`
- Accounting Core reporting API: `accounting.reporting/0.1`
- VMM persistence: `vmm.accounting.persistence/0.11`
- VMM reporting: `vmm.accounting.reporting/0.11`
- qualified core: `accounting_core_v0.7`


## v0.11 one-book reporting boundary

VMM has one accounting legal entity and one statutory book. `VMMAccountingReportingService` derives views from that native book using Accounting Core reporting boundaries; it never reposts entries and never creates a desk book.

New journal dimensions are part of the posted evidence:

- `vmm.businessLine=INSTITUTIONAL_SYNTHETICS` for synthetic premium, collateral/custody, XVA and close-out activity;
- `vmm.businessLine=TREASURY_FUNDING` for arm's-length funding activity;
- `vmm.accountingFunction` distinguishes `PREMIUM`, `COLLATERAL_CUSTODY`, `XVA`, `CLOSEOUT` and `FUNDING`.

The VMM boundary factory produces whole-firm, institutional-synthetics, treasury-funding, collateral/custody, close-out and XVA views. Every accepted VMM boundary is evidence-bearing, includes only `VECTOR_MERIDIAN_MARKETS_LTD`, includes only `VMM-STAT`, and carries the VMM reporting-boundary policy identity. A caller cannot turn a counterparty dimension into a reporting entity: an attempted boundary that includes Federation is rejected before Accounting Core builds the view.

Because dimensions live on the immutable journal lines, filtered views survive AccountingFileStore restart without a parallel reporting ledger. VMM v0.11 consumes Accounting Core v0.7 scope/reporting APIs only; generic tax determination and settlement-rounding facilities remain available upstream but are not VMM policy in this cut.

## Operational transaction path

Normal VMM mappings create an `AccountingEvent` and call `AccountingEngine~transact()`. Effective-dated policies are legal-entity/event-type scoped. A posted journal freezes `policyRef`, exact executable `policyIdentity`, source-event fingerprint, event type, counterparty, source authority and evidence.

Replay is checked before policy execution:

```text
same source ref + same fingerprint    -> DUPLICATE, original entry returned
same source ref + changed fingerprint -> SOURCE_EVENT_CONFLICT
```

Cumulative premium accrual derives prior cumulative state from posted accounting event metadata rather than adapter-local memory, so adapter restart does not duplicate or lose the incremental accrual delta.

## Retained mappings

- Premium accrual: Dr premium receivable / Cr premium revenue.
- Premium settlement: Dr cash / Cr premium receivable.
- VMM-posted cash variation margin: Dr collateral posted / Cr cash.
- VMM-posted securities IM: Dr collateral posted / Cr trading asset at gross carrying value; haircut-adjusted recognized value remains risk evidence.
- Funding draw: Dr cash / Cr arm's-length borrowing.
- Funding interest: Dr funding expense / Cr accrued interest payable.
- Funding repayment: Dr borrowing / Cr cash.
- XVA: Dr XVA expense / Cr derivative valuation-adjustment reserve; never rewrites the client payoff.

## v0.9 finalization recognition

The v0.8 close-out determination remains legal evidence but may be disputed. When `VMMCloseoutOperationsService` is bound, v0.9 accounting recognizes `VMMCloseoutFinalization`, not a still-disputable determination. A finalization either adopts the original amount after the dispute window (`ORIGINAL_UNDISPUTED`) or adopts a separately evidenced fallback resolution (`DISPUTE_RESOLUTION`).

For a VMM payable finalization, accounting records the gross contractual loss, disposes any evidenced cash-VM carrying value included in legal set-off, and records the final net payable. For a VMM receivable, directions reverse into recovery revenue and a net receivable. Segregated IM remains outside this formula.

A later direct cash settlement clears the final receivable/payable.

## Master-agreement net settlement

Legal set-off is established by `VMMMasterAgreementNettingSet` before accounting. Accounting does not decide which contracts may net. It consumes the legally evidenced determination and preserves both gross sides.

For example, where finalized members contain a gross VMM receivable of 3m and gross VMM payable of 1m, one 2m cash receipt clears both positions. The journal therefore retains the 3m receivable and 1m payable evidence rather than pretending only a 2m contract ever existed.

## Segregated initial-margin return

Segregated IM is not silently consumed by close-out or master-netting accounting. After legal cash close-out, an exact original IM transfer is returned through custody instruction, acknowledgement and settlement. Only custody settlement changes accounting. Gross carrying value is reclassified back to the original trading/derivative asset; haircut-adjusted recognized value remains a risk/evidence dimension and is not booked as a loss.

## Precision qualification

Accounting Core v0.7 retains the package-level 50-digit accounting arithmetic compatibility contract introduced upstream after the institutional-scale precision defect was found. VMM policy code remains `::OPTIONS DIGITS 50`, including the 12,000,000,000-minor-unit premium path.


## Durable VMM book

`VMMAccountingStore` creates and recovers only `VECTOR_MERIDIAN_MARKETS_LTD` / `VMM-STAT` / `ENTITY_GAAP`. Accounting Core v0.7 persists chart mutations, periods, evidence-bearing period transitions and immutable journals to append-only JSONL. Exact source replay after recovery is resolved before policy dispatch; changed reuse remains a source-event conflict. Recovery of an accounting store does not confer operational trading authority and cannot be used to import another legal entity's book into VMM.
