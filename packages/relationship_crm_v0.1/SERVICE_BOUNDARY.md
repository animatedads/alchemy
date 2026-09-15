# Service boundary

The core module intentionally contains no network listener and no shared CRM database contract.  A service adapter should expose commands/events over Queue Fabric and persist the typed object graph.  Reads must return policy projections, never a raw repository.

Suggested command family:

- `CRM.RELATIONSHIP.OPEN`
- `CRM.INTERACTION.RECORD`
- `CRM.COMMUNICATION.RECORD`
- `CRM.COMMUNICATION.TRANSITION`
- `CRM.PROMISE.RECORD` / `CRM.PROMISE.TRANSITION`
- `CRM.TASK.CREATE` / `CRM.TASK.TRANSITION`
- `CRM.COMPLAINT.RECOGNISE` / `CRM.COMPLAINT.LINK_CASE` / `CRM.COMPLAINT.TRANSITION`
- `CRM.PROFILE.SET`
- `CRM.PROJECT` / `CRM.FOR_SUBJECT`
