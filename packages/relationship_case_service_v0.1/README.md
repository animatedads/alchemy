# Relationship Case Service v0.1

A durable service boundary around the general `relationship_case_v0.2` domain model.

This is deliberately **not a website and not a CRM implementation**. It is the service layer that lets CRM, banking, compliance, legal, reputation, interaction, document and staff-channel modules coordinate around the same case without transferring authority to the case service.

## Commands

- `CASE.OPEN`
- `CASE.ATTACH_ELEMENT`
- `CASE.TRANSITION`
- `CASE.GET`
- `CASE.PROJECT`
- `CASE.FOR_SUBJECT`

Every externally visible read is policy-projected. There is no queue command that returns an unfiltered raw case.

## Durable behaviour

Mutations are assigned a command id. The service retains a semantic command fingerprint, so exact retries are idempotent while reuse of the same command id for a different actor/action/payload fails with `COMMAND_ID_CONFLICT`.

The persistence adapter uses Queue Fabric v0.9-dev4's append-only `QueueDurableStore` and graph codec. Each committed mutation appends a complete typed service-state checkpoint containing cases, domain event histories, command receipts, service audit events and the event outbox. The underlying source evidence remains referenced in its authoritative module rather than copied into the checkpoint.

Service events are committed to the outbox before publication. Sink failure therefore leaves a durable pending event. Delivery is at-least-once: if publication succeeds but persisting the outbox acknowledgement fails, the stable event id allows downstream de-duplication after restart.

## CRM place in the model

`RelationshipCaseCRMBridge.cls` intentionally models only the boundary. A CRM-owned customer, interaction, communication, complaint or work item becomes a typed `RelationshipCaseElement` carrying the CRM system and opaque source record reference. The case does not become the CRM of record and a CRM reference never acquires Core Banking authority merely by being attached to a case.

See `docs/CRM_BOUNDARY.md` for the proposed next general CRM module.
