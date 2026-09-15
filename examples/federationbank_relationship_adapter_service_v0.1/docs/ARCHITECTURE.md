# Architecture

```text
Relationship Case + authoritative decision
                 |
                 v
       Relationship Adapter
                 |
          service action
         /             \
NO_BANK_ACTION     bank submission port
      |                   |
      |             Account / Payments queues
      |                   |
      +--------- durable correlation <---- bank result
                         |
                    service event
                         |
                Case / CRM consumers
```

Persistence, idempotency and event outbox are service mechanics. They do not change authority ownership.
