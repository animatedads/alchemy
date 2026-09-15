# All Japan / Regulated Intermediary Adapter v0.1

Narrow provider adapter between Federation's Regulated Intermediary Distribution service and All Japan Insurance v0.4.

## Institutional rule

FederationBank acts as the regulated intermediary/distribution channel. All Japan remains insurer authority even though both are in the Federation group.

The adapter may:

- validate an insurance distribution case is actually `SUBMISSION_REQUESTED`;
- prove the RID product reference is the exact All Japan product semantic identity;
- submit the risk through AJI's `DISTRIBUTION_CHANNEL` role;
- observe AJI-owned underwriting/quote/policy truth;
- project exact provider statuses back into the RID case.

The adapter may not:

- underwrite;
- rate or override premium;
- bind a policy;
- assess claims;
- move customer money;
- treat Federation group ownership as insurer authority.

## Provider lifecycle projection

An executable qualification runs:

`RID SUBMISSION_REQUESTED -> AJI risk submission -> RECEIVED -> AJI ACCEPT -> APPROVED -> AJI quote -> OFFERED -> AJI bound policy -> BOUND`.

The provider case reference is the AJI submission id. Each subsequent projection must match that exact provider case and product.

## Sales targets

Sales targets are workforce/CRM objectives, not distribution evidence. A `SALES_TARGET` evidence reference cannot satisfy `DEMANDS_AND_NEEDS`, suitability, customer consent or any other policy-required customer evidence. The regression test explicitly proves this.

## Current qualification

- adapter: 4/4 executable tests PASS;
- adapter `.cls`: 3/3 PASS `rexxc` (source + test fixtures/support);
- actual All Japan Insurance v0.4 full suite: 31/31 PASS;
- RID v0.2 + service qualification also green.
