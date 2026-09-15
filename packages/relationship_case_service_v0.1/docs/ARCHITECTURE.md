# Architecture

```text
Interaction Event   Reputation Feed   Legal/Policy   CRM (relationship authority)
       |                  |                |                    |
       +------------------+----------------+--------------------+
                                   |
                         Relationship Case v0.2
                           typed reference graph
                                   |
                      Relationship Case Service v0.1
                  command idempotency / persistence / outbox
                          policy-projected reads
                          /                 \
                  Queue Fabric             direct in-process
                     commands/events        service calls
                          |                     |
                    service adapters      specialist adapters
                          \                     /
                           FederationBank / staff channels
```

The service owns coordination durability only. It does not own account state, money, legal effect, sanctions truth, external reputation truth, or CRM record contents.

## Commit boundary

A successful mutation is:

1. evaluate current Institutional Policy through the Relationship Case engine;
2. mutate the domain object and create a domain event carrying exact policy release evidence;
3. create a service event with correlation/causation and that domain policy evidence;
4. add a semantic idempotency receipt and event to the durable outbox;
5. append the complete typed service-state checkpoint;
6. attempt event publication;
7. persist removal from the outbox after successful publication.

If step 5 fails, the service latches `faulted` and refuses further work. If step 6 fails, the business mutation remains committed and the event remains pending. If step 7 fails, the service faults and may redeliver the same stable event id after recovery.

## Information barrier

`CASE.GET`, `CASE.PROJECT`, and `CASE.FOR_SUBJECT` always invoke `RelationshipCaseEngine~project`. A restricted case may therefore appear as a policy-generated shell or be absent entirely; transport and UI layers cannot bypass this by asking for the raw service repository.
