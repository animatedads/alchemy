root=value("CRM_TEST_ROOT",,"ENVIRONMENT"); if root="" then raise syntax 88.900 array("CRM_TEST_ROOT required")
c=.FederationBankCRMPolicyFixtures~publishedCatalog; sink=.RelationshipCRMMemoryEventSink~new; sink~failNext
s=.RelationshipCRMService~new(c,,.RelationshipCRMServiceStore~new(root),sink)
r=.RelationshipRecord~new("REL-O","COREBANK","CUST-O"); p=.directory~new; p["relationship"]=r
a=s~handle(.RelationshipCRMServiceEnvelope~new("O1","CRM.RELATIONSHIP.OPEN","T1","TELLER",p)); .CRMServiceTest~assertTrue(a~ok); .CRMServiceTest~assertEqual("1",s~state~outbox~items)
s2=.RelationshipCRMService~new(c,,.RelationshipCRMServiceStore~new(root),sink); f=s2~flushOutbox; .CRMServiceTest~assertTrue(f~ok); .CRMServiceTest~assertEqual("0",s2~state~outbox~items); .CRMServiceTest~assertEqual("1",sink~events~items)
say "PASS outbox recovery"
::requires "TestSupport.cls"
::requires "RelationshipCRMServicePersistence.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
