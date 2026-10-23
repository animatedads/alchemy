# Commerce and marketplace billing integration — versioned contract design

**Status: proposed; no live metering or marketplace listing.**

## Shared layers

Marketplace procurement → tenant/external agreement mapping → Alchemy Commerce entitlement/trial/versioned signed SKU → authorized deployment/health → app accepted usage → raw Work Load Units record → tariff conversion → commercial usage ledger → cloud-specific meter/receipt → reconciliation/dispute/credit.

Application semantics remain independent of provider and carrier. Connect Selector supports direct call, RPC and Queue Fabric when delivered; no design assumes Queue Fabric is a compulsory dependency. Serialization Selector and RPC dispatcher are separate authorities.

## WLU and finance invariants

- Raw WLU is not directly an approved third-party billing currency; map accepted activity to **commercial WLU** using a dated, signed, published activity/conversion tariff.
- Charge accepted useful work, not internal maintenance, failures, retries, discarded jobs, replay/migration or transport chatter.
- Deduplicate on tenant + agreement + dimension + canonical event + period; persist provider accepted receipts. Never meter a successful job twice after crash, reschedule, migration or billing retry.
- Historical rates are immutable to completed periods. Credit/reversal is a linked auditable correction event.
- Support budget warnings, consent, hard caps, paid-overage terms and detailed usage/export/dispute. Example **$10/10,000 commercial WLU** is a modelling assumption only, not a price commitment.
- Measure cost per activity under peak/trial workloads before fixing allowances or claiming a contribution margin.

## Per-channel conditions (not interchangeable)

**Microsoft Marketplace transactable SaaS:** 14-day plan trials fit the permitted 1–180-day window. Trials automatically convert to paid if not cancelled/auto-renew disabled; require accurate warning and cancellation information. The Microsoft SaaS metering service applies to **flat-rate SaaS offers** and **does not support metered overage on per-user SaaS plans**. For CRM/Case/Knowledge per-seat products, either adopt flat-rate bundled-seat plans with usage dimensions or do not sell metered WLU overage; never silently combine incompatible types. Fulfillment API, landing page, webhook, Entra ID and tenant mapping are blocking.
https://learn.microsoft.com/en-us/partner-center/marketplace-offers/plan-saas-offer
https://learn.microsoft.com/en-us/partner-center/marketplace-offers/saas-metered-billing

**AWS Marketplace SaaS:** an AWS SaaS free trial **does not automatically become a paid agreement**. Capture an affirmative paid conversion; verify SaaS procurement, entitlement and hourly metering dimensions and settlement. Do not call an AMI/container listing an SaaS sale to assume favorable channel fees.
https://docs.aws.amazon.com/marketplace/latest/buyerguide/saas-free-trials.html

**Google Cloud Marketplace:** standalone subscription, usage, or combined pricing supported; usage dimension `commercial_wlu` needs public per-action submetrics and conversion/rates. Trial duration **and** credit cap apply and can end earlier on credit exhaustion; customers pay after trial on their selected plan. Integrate Partner Procurement API, Pub/Sub lifecycle and Service Control reporting.
https://docs.cloud.google.com/marketplace/docs/partners/integrated-saas/select-pricing
https://docs.cloud.google.com/marketplace/docs/partners/integrated-saas/technical-integration-setup

**OCI, IBM and other clouds:** deployment portability is not native marketplace transaction/billing. Approve each published procurement, charging, conversion and cancellation capability separately. Direct invoice is a different commercial contract.

## Hosted versus private installation

Alchemy-managed hosted SaaS must carry operating infrastructure within the seller's cost model. BYOC/private installation may charge customer cloud compute/network/storage separately and may need an entirely different offer type, negotiated support obligation and permissions. Customer must know the billing split before deploying.

**14-day trial** refers to software entitlement, not free underlying buyer resources, SMS/email carrier fees or unbounded premium inference. Trial and cancellation must not silently erase documents; governed export/retention/read-only transition is specified by contract.

## Required evidence

Sandbox orders and billing lifecycle per provider; exact 14-day behavior; approved tariff and plan manifest; 24h/period close and correction; customer-facing forecast; duplicate-retry test; refunds/disputes; access revocation, subscription cancellation, region and daylight-saving changes; data export/teardown; published support commitments. Nothing is presumed passed here.
