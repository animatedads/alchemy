call test
say "PASS service profile authority"
exit 0

test:
  c=.FederationBankCRMPolicyFixtures~publishedCatalog; e=.RelationshipCRMEngine~new(c); r=.RelationshipRecord~new("REL-6","COREBANK","CUST-006")
  call a e~openRelationship(r,"M1","SERVICE_MANAGER")~ok
  p=.RelationshipServiceProfile~new("SP-1","REL-6","PRIORITY_SERVICE","EMAIL","CALLBACK_FIRST")
  denied=e~setServiceProfile(p,"T1","TELLER"); .CRMTest~assertTrue(\denied~ok)
  ok=e~setServiceProfile(p,"M1","SERVICE_MANAGER"); call a ok~ok
  .CRMTest~assertEqual("CALLBACK_FIRST",ok~value~serviceTreatment)
  /* No object or method in this module posts money or sets account holds. */
  .CRMTest~assertTrue(\ok~value~hasMethod("POST")); .CRMTest~assertTrue(\ok~value~hasMethod("HOLD"))
return
a: procedure; use arg v; .CRMTest~assertTrue(v); return
::requires "TestSupport.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
