call test
say "PASS task promise policy"
exit 0

test:
  c=.FederationBankCRMPolicyFixtures~publishedCatalog; e=.RelationshipCRMEngine~new(c); r=.RelationshipRecord~new("REL-3","COREBANK","CUST-003")
  call a e~openRelationship(r,"T1","TELLER")~ok
  t=.RelationshipTask~new("T-1","REL-3","CALLBACK","T1","TELLER",.DateTime~new+.TimeSpan~new(0,0,0,1))
  call a e~createTask(t,"T1","TELLER")~ok
  denied=e~transitionTask("T-1","CANCEL","T1","TELLER"); .CRMTest~assertTrue(\denied~ok); .CRMTest~assertEqual("CRM_POLICY_DENIED",denied~code)
  call a e~transitionTask("T-1","COMPLETE","T1","TELLER")~ok
  p=.RelationshipPromise~new("P-1","REL-3","CALLBACK",.DateTime~new+.TimeSpan~new(0,0,0,1),"T1","TELLER")
  call a e~recordPromise(p,"T1","TELLER")~ok; call a e~transitionPromise("P-1","FULFIL","T1","TELLER")~ok; .CRMTest~assertEqual("FULFILLED",p~state)
return
a: procedure; use arg v; .CRMTest~assertTrue(v); return
::requires "TestSupport.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
