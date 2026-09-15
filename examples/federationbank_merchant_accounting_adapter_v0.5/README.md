# FederationBank Merchant Accounting Adapter v0.5

Merchant-Banking-owned accounting integration over Accounting Core v0.7 and FederationBank Merchant Bank v0.15.

## APIs

- `federationbank.merchant.accounting/0.5`
- `federationbank.merchant.accounting.projection/0.2`
- `federationbank.merchant.accounting.event_projection/0.2`
- fair-value movement policy: `federationbank.merchant.accounting.derivative_fair_value/0.2`
- fair-value transition policy: `federationbank.merchant.accounting.derivative_fair_value_transition/0.2`
- settlement-obligation policy: `federationbank.merchant.accounting.settlement_obligation/0.1`
- settlement-observation policy: `federationbank.merchant.accounting.settlement_observation/0.1`
- settlement-amount determination projection: `federationbank.merchant.accounting.settlement_amount/0.1`

The normalized Accounting Core contracts used are `accounting.event/0.1`, `accounting.transaction/0.1`, `accounting.posting/0.2`, `accounting.store/0.1` and, for optional settlement-amount determination, `accounting.settlement/0.1`, `accounting.settlement.request/0.1` and `accounting.settlement.determination/0.1`.

## Authority boundary

Merchant Bank remains authority for contracts, close-out/risk-neutralisation execution, settlement obligations, settlement instructions and externally attributable settlement observations. Accounting Core remains posting/event/persistence infrastructure. The adapter maps proved Merchant facts into the independent `FEDERATIONBANK_MERCHANT_BANK` accounting book; it does not make trades, dispatch settlement, move collateral, mutate Retail/Core balances or infer settlement from workflow status.

No live Merchant-domain object is put onto a transport as an accounting persistence format. The projection layer validates actual Merchant objects and emits bounded scalar evidence for the accounting boundary.

## Preferred operational path

```text
Merchant authoritative evidence
        |
        v
federationbank.merchant.accounting.projection/0.2
        |
        v
bounded Merchant accounting evidence
        |
        v
AccountingEvent
        |
        v
AccountingEngine~transact()
        |
        +-- legal-entity boundary
        +-- replay/conflict before policy dispatch
        +-- effective-dated Merchant policy
        +-- exact executable policyIdentity
        +-- source-event fingerprint
        v
independent Merchant AccountingBook
```

The adapter does not expose a generic remote accounting command. External authentication/authorization remains outside Accounting Core and cannot be replaced by possession of a scalar projection.


## Accounting Core v0.7 settlement-amount determination

v0.5 adopts Accounting Core v0.7 without letting Accounting Core rewrite Merchant contractual settlement truth. The adapter may register an explicit `AccountingSettlementRoundingElection` and externally supplied `AccountingSettlementPolicy`, then call `determineSettlementAmount()` for an already-accounted Merchant settlement obligation.

The request deliberately carries **no caller-supplied amount, currency, counterparty or settlement side**. Those are recovered from the immutable journal that recognised the exact Merchant obligation. The caller supplies only the obligation identity, date, currency minor exponent, exact election reference, tender class, source authority and supporting evidence. The supplied currency-scale evidence must agree exactly with the declared minor exponent.

```text
accounted Merchant obligation
        |
        +--> amount / currency / side / counterparty from journal
        |
explicit settlement election + executable policy
        |
        v
Accounting Core v0.7 determination
        |
        v
MBAccountingSettlementAmountDetermination
        |
        +--> difference = 0
        |      postingState = MERCHANT_SETTLEMENT_OBSERVATION_REQUIRED
        |
        +--> difference != 0
               postingState = MERCHANT_SETTLEMENT_AMOUNT_AUTHORITY_REQUIRED
```

A determination is **non-posting**. `determineSettlementAmount()` calls `AccountingEngine~determineSettlement()`, never `transactSettlement()`. `postSettlementAmountDetermination()` is an explicit fail-closed API: an exact result still requires external settlement completion evidence, while a non-zero rounding difference requires separate Merchant-domain settlement-amount/discharge authority before any accounting adjustment can be posted.

This is intentional. Accounting Core can prove what an exact selected ruleset would determine; it does not thereby amend `MBSettlementObligation`, dispatch settlement, prove cash movement or extinguish the contract. Merchant Bank v0.15 still requires exact attributable instruction/observation evidence for its own settlement state.

The determination projection retains exact election identity, ruleset identity, executable settlement-policy identity, rounding algorithm, quantum, tender class, jurisdiction and Core request fingerprint. It is bounded scalar evidence and contains no live Merchant-domain object.

