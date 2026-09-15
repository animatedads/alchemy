codec=.RelationshipCRMQueuePersistenceSupport~newCodec
r=.RelationshipRecord~new("REL-Q","COREBANK","CUST-Q")
i=.RelationshipInteractionRef~new("I-Q","REL-Q","INTERACTION-EVENT","IE-Q","BRANCH","INBOUND",.DateTime~new)
a=.array~of(r,i)
encoded=codec~encode(a); restored=codec~decode(encoded)
.CRMTest~assertEqual("REL-Q",restored[1]~relationshipId)
.CRMTest~assertEqual("IE-Q",restored[2]~sourceRef)
say "PASS queue persistence"
::requires "TestSupport.cls"
::requires "RelationshipCRMQueuePersistence.cls"
