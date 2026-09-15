# Changelog

## 0.11 - 2026-08-28

- adopted Accounting Core v0.7 while preserving one durable `VECTOR_MERIDIAN_MARKETS_LTD / VMM-STAT / ENTITY_GAAP` book;
- advanced VMM accounting to `vmm.accounting/0.11` and persistence to `vmm.accounting.persistence/0.11`;
- added `VMMAccountingReporting.cls` and reporting protocol `vmm.accounting.reporting/0.11` over Accounting Core `accounting.reporting/0.1` and `accounting.scope/0.1`;
- added exact journal dimensions `vmm.businessLine` and `vmm.accountingFunction`, separating institutional synthetics from treasury funding and premium/collateral-custody/XVA/close-out/funding functions without reposting transactions;
- added evidence-bearing VMM reporting boundaries for whole firm, institutional synthetics, treasury funding, collateral/custody, close-out and XVA;
- reporting views are projections of the same immutable VMM journals, not extra books, desk legal entities or accounting authorities;
- VMM reporting service rejects a custom boundary that includes Federation or any non-VMM legal entity/book; Federation remains only an arm's-length lender/counterparty dimension where applicable;
- durable regressions prove reporting dimensions and filtered views survive `AccountingFileStore` restart;
- deliberately did not adopt generic Accounting Core v0.7 tax determination or settlement-rounding policy into VMM in this cut;
- deliberately did not wire `oorexx_access_permissions_v0.1` decoratively into queue-facing message boundaries; exact object×method permissions remain a separate future Security Manager integration where an object method is actually exposed;
- qualified against FederationBank Merchant Bank v0.15 and Queue Fabric v0.9-dev4 with ooRexx Crypto v0.5; All Japan Insurance v0.9 remains an independent institutional-counterparty package, not a VMM runtime dependency;
- VMM suite passes 61/61; Accounting Core v0.7 passes 297 ooRexx + 10 projection assertions; Merchant Bank v0.15 passes 51/51 unchanged; Queue Fabric targeted suites pass 62/71/141/85/10; all 15 VMM source/integration class files compile under ooRexx 5.3.0 r13196.

## 0.10 - 2026-08-28

- adopted supplied Accounting Core v0.4 and its explicit 50-digit accounting arithmetic contract;
- changed `VMMAccounting.cls` to package-level `::OPTIONS DIGITS 50`, satisfying Accounting Core v0.4 policy-package qualification instead of relying only on method-local precision;
- advanced VMM accounting to `vmm.accounting/0.10` while retaining `accounting.event/0.1`, `accounting.transaction/0.1` and `accounting.posting/0.2`, and exposing durable `accounting.store/0.1`;
- added `VMMAccountingPersistence.cls`, `VMMAccountingStore` and exact VMM statutory-book recovery guards for legal entity, book ID and reporting basis;
- added append-only durable VMM accounting bootstrap/recovery over `AccountingFileStore`; chart, periods, transitions, journals, source fingerprints, balances and policy identities survive restart;
- split VMM accounting setup from policy registration so recovered books are not reconfigured or mutated before current policy is registered;
- added replay-only recovery proving exact historical replay/conflict resolves from recovered journal identity before current policy dispatch;
- added evidence-bearing VMM period close/reopen/lock control using Accounting Core v0.4 durable transition history;
- proved the ¥12,000,000,000-minor-unit All Japan premium cumulative accrual resumes incrementally after full accounting-book restart;
- VMM suite passes 58/58 against Accounting Core v0.4; Accounting Core v0.4 full suite passes 148 ooRexx + 10 projection assertions; Merchant Bank v0.13 remains 41/41; Queue Fabric targeted suites remain 62/71/141/85/10.

## 0.9 - 2026-08-28