## Settlement is a sequence of independently proved facts

v0.4 connects the new Merchant Bank v0.15 settlement evidence stream without collapsing its states:

```text
contractual settlement obligation
        |
        v
recognise settlement receivable/payable
against derivative-settlement control
        |
        v
settlement instruction observed
        |
        +--> NO POSTING
        |    instruction proves intent/dispatch only
        |
        v
external settlement observation
        |
        +--> PARTIAL: partial cash + partial clearing
        +--> COMPLETE: remaining cash + remaining clearing
        +--> FAILED: no accounting posting
```

For a Merchant receivable, obligation recognition debits derivative settlement receivable and credits derivative-settlement control liability. An externally observed receipt debits cash at settlement agent and credits the receivable. For a Merchant payable, obligation recognition debits derivative-settlement control asset and credits derivative settlement payable; externally observed payment debits the payable and credits cash at settlement agent.

The control account deliberately remains after cash settlement. Cash completion does **not** prove that derivative carrying value has been derecognised correctly and does not by itself prove realised P&L. That requires separate attributable carrying-value/derecognition evidence in a later accounting step.

## Instruction is not settlement

`MBAccountingSettlementInstructionObservation` is non-posting. `postSettlementInstructionObservation()` returns `SETTLEMENT_COMPLETION_EVIDENCE_REQUIRED`. A queue/work status, instruction ID or dispatch acknowledgement therefore cannot fabricate cash.

A Merchant `FAILED` settlement observation is retained as Merchant-domain evidence but has no accounting cash consequence; the accounting adapter returns `NO_POSTING_SETTLEMENT_FAILED`.

## Settlement binding and over-clear protection

A new settlement observation can post only when the exact Merchant obligation was already recognised in the Merchant accounting book. The adapter independently checks:

- obligation correlation;
- counterparty identity;
- receivable/payable side;
- currency;
- amount originally recognised; and
- cumulative cash clearing already posted for that obligation.

A scalar event therefore cannot clear more than the receivable/payable the accounting book actually contains, even if its caller supplies a larger amount. Such evidence fails with `SETTLEMENT_ACCOUNTING_BINDING_MISMATCH`.

Exact replay remains Accounting Core authority: if the same source event is already present, the event goes to `AccountingEngine~transact()` before the new-binding check so `DUPLICATE` and `SOURCE_EVENT_CONFLICT` retain the Core v0.4 replay-before-policy semantics.

Merchant Bank v0.15 separately deduplicates the underlying external receipt using `(sourceAuthority, externalSettlementRef)`, independent of local evidence ID. The accounting source-event fingerprint is an additional, not substitute, idempotency boundary.

## Sealed-chart compatibility

Accounting Core seals a chart. A durable Merchant book created by v0.3 may therefore recover with only the earlier fair-value accounts. v0.4 does not mutate that historical sealed chart behind its back.

- historical fair-value replay/recovery remains available;
- `settlementPostingAvailable()` reports false on such a book;
- new settlement postings return `SETTLEMENT_CHART_UPGRADE_REQUIRED`;
- a fresh v0.4 Merchant book contains the settlement accounts and can post settlement events.

This is an explicit migration gate rather than silently repurposing old accounts.

## Executable policy identity

v0.5 policies compile in a package declaring `::OPTIONS DIGITS 50`, as required by Accounting Core v0.7. The release-scoped executable identity is `FBMAA-0.5-20260828-AC07-7F93D184`; the policy-class suffix identifies the concrete executable treatment. Journals retain semantic `policyRef`, exact `policyIdentity`, event type, source-event fingerprint, source authority, counterparty and evidence references.

## Restart-safe replay and precision

The Accounting Core v0.7 replay behavior inherited from v0.4 is retained: durable recovery resolves exact historical replay and changed-source conflicts before current policy dispatch. Currency-scale conversion remains exact, signed minor-unit values are canonical integers and values wider than 50 significant digits are rejected before policy arithmetic.

## Fair-value and CFD-close invariants retained

Asset/liability sign crossing remains atomic: the old carrying side is derecognised, the new side recognised and the exact fair-value P&L movement posted in one journal.

A customer close remains a separate reversing Merchant contract. Accounting correlation can retain the original economic root and close intent, but the reversing journal has no `reversalOf` link to the original journal. `UI/client CLOSED` therefore never destroys the original CFD contract or accounting evidence.

Lifecycle state alone (`EXERCISED`, `EXPIRED`, `CLOSED`) remains non-posting for cash and returns `SETTLEMENT_EVIDENCE_REQUIRED` until attributable Merchant settlement evidence exists.
