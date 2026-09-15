call test
say "PASS interaction communication"
exit 0

test:
  c=.FederationBankCRMPolicyFixtures~publishedCatalog; e=.RelationshipCRMEngine~new(c); r=.RelationshipRecord~new("REL-2","COREBANK","CUST-002")
  call assert e~openRelationship(r,"T1","TELLER")~ok
  i=.RelationshipInteractionRef~new("I-1","REL-2","INTERACTION-EVENT","IE-77","BRANCH","INBOUND",.DateTime~new)
  call assert e~recordInteraction(i,"T1","TELLER")~ok
  m=.RelationshipCommunication~new("M-1","REL-2","RECEIPT","EMAIL","DEST-9","DOC-1")
  call assert e~recordCommunication(m,"T1","TELLER")~ok
  call assert e~transitionCommunication("M-1","MARK_SENT","MAILER","SERVICE")~ok
  call assert e~transitionCommunication("M-1","MARK_DELIVERED","MAILER","SERVICE")~ok
  .CRMTest~assertEqual("DELIVERED",m~deliveryState)
return
assert: procedure
  use arg v
  .CRMTest~assertTrue(v)
return
::requires "TestSupport.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
