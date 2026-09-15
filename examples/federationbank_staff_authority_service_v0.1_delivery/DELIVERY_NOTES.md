# FederationBank Staff Authority v0.1 — Complete Delivery

This delivery contains the matching domain and durable service packages:

- `federationbank_staff_authority_v0.1`
- `federationbank_staff_authority_service_v0.1`

## Architectural purpose

The pair gives FederationBank an explicit institutional authority boundary for staff work before a staff-facing application is built.

It keeps these authorities independent:

```text
Relationship/case decision
        |
        v
banking action proposed
        |
        +---- employee/session/role/delegation/elevation
        |                    |
        |                    v
        |             Staff Authority
        |              maker/checker
        |                    |
        +--------------------+
                    |
          exact STAFF command binding
                    |
                    v
             Core Banking policy
          Legal / Security / Product
                    |
                    v
                  Ledger
```

Staff Authority is neither HR/IAM nor Core Banking. It consumes sealed references/snapshots of externally authoritative workforce/session facts and issues exact-action authority evidence. Core Banking then independently decides whether the customer's banking operation is permitted.

## Qualified behavior

- 8/8 Staff Authority module tests pass.
- 1/1 Relationship Case -> Relationship Adapter -> Staff Authority -> Core Banking -> Ledger integration test passes.
- 8/8 Staff Authority Service tests pass.
- 11/11 package `.cls` files pass `rexxc` under ooRexx 5.3.0 r13196.
- Permanent Queue Fabric recovery of typed staff-authority commands is exercised.
- Semantic command idempotency and at-least-once outbox retry are exercised.
- Staff authority cannot bypass separate customer/product Core Banking policy.
- There is no Staff Authority or Staff Authority Service -> Ledger ingress.

The fixture Staff/Core policy limits are illustrative qualification data, not production banking policy.
