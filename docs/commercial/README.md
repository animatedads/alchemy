# Alchemy Commercial Marketplace — product group portfolio v0.2

**Working commercial design; not an approved or released marketplace offer.** Dated 23 October 2026. Do not construe a directory in this repository as production certification or a right to sell.

## Offer philosophy

One purchase, one guided installation, one supported business result — not a vendor-managed ZIP full of modules that the customer must integrate. Alchemy keeps authoritative domain semantics independent of renderer, encoding and transport; service-to-service communication may use direct, RPC or Queue Fabric according to the delivered Connect Selector contract. Queue Fabric is not compulsory. Cloud marketplaces adapt entitlement and settlement, not the application model.

Commercial comparison is the **total cost of a supported outcome**: license, cloud/backup, mobile/offline, directory integration, migration, training, support, staff time and business continuity. Never compare a bare $20 server with a fully supported product.

## Catalogue

`catalog.v0.2.json` contains **18 product groups and 46 proposed paid plans**, expanding the 15 October portfolio of 17 groups/43 plans with **Alchemy NotNotes Business & Field Operations**. Finance and Insurance remain private design-partner candidates without public prices. The machine catalogue carries price targets and provisional included WLU for modelling; no allowance is asserted technically enforced.

| Initial product | Price hypotheses, USD per month | Customer outcome |
|---|---:|---|
| Alchemy Communications | $19 / $79 / $249 per workspace | CMS, website, brand content, contacts, enquiry, case and communications management |
| NotNotes Business & Field Operations | $149 / $299 / $499 per workspace | 20-user business document designer, forms/views, identity, approval, offline mobile operations at higher tier |
| Relationship | $12 / $29 / $49 per user | Governed CRM and customer relationship work |
| Service Desk | $15 / $45 / $85 per agent | Cases, routing, knowledge and support |
| Knowledge | $9 / $25 / $75 per user | Authoritative documents, revisions, permissions and publication |

Prices exclude tax, separately procured third-party services and buyer cloud bills. Managed SaaS must include infrastructure/support allowances in the price *when priced and qualified*. Quoted outcomes require end-to-end testing and published entitlements before public listing.

## Reading order

- [NotNotes 20-user acceptance and supported product definition](notnotes-field-operations.md)
- [Marketplace, billing and WLU contract](marketplace-commerce.md)
- [Competitive pricing and comparison discipline](competitive-pricing.md)
- [Non-negotiable release gates](release-gates.md)
- [Machine-readable catalogue](catalog.v0.2.json)

## Productization map

Marketplace order → resolve external order/identity → Commerce entitlement/trial → signed product and dependency manifest → least-privilege preflight → user-authorised deploy → functional proof → app onboarding → WLU usage/accepted event ledger → versioned rating and budget → provider metering/reconciliation.

All packages need exact accepted revisions, dependency locks and QA evidence. Availability of individual NotNotes, Wire UI, SMTP, LDAP, WLU, provenance or storage components in the Alchemy estate is **not proof** that the composite product can be installed or supported.

## Publication

This business-design portfolio is not an Alchemy Autobuild package submission. Executable source and compiled package delivery must follow [GIT_SUBMISSION.md](../../GIT_SUBMISSION.md) and the repo-specific dependency/provenance protocols. These files do not deploy, sell, bill or activate anything.
