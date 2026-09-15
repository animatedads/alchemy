# Vector Meridian Markets v0.11 handover

Current candidate: `vector_meridian_markets_v0.11.zip`

VMM remains separate legal entity `VECTOR_MERIDIAN_MARKETS_LTD`. Federation Merchant <-> VMM remains `vmm.federation.arm_length/0.3`; institutional formation remains `vmm.institutional.synthetic/0.5`; lifecycle `vmm.institutional.synthetic.lifecycle/0.6`; default `vmm.institutional.synthetic.default/0.8`; close-out operations `vmm.institutional.synthetic.closeout/0.9`; base execution `vmm.execution/0.4`; smart execution `vmm.smart-execution/0.4`.

v0.11 advances only VMM accounting/reporting integration: `vmm.accounting/0.11`, `vmm.accounting.persistence/0.11`, and new `vmm.accounting.reporting/0.11`. The candidate adopts Accounting Core v0.7 and its `accounting.scope/0.1` / `accounting.reporting/0.1` facilities while retaining the event/transaction/posting/store path from v0.10.

Critical reporting invariant: VMM still has one statutory book, `VECTOR_MERIDIAN_MARKETS_LTD / VMM-STAT / ENTITY_GAAP`. Reporting views are immutable projections over posted journals. They are not extra ledgers or legal entities. New dimensions identify `INSTITUTIONAL_SYNTHETICS` versus `TREASURY_FUNDING` and the accounting function (premium, collateral/custody, XVA, close-out, funding).

`VMMAccountingReportingBoundaryFactory` creates evidence-bearing whole-firm and filtered VMM boundaries. `VMMAccountingReportingService` accepts only exact VMM legal entity/book boundaries with VMM reporting policy identity/evidence and rejects attempts to include Federation or another legal entity. Federation may remain a lender/counterparty dimension inside a funding journal; that does not make Federation a VMM reporting entity or book authority.

Durable tests prove the same journals can be projected before and after `AccountingFileStore` restart with business-line/function dimensions intact. v0.11 deliberately does not add VMM policy for Accounting Core v0.7 generic tax determination or settlement rounding. `oorexx_access_permissions_v0.1` is present in the roll-up but is not added decoratively to queue message boundaries; integrate it later only where a VMM object/method is actually exposed through Security Manager.

Qualification target: VMM 61/61; Accounting Core v0.7 297 ooRexx + 10 projection assertions; FederationBank Merchant Bank v0.15 51/51 unchanged; Queue Fabric targeted 62/71/141/85/10 using Crypto v0.5; 15/15 VMM source/integration classes compile. All Japan Insurance v0.9 is current independent sibling/counterparty shape, not a VMM runtime dependency.

## Previous v0.9 handover context

# Vector Meridian Markets v0.9 handover

## Candidate

`vector_meridian_markets_v0.9`

Legal entity remains `VECTOR_MERIDIAN_MARKETS_LTD`. VMM remains a separate principal market maker and direct institutional OTC manufacturer. Do not fold it into FederationBank Core or Merchant Bank and do not grant Federation principals access to direct-institutional queues.

## New v0.9 scope

v0.9 adds post-termination close-out operations on `vmm.institutional.synthetic.closeout/0.9`: valuation dispute, independent fallback resolution, explicit finalization, evidence-bound master-agreement netting, aggregate settlement and segregated-IM custody return.

The v0.8 bilateral default protocol `vmm.institutional.synthetic.default/0.8` remains the authority for default/cure/termination and original close-out determination. v0.9 never mutates that determination.

Accounting advances to `vmm.accounting/0.9` while retaining Accounting Core `accounting.event/0.1`, `accounting.transaction/0.1` and `accounting.posting/0.2`.

## Critical invariants

1. Original close-out determination is immutable even when disputed.
2. Dispute resolution is separate evidence; it cannot rewrite the original object.
3. An undisputed close-out may finalize only after the configured dispute window has expired.
4. A disputed close-out may finalize only after a configured independent fallback valuation agent resolves it; the original valuation agent is not accepted as its own fallback.
5. Settlement/accounting authority is the exact `VMMCloseoutFinalization`, not an unresolved/disputed determination.
6. Close-out amounts remain signed from VMM perspective: positive receivable, negative payable.
7. Master-agreement netting requires exact counterparty ID/entity, master agreement, currency, governing law, legal opinion and explicit close-out-netting election.
8. A member of a fixed netting set cannot settle individually; one aggregate settlement moves the legal net cash.
9. Cross-counterparty or cross-master-agreement netting is prohibited and failure must not mutate member state.
10. Gross receivables and payables remain visible even when one legal net amount is paid.
11. Segregated IM is outside v0.9 close-out/netting algebra and requires its own post-termination custodian-return lifecycle.
12. IM return references the exact original transfer and is not effective until custody settlement; acknowledgement alone is insufficient.
13. Accounting returns IM at gross carrying value; haircut-adjusted recognised value remains risk evidence.
14. VMM hedge-unwind P&L remains VMM attribution evidence and cannot rewrite client close-out.
15. Federation has no ACL on direct institutional default or close-out queues and no VMM service reference.
16. Federation Merchant <-> VMM remains `vmm.federation.arm_length/0.3`.
17. Formation remains `vmm.institutional.synthetic/0.5`; ordinary lifecycle remains `vmm.institutional.synthetic.lifecycle/0.6`.
18. Base execution remains `vmm.execution/0.4`; smart execution remains `vmm.smart-execution/0.4`.
19. Merchant Bank source remains unmodified.

## Dependency choice

`oorexxapis(20260828-155014)` advances ooRexx Crypto to v0.4, which is qualified with v0.9. The roll-up's VMM v0.7 and Accounting Core v0.3 are older than this workstream. Keep `accounting_core_v0.3.1`, whose high-precision exact-minor-unit repair and regression remain required.

Queue Fabric targeted qualification additionally resolves NoSQLServer v0.79 and Runtime Registry v0.14 from the current roll-up; these remain Queue Fabric qualification dependencies, not VMM data authorities.

## Qualification

- VMM v0.9: 54/54 tests pass on ooRexx 5.3.0 r13196.
- Accounting Core v0.3.1: 113 ooRexx assertions plus 10 Python projection assertions pass.
- FederationBank Merchant Bank v0.13: 41/41 unchanged tests pass.
- Queue Fabric v0.9-dev4 targeted suites: 62 basic, 71 adversarial, 141 MQ semantics, 85 channels, 10 release-boundary assertions pass.
- all 13 VMM source/integration `.cls` files compile with `rexxc`.

## Next increment

A future v0.10 should add multi-currency/master-agreement settlement only through explicit FX/CSA/legal-setoff evidence, plus valuation-agent/session evidence and custody failure/escalation. Do not broaden netting by economic similarity or corporate affiliation.
