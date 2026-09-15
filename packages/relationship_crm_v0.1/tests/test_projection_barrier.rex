call test
say "PASS projection barrier"
exit 0

test:
  c=.FederationBankCRMPolicyFixtures~publishedCatalog; e=.RelationshipCRMEngine~new(c); r=.RelationshipRecord~new("REL-5","COREBANK","CUST-005")
  call a e~openRelationship(r,"T1","TELLER")~ok
  comp=.ComplaintRecord~new("CMP-R","REL-5","INTERACTION:I-2",.DateTime~new,"OPEN","","RESTRICTED")
  call a e~recogniseComplaint(comp,"T1","TELLER")~ok
  p=e~project("REL-5","TELLER"); call a p~ok; .CRMTest~assertEqual("0",p~value~complaints~items)
  p2=e~project("REL-5","COMPLAINTS"); call a p2~ok; .CRMTest~assertEqual("1",p2~value~complaints~items)
return
a: procedure; use arg v; .CRMTest~assertTrue(v); return
::requires "TestSupport.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
