# Service Boundary

## Responsibility

The service makes a long-lived staff journey reliable. It coordinates existing authorities and preserves enough durable evidence to resume work without reinterpreting UI state.

```text
Staff producer / future Wire UI / branch workflow
                    |
             ACTION.SUBMIT
                    |
          Staff Channel domain
                    |
        Staff Authority Service
                    |
       +------------+-------------+
       |                          |
APPROVAL_REQUIRED            READY_FOR_CORE
       |                          |
 durable pause                 durable save
       |                          |
ACTION.RESUME                   Core port
       |                          |
       +------------+-------------+
                    |
           final durable state
                    |
              event outbox
```

## Non-responsibilities

The service does not:

- authenticate employees;
- own HR/IAM truth;
- decide a complaint or relationship case;
- infer banking authority from CRM/reputation/external signals;
- change Staff Authority policy;
- change Core Banking customer/product/legal/security policy;
- post directly to the Ledger;
- own detailed Core/Ledger receipts;
- render a website.

## Recovery rule

`READY_FOR_CORE` is the recovery point. Only the exact command already bound to a positive Staff Authority envelope can be retried. The service never recreates a different command from a stale screen or mutable form.

Core port transport failures use `CORE_PORT_*` / `CORE_DELIVERY_*` and leave the work ready for retry. A real Core institutional decline becomes `CORE_REJECTED` and is final unless a new legitimate banking action is created.
