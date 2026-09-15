# Service Boundary

## Responsibilities

FederationBank Staff Authority Service owns the durable coordination state needed to evaluate employee business authority. It stores snapshots/references rather than becoming the authority for workforce identity itself.

```text
IAM / workforce integration
        |
 sealed StaffContextSnapshot
        |
        v
FBSTAFF.CONTEXT.PUT
        |
        +--------------------------+
        |                          |
Maker action               checker context/approval
        |                          |
        +-------------+------------+
                      |
             FBSTAFF.ACTION.AUTHORISE
                      |
              StaffAuthorityEngine
                      |
             +--------+---------+
             |                  |
     APPROVAL_REQUIRED       AUTHORISED
             |                  |
        durable record      sealed envelope
             +--------+---------+
                      |
                 durable outbox
```

## Non-responsibilities

The service does not:

- authenticate employees;
- maintain the HR employee master;
- decide Relationship Case or complaint outcomes;
- decide customer/product limits;
- execute banking commands;
- post money;
- expose a Ledger submission API.

## Queue Fabric

`FederationBankStaffAuthorityQueueWorker` consumes typed `FederationBankStaffServiceEnvelope` objects and can create temporary or permanent command/event queues. For a permanent command queue, the persisted typed command graph survives manager reconstruction and can then be claimed and processed.

Replies are optional and correlation-aware. Failed reply delivery nacks rather than acknowledging the input command.
