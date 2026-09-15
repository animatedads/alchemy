# FederationBank Merchant <-> VMM Arm's-Length Flow Protocol v0.3

Protocol identity: `vmm.federation.arm_length/0.3`

## Legal entities

Producer/customer-flow side: `FEDERATIONBANK_MERCHANT_BANK`

Principal dealer/counterparty: `VECTOR_MERIDIAN_MARKETS_LTD`

The protocol does not make VMM a FederationBank book, agent, subledger or shared authority.

## Queues

- `VMM.ARM_LENGTH.RFQ`
- `VMM.ARM_LENGTH.QUOTE`
- `VMM.ARM_LENGTH.EXECUTE`
- `VMM.ARM_LENGTH.CONFIRM`

All are permanent Queue Fabric queues in security domain `VMM_FEDERATION_ARM_LENGTH`.

## Message types

### `VMMArmLengthRFQ`

Contains exact tradable-line identity, product type, customer side, notional, opaque relationship reference, Federation source authority and correlation/idempotency evidence.

It intentionally defines no customer legal-identity field.

### `VMMArmLengthQuote`

Contains the VMM quote identity, strategy, exact instrument key, bid/ask, validity and `VECTOR_MERIDIAN_MARKETS_LTD` as quoting entity.

### `VMMArmLengthExecutionInstruction`

Represents Federation's instruction that an accepted quote should become a VMM principal trade. It carries quote/trade IDs, source authority, idempotency/correlation and acceptance time; it carries no customer legal identity.

### `VMMArmLengthTradeConfirmation`

Confirms the VMM principal trade and explicitly identifies VMM as the legal entity and `FEDERATIONBANK_MERCHANT_FLOW` as the counterparty channel.

## ACL direction

Federation principal:

- PUT RFQ
- GET quote
- PUT execute
- GET confirmation

VMM principal:

- GET RFQ
- PUT quote
- GET execute
- PUT confirmation

The test suite checks the inverse permissions are denied, preventing either side from simply writing the other legal entity's message role.
