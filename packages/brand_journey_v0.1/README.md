# Brand Journey v0.1

`Brand Journey` models the **overall customer-facing brand experience across
organisational boundaries**.  It is the continuity layer above individual
interaction episodes and below effect/statistical reasoning.

The core premise is that a customer does not experience Support, Delivery,
Billing and Sales as unrelated organisations.  Those touchpoints are all part of
the commercial and reputational relationship.

## What it does

- retains privacy-minimised touchpoints across operational domains;
- records cross-domain handoff continuity without storing raw customer text;
- distinguishes brand/promotional work from an actual sales proposition;
- exposes repeated-explanation burden and lost context;
- keeps unresolved service state visible across departmental boundaries;
- recognises cross-domain recovery without deleting the earlier failure;
- can flag an **explicit** sales proposition made while the underlying service
  need is still unresolved;
- produces controlled findings that can bridge into Brand Interaction Effect.

## What it does not do

- customer identity / CRM;
- session or user matching;
- access-point instrumentation;
- customer-data storage;
- causal attribution;
- automatic sales authority.

Correlation is supplied externally.  A customer-specific `relationshipRef` is
`SECRET`; the public/customer-safe journey id is separate.

## Service as Sales

A support or delivery touchpoint is commercial/brand work even if nobody tries
to upsell anything.  In v0.1 this is represented explicitly:

```text
SERVICE_AS_SALES_JOURNEY
PROMOTIONAL_TOUCHPOINTS=2
EXPLICIT_SALES=0
```

The package will not convert `PROMOTIONAL_WORK` into `SALESPROP`.

## Stable points

- `BRAND_JOURNEY:<journey-id>`
- `BRAND_JOURNEY:TOUCHPOINT:<touchpoint-id>`
- `BRAND_JOURNEY:HANDOFF:<handoff-id>`
- `BRAND_JOURNEY:ASSESSMENT:<assessment-id>`

## Dependencies

Core:

- ooRexx 5.3.0 r13196 behaviour profile
- Alchemy Objects v0.4.3
- ooRexx Crypto v0.1 (through Alchemy Objects)

Optional integrations/tests:

- Brand Interaction Effect v0.3
- Runtime Registry v0.12
