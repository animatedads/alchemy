# Relationship CRM Service v0.1

Durable Queue Fabric/service boundary around `relationship_crm_v0.1`.

It exposes relationship servicing commands without turning CRM into Core Banking or Relationship Case.

## Commands

- `CRM.RELATIONSHIP.OPEN`
- `CRM.INTERACTION.RECORD`
- `CRM.COMMUNICATION.RECORD` / `CRM.COMMUNICATION.TRANSITION`
- `CRM.PROMISE.RECORD` / `CRM.PROMISE.TRANSITION`
- `CRM.TASK.CREATE` / `CRM.TASK.TRANSITION`
- `CRM.COMPLAINT.RECOGNISE` / `CRM.COMPLAINT.LINK_CASE` / `CRM.COMPLAINT.TRANSITION`
- `CRM.PROFILE.SET`
- `CRM.PROJECT`
- `CRM.FOR_SUBJECT`

All reads are policy-projected.  There is deliberately no raw repository command.

Mutation command ids carry a semantic fingerprint: exact retries are idempotent; reuse for different semantics fails `COMMAND_ID_CONFLICT`.

A mutation commits domain state, receipt and outbox event to one typed service-state checkpoint before publication.  Sink failure leaves a durable event pending for later delivery.
