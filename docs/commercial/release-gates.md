# Acceptance and launch gates — commercial v0.2

**Status: proposed work, none hereby marked passed.** A source directory is not an accepted sellable product.

| ID | Blocking test or delivery | Target |
| --- | --- | --- |
| C01 | Product + SKU signed/versioned entitlements with enforceable seats, features, support tier and limits | COMM/NNFO |
| C02 | Exact source SHA/release authority, dependency lock and composite functional QA | COMM/NNFO |
| C03 | Tenant isolation, directory identity, RBAC, revocation, secrets boundary and threat model | Both |
| C04 | Customer authorized preflight, cost disclosure, install, health, upgrade, rollback, uninstall | Both |
| C05 | Accessible web/native management UX usable without a development team | Both |
| C06 | Managed ops, support triage, backups, restore, import/export, retention and incident response | Both |
| C07 | Website to contact/enquiry to communications/case to report with policy/consent and delivery | COMM |
| C08 | Non-developer designs new documents/views/workflows from graphical interface | NNFO |
| C09 | Mobile client persists signed-off scoped offline data, reports, photos and signatures with no network | NNFO Field |
| C10 | Reconnect/merge/ACL expiry, partial upload, double write, crash and zero lost accepted updates | NNFO Field |
| C11 | Signed WLU tariff; accepted-work-only rating; capping, reproducible settlement, no replay double charges | Both |
| C12 | Microsoft test order, flat+meter billing, 14-day trial, auto-convert/cancel, corrected invoice | First channel |
| C13 | AWS purchase, non-auto-converting trial, affirmative paid purchase and metered reconciliation | Parallel |
| C14 | Google Procurement/PubSub/ServiceControl, credit+day trial, cancellation and error handling | Parallel |
| C15 | Real unit-cost sample and sustainable margin after fee, WLU, support, hosting, acquisition | Both |
| C16 | Three design partners complete useful workflow, trial, export, cancellation and support contact | Both |
| C17 | Accepted public claims: regions, privacy, legal, accessibility, contract, data rights, support & SLO | Both |
| C18 | Published onboarding, demo, seller listing copy, buyer cost calculator, docs and escalation routing | Both |

## Release work order

1. Freeze SKU manifest as a proposal; resolve authoritative source, acceptance and licenses per Alchemy module.
2. Build Commerce/Trial/WLU rating + read-only installer/preflight interfaces; test failure and retry paths before live charges.
3. Qualify Communications managed tenant from publish to enquiry to cancellation.
4. Qualify NotNotes against 20-worker offline acceptance fixture [NN-01 through NN-14](notnotes-field-operations.md) **before** advertising production offline work.
5. Qualify Microsoft sandbox billing, then AWS and Google independently. External approval determines marketplace dates.
6. Finance signs tariffs on real costs; Support signs actual SLO; human commercial authority approves customer-facing offer.

Per release attach signed plan, accepted component digests, cost model, operational support matrix, region and third-party charges, tested account lifecycle, privacy export/delete, and evidence links. Any missing acceptance leaves **BLOCKED** state. Financial/Insurance remain design-partner-only.
