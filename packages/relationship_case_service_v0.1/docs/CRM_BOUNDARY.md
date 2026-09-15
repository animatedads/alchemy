# CRM boundary: theoretical component for the initial bank model

A full CRM can be a product lifetime of its own. FederationBank does not need to implement that lifetime before modelling its place correctly.

The general CRM authority should eventually own relationship facts such as:

- customer/contact relationship records and servicing ownership;
- interaction/correspondence history references;
- complaints as customer-relationship processes;
- promises, callbacks and follow-up work;
- communication preferences and service treatment profiles;
- relationship-manager tasks and hand-offs;
- customer-facing communications and their delivery state.

It should not own:

- balances or ledger postings;
- whether a payment committed;
- account restrictions and holds;
- legal or sanctions conclusions merely because a CRM user typed a note;
- the source content of Reputation Feed, Legal Effect or other specialist authorities.

The case service joins these worlds through typed opaque references. For example:

```text
RelationshipCaseElement
  elementType:      INTERACTION
  semanticKind:     CUSTOMER_CONTACT
  sourceSystem:     CRM-IOM
  sourceRef:        INTERACTION:99172
  authorityClass:   CRM_INTERACTION_REFERENCE
  relationship:     ORIGINATING_INTERACTION
```

A later `relationship_crm_v0.1` module can therefore evolve independently while preserving the case boundary. Its initial useful objects should be `RelationshipRecord`, `RelationshipInteractionRef`, `RelationshipCommunication`, `RelationshipPromise`, `RelationshipTask`, `ComplaintRecord` and a policy-driven `RelationshipServiceProfile`.

The first service boundary should expose references/events rather than shared database tables: `CRM.INTERACTION.RECORDED`, `CRM.COMPLAINT.RECOGNISED`, `CRM.COMMUNICATION.RECORDED`, `CRM.TASK.CREATED`, `CRM.TASK.COMPLETED`, with case correlation where applicable.