- added `VMMCloseoutOperations.cls` and post-termination protocol `vmm.institutional.synthetic.closeout/0.9`;
- retained every v0.8 close-out determination as immutable evidence; a dispute/resolution creates new objects and never edits the original amount;
- added evidence-bound dispute windows, independent fallback valuation-agent resolution and explicit `VMMCloseoutFinalization` as settlement/accounting authority;
- undisputed determinations cannot be finalized until their dispute window expires, and unresolved disputes block settlement;
- added `VMMMasterAgreementNettingSet` with exact counterparty/master-agreement/currency identity plus governing-law, legal-opinion and close-out-netting-election evidence;
- valid netting preserves gross receivable/payable evidence and produces one aggregate cash settlement; member close-outs cannot then settle individually;
- cross-counterparty/master-agreement netting attempts are rejected without mutating settlement state;
- retained segregated IM outside close-out-set algebra and added post-termination custodian instruction/acknowledgement/settlement for exact original IM transfers;
- advanced VMM accounting to `vmm.accounting/0.9`; finalization rather than disputed determination is the recognition point, with separate final settlement, master-netting settlement and IM-return AccountingEvent policies;
- added dedicated durable Queue Fabric dispute/result/finalization queues; institutional clients remain queue-only and Federation receives no ACL;
- qualified unchanged accounting event/transaction/posting APIs against Accounting Core v0.3.1 and advanced Queue Fabric transitive crypto qualification to ooRexx Crypto v0.4 from the 20260828-155014 roll-up;
- VMM suite passes 54/54, Merchant Bank v0.13 remains 41/41, Accounting Core v0.3.1 remains 113 ooRexx + 10 projection assertions, Queue Fabric targeted suites remain 62/71/141/85/10, and all 13 VMM class files compile under ooRexx 5.3.0 r13196.

## 0.8 - 2026-08-28

- added `VMMDefaultCloseout.cls` and bilateral default protocol `vmm.institutional.synthetic.default/0.8`;
- separated default notice, cure, uncured assessment, termination election, close-out determination and settlement into distinct immutable lifecycle facts;
- premium-payment default by an institutional client requires an actual outstanding VMM premium receivable;
- cure is accepted only from the defaulting party and only on/before the configured cure deadline;
- early termination requires an uncured default and election by the non-defaulting legal party;
- close-out amount is expressed from VMM's perspective and preserves methodology, market-data, collateral-netting and valuation-authority evidence;
- evidence-backed cash variation margin may offset legal close-out while segregated initial margin remains disclosed but outside automatic v0.8 netting;
- VMM hedge-unwind P&L is retained as separate attribution evidence and cannot rewrite the legal client close-out amount;
- added durable Queue Fabric default notice/cure/termination queues with directional client/VMM ACLs and no Federation access;
- advanced accounting adapter to `vmm.accounting/0.8` using Accounting Core `accounting.event/0.1` + `accounting.transaction/0.1` + `accounting.posting/0.2`;
- normal VMM accounting now emits AccountingEvents and uses effective-dated VMM policies, immutable `policyIdentity`, source fingerprint and replay-before-policy semantics;
- added close-out determination/settlement accounting while retaining contractual close-out, collateral and XVA/hedge evidence as separate truths;
- premium cumulative accrual delta now derives from already-posted accounting event evidence, so adapter restart does not lose incremental state;
- qualified against `accounting_core_v0.3.1`, a narrow repair carrying forward high-precision whole-minor-unit validation before `DATATYPE(...,"W")`;
- VMM suite passes 45/45, Merchant Bank v0.13 remains 41/41, Queue Fabric targeted suites remain 62/71/141/85/10, and all 11 VMM class files compile under ooRexx 5.3.0 r13196.

## 0.7 - 2026-08-28

- added `VMMAccountingService` and `VMMAccountingPolicy` using `vmm.accounting/0.7` over Accounting Core `accounting.posting/0.1`;
- VMM accounting is legal-entity scoped to `VECTOR_MERIDIAN_MARKETS_LTD`; Federation/client identities can appear only as dimensions/evidence, never as book authority;
- added independent VMM chart/period setup and immutable postings for premium accrual/settlement, VMM variation margin, initial-margin asset reclassification, funding draw/interest/repayment and CVA/FVA adjustment;
- premium cumulative operational accruals are translated into incremental accounting journal entries;
- source-event replay is idempotent and changed reuse of the same source identity is rejected by Accounting Core;
- initial-margin haircuts remain risk recognition rather than artificial accounting write-downs;
- XVA accounting adjustments do not modify contractual synthetic valuation/payoff truth;
- qualified against Accounting Core v0.2.1, a narrow repair discovered during VMM integration for exact minor-unit values above ooRexx default 9-digit numeric precision;
- VMM suite passes 41/41, Merchant Bank v0.13 remains 41/41, Queue Fabric targeted suites remain 62/71/141/85/10, and all 9 VMM class files compile under ooRexx 5.3.0 r13196.


## 0.6 - 2026-08-28

