c=.FederationBankCRMPolicyFixtures~publishedCatalog; s=.RelationshipCRMService~new(c)
r=.RelationshipRecord~new("REL-ID","COREBANK","CUST-ID")
p=.directory~new; p["relationship"]=r
e=.RelationshipCRMServiceEnvelope~new("ID-1","CRM.RELATIONSHIP.OPEN","T1","TELLER",p)
a=s~handle(e); .CRMServiceTest~assertTrue(a~ok)
b=s~handle(e); .CRMServiceTest~assertTrue(b~ok); .CRMServiceTest~assertEqual("IDEMPOTENT_REPLAY",b~code)
r2=.RelationshipRecord~new("REL-OTHER","COREBANK","CUST-OTHER"); p2=.directory~new; p2["relationship"]=r2
conf=s~handle(.RelationshipCRMServiceEnvelope~new("ID-1","CRM.RELATIONSHIP.OPEN","T1","TELLER",p2)); .CRMServiceTest~assertTrue(\conf~ok); .CRMServiceTest~assertEqual("COMMAND_ID_CONFLICT",conf~code)
say "PASS idempotency"
::requires "TestSupport.cls"
::requires "RelationshipCRMService.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
