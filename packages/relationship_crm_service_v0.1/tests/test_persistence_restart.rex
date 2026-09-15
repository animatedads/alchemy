root=value("CRM_TEST_ROOT",,"ENVIRONMENT"); if root="" then raise syntax 88.900 array("CRM_TEST_ROOT required")
c=.FederationBankCRMPolicyFixtures~publishedCatalog
st=.RelationshipCRMServiceStore~new(root)
s=.RelationshipCRMService~new(c,,st)
r=.RelationshipRecord~new("REL-R","COREBANK","CUST-R")
p=.directory~new; p["relationship"]=r; call assert s~handle(.RelationshipCRMServiceEnvelope~new("R1","CRM.RELATIONSHIP.OPEN","T1","TELLER",p))~ok
t=.RelationshipTask~new("TASK-R","REL-R","CALLBACK","T1","TELLER",.DateTime~new+.TimeSpan~new(0,0,0,1)); p=.directory~new; p["task"]=t; call assert s~handle(.RelationshipCRMServiceEnvelope~new("R2","CRM.TASK.CREATE","T1","TELLER",p))~ok
s2=.RelationshipCRMService~new(c,,.RelationshipCRMServiceStore~new(root))
p=.directory~new; p["relationshipId"]="REL-R"; q=s2~handle(.RelationshipCRMServiceEnvelope~new("RQ","CRM.PROJECT","T1","TELLER",p)); call assert q~ok; .CRMServiceTest~assertEqual("1",q~value~tasks~items)
replay=s2~handle(.RelationshipCRMServiceEnvelope~new("R1","CRM.RELATIONSHIP.OPEN","T1","TELLER",.directory~new)); .CRMServiceTest~assertTrue(\replay~ok); .CRMServiceTest~assertEqual("COMMAND_ID_CONFLICT",replay~code)
say "PASS persistence restart"
exit 0
assert: procedure; use arg v; .CRMServiceTest~assertTrue(v); return
::requires "TestSupport.cls"
::requires "RelationshipCRMServicePersistence.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
