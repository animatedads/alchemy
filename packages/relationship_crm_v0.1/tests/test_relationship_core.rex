call test
say "PASS relationship core"
exit 0

test:
  c=.FederationBankCRMPolicyFixtures~publishedCatalog; e=.RelationshipCRMEngine~new(c)
  r=.RelationshipRecord~new("REL-1","COREBANK","CUST-001","TEL-01","TELLER")
  x=e~openRelationship(r,"TEL-01","TELLER"); .CRMTest~assertTrue(x~ok); .CRMTest~assertEqual("ACTIVE",r~status)
  .CRMTest~assertEqual("1",r~revision)
return
::requires "TestSupport.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