- added `VMMSyntheticLifecyclePolicy` with client-substitution value-drift, XVA-size and hedge-effectiveness thresholds under VMM authority;
- added fixed premium schedules, deterministic cumulative premium accrual and externally evidenced institutional premium settlement; contractual premium payee must be VMM and per-period over-settlement is rejected;
- added separate `VMMSyntheticInitialMarginTerms` and `VMMSyntheticInitialMarginTransfer` with asset eligibility, policy haircut caps, recognised collateral value and explicit shortfall;
- added immutable `VMMReferencePortfolioChange` lineage for `CLIENT_SUBSTITUTION` and `CORPORATE_ACTION`; current reference snapshot advances only after registered ownership/currency checks, VMM lifecycle admission and current wrong-way-risk checks;
- added tripartite `VMMSyntheticNovation`; the old contract becomes `NOVATED`, preserves its target lineage, and a new active contract is created with the successor counterparty's agreements and replacement snapshot while retaining original economic terms and initial reference value;
- added separate `VMMSyntheticXVAReport` for CVA/FVA evidence without altering contractual MTM;
- added `VMMSyntheticHedgeEffectiveness` with liability change, hedge P&L, offset %, residual amount and effective/ineffective status; ineffective results are journalled as alerts rather than refused;
- added durable Queue Fabric post-trade protocol `vmm.institutional.synthetic.lifecycle/0.6` for institutional premium-payment notices and reference-change requests, with client/VMM directional ACLs and no Federation access;
- deliberately retained direct institutional formation protocol `vmm.institutional.synthetic/0.5`, Federation/VMM `vmm.federation.arm_length/0.3`, base execution `vmm.execution/0.4` and smart execution `vmm.smart-execution/0.4`;
- upgraded Merchant Bank qualification target to current roll-up `federationbank_merchant_bank_v0.13`; 41/41 unchanged Merchant tests pass;
- validated 35/35 VMM tests plus Queue Fabric targeted 62/71/141/85/10 assertion suites on ooRexx 5.3.0 r13196.

## 0.5 - 2026-08-28

- added a direct institutional OTC synthetic-products service inside VMM, separate from FederationBank Merchant flow;
- added disclosed institutional counterparty onboarding with KYC, master-agreement and collateral-agreement evidence;
- added immutable portfolio reference snapshots with current-owner, legacy-owner, source-book and merger/succession provenance; inherited pre-merger positions require legal succession evidence;
- added first executable product `PORTFOLIO_LOSS_PROTECTION` with protected notional, attachment/exhaustion loss points, premium and maturity;
- added synthetic offer/contract lifecycle with independent model, market-data and risk-approval evidence;
- added VMM synthetic risk policy for gross notional, single-counterparty concentration and wrong-way reference concentration; VMM self-reference is rejected;
- added direct institutional Queue Fabric protocol `vmm.institutional.synthetic/0.5` for request/offer/accept/confirmation with client-specific ACLs and no Federation access;
- added independent synthetic valuation, threshold/MTA/independent-amount variation margin and externally evidenced collateral transfer records;
- added `SYNTHETIC_HEDGE` market-order origin and VMM synthetic hedge creation tied only to the VMM contract reference; hedge execution uses the existing smart execution queues and does not carry the client's raw portfolio;
- preserved Federation/VMM protocol `vmm.federation.arm_length/0.3` unchanged;
- validated 29/29 VMM tests, 38/38 Merchant Bank v0.12 tests and Queue Fabric targeted assertion suites on ooRexx 5.3.0 r13196.

## 0.4 - 2026-08-28

