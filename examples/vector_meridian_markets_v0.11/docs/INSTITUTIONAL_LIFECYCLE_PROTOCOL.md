# VMM Institutional Synthetic Lifecycle Protocol v0.6

Protocol: `vmm.institutional.synthetic.lifecycle/0.6`

This protocol extends the already accepted direct-institution formation boundary `vmm.institutional.synthetic/0.5`. The formation protocol remains unchanged for request -> offer -> acceptance -> confirmation.

The lifecycle protocol exists for post-trade instructions that originate with the institutional counterparty but must become authoritative VMM records only after VMM admission and evidence checks.

## Durable queues

- `VMM.INSTITUTIONAL.SYNTHETIC.LIFECYCLE.INSTRUCTION`
- `VMM.INSTITUTIONAL.SYNTHETIC.LIFECYCLE.RESULT`

The institutional gateway has PUT on the instruction queue and GET on the result queue. The VMM lifecycle principal has the inverse authority. Federation principals have no ACL on either queue.

## v0.6 instruction types

### Premium payment notice

`VMMInstitutionalPremiumPaymentNotice` carries:

- notice/idempotency/correlation identity;
- VMM contract and premium-period identity;
- VMM institutional counterparty ID and disclosed source legal entity;
- source authority;
- currency and payment amount;
- externally attributable payment evidence;
- payment time.

A successful notice creates a `VMMSyntheticPremiumSettlement` whose payee must be `VECTOR_MERIDIAN_MARKETS_LTD`. FederationBank cannot be named as the premium recipient.

### Reference portfolio change request

`VMMInstitutionalReferenceChangeRequest` carries:

- request/idempotency/correlation identity;
- VMM contract identity;
- replacement immutable portfolio-snapshot identity;
- `CLIENT_SUBSTITUTION` or `CORPORATE_ACTION` cause;
- institutional legal identity and authority;
- effective time and external change evidence.

The message itself cannot authorise a VMM risk decision. Before VMM records the change, the lifecycle service requires independent VMM risk approval and VMM contract-control authority. Client substitutions are also checked against the configured value-drift limit and current wrong-way-risk policy.

## Deliberately not a one-sided instruction

Novation is not represented as a lifecycle queue message in v0.6. A legal novation requires outgoing-counterparty authority, incoming-counterparty authority and VMM authority, plus a replacement successor-owned reference snapshot. The executable service records this as a tripartite `VMMSyntheticNovation` and creates a new legal VMM contract rather than mutating the old contract's identity.

## Boundary rule

The institutional lifecycle gateway has no `VectorMeridianMarkets` engine or `VMMInstitutionalSyntheticService` reference. Queue Fabric remains the cross-company message boundary. VMM risk, valuation, collateral, accounting and execution internals remain private VMM authority.