- added `VMMSmartExecutionService` with one durable Queue Fabric command queue per registered execution route and a shared smart execution event queue;
- added `VMMVenueRoute`, `VMMVenueQuote` and evidence-bearing `VMMSmartRouteDecision`;
- smart routing ranks fee/rebate-adjusted executable price, available size, route status and deterministic priority while preserving the exact venue/listing identity of the order;
- added route-target metadata to `VMMExecutionCommand` without changing its persistent payload type identity;
- added route ID, fee and rebate amounts to execution-fill payloads and VMM fill records; existing v0.3-style payload construction remains source compatible;
- added aggregated order-level execution fee, rebate and net-cost accounting across partial fills; trading cash/P&L now reflects net execution cost;
- added `VMMShortLocate` and reservation lifecycle: pre-route reservation, fill consumption and release of unused borrow after rejection/cancellation;
- added `VMMMarketRestriction` for `BLOCK_NEW`, `CLOSE_ONLY`, `SETTLEMENT_IMPAIRED` and `PRICE_UNRELIABLE` pre-trade controls;
- added `VMMMarketStructureLink` so economic/fungibility relationships are separate from legal tradable-line identity and can become `IMPAIRED`, `BROKEN` or `SUSPENDED` after sanctions/transfer events;
- added independent `VMMCapitalPolicy` and leverage snapshots; capital is explicitly separate from Federation/wholesale funding liabilities;
- preserved the Federation/VMM arm's-length wire protocol at `vmm.federation.arm_length/0.3`; no customer legal identity or direct VMM engine reference was added;
- validated 23/23 VMM tests, 38/38 Merchant Bank v0.12 tests and Queue Fabric targeted assertion suites on ooRexx 5.3.0 r13196.

## 0.3 - 2026-08-28

- made Queue Fabric v0.9-dev4 the canonical production-style execution path;
- added durable queue-persistable execution command, acknowledgement, fill, rejection, cancellation and reconciliation objects;
- added correlation/idempotency binding and durable command recovery;
- added explicit external execution states including `RISK_ACCEPTED`, `ROUTED`, `ACKNOWLEDGED`, `CANCEL_PENDING` and `UNKNOWN_PENDING_RECONCILIATION`;
- bound VMM to one queue execution service and reject direct `fillMarketOrder()` bypass while that service is bound;
- changed post-routing fill handling so real venue fills are booked even after a kill switch, strategy disablement or tighter risk limits; pre-trade controls remain admission controls rather than a way to erase actual fills;
- changed kill-switch semantics for routed orders: enqueue cancellation and remain `CANCEL_PENDING` until venue confirmation; fills can race the cancel and are retained;
- added `VMMExecutionJsonAdapter`; JSON is an edge representation that only enqueues execution events and cannot mutate VMM inventory directly;
- added durable FederationBank Merchant <-> VMM arm's-length RFQ/quote/execute/confirmation Queue Fabric protocol;
- arm's-length RFQ wire schema contains no customer legal-identity field and uses an opaque relationship reference;
- added directional Queue Fabric ACLs preventing Federation from forging VMM quote/confirmation messages or consuming requests in the VMM role;
- targeted Federation Merchant integration to v0.12 and retained VMM as `EXTERNAL_HEDGE` / `VECTOR_MERIDIAN_MARKETS_LTD`;
- added queue lifecycle, idempotency/reconciliation, JSON no-bypass, cancel/fill race, persistence, arm's-length flow and ACL regressions;
- validated 18/18 VMM tests and 38/38 FederationBank Merchant Bank v0.12 tests on ooRexx 5.3.0 r13196;
- independently reran Queue Fabric persistence/adversarial/MQ/channel/release-boundary tests successfully. The aggregate Queue Fabric `core` runner was also attempted; its upstream concurrency fixture did not terminate inside the 120-second harness window after earlier core fixtures had passed.

## 0.2 - 2026-08-28

- added evidence-backed `VMMTradableInstrument` identity with ISIN, venue/listing and currency separation;
- retained v0.1 bare-reference flow compatibility but prohibited bare-reference external algo hedging;
- added `VMMAlgorithmDecision` for independently evidenced proprietary signals;
- added external `VMMMarketOrder` and `VMMExecutionFill` ledger with partial fills;
- prohibited inventory hedge orders until the related VMM principal customer trade has actually executed;
- added trading-cash accounting and marked trading P&L;
- added arm's-length funding cash, repayment and interest-accrual records;
- added firm gross/single-line/funding/loss limits and enforceable risk snapshots;
- kill switch cancels resting local algorithmic market orders;
- Merchant adapter preserves VMM instrument identity into `MBInstrumentIdentity`;
- validated 11/11 VMM tests and 35/35 FederationBank Merchant Bank v0.11 tests on ooRexx 5.3.0 r13196.

## 0.1 - 2026-08-28

- initial separate VMM legal entity and principal market-making book;
- sanitised flow requests and opposite-side quoting;
- versioned algorithm strategy lifecycle and inventory limits;
- arm's-length funding facilities/draw obligations;
- VMM surveillance evidence and kill switch;
- FederationBank Merchant Bank external-counterparty adapter.
