c=.FederationBankCRMPolicyFixtures~publishedCatalog; s=.RelationshipCRMService~new(c)
r=.RelationshipRecord~new("REL-P","COREBANK","CUST-P")
p=.directory~new; p["relationship"]=r; call assert s~handle(.RelationshipCRMServiceEnvelope~new("P1","CRM.RELATIONSHIP.OPEN","T1","TELLER",p))~ok
comp=.ComplaintRecord~new("CMP-P","REL-P","INTERACTION:1",.DateTime~new,"OPEN","","RESTRICTED"); p=.directory~new; p["complaint"]=comp; call assert s~handle(.RelationshipCRMServiceEnvelope~new("P2","CRM.COMPLAINT.RECOGNISE","T1","TELLER",p))~ok
p=.directory~new; p["relationshipId"]="REL-P"
teller=s~handle(.RelationshipCRMServiceEnvelope~new("Q1","CRM.PROJECT","T1","TELLER",p)); call assert teller~ok; .CRMServiceTest~assertEqual("0",teller~value~complaints~items)
compl=s~handle(.RelationshipCRMServiceEnvelope~new("Q2","CRM.PROJECT","C1","COMPLAINTS",p)); call assert compl~ok; .CRMServiceTest~assertEqual("1",compl~value~complaints~items)
say "PASS policy projection"
exit 0
assert: procedure; use arg v; .CRMServiceTest~assertTrue(v); return
::requires "TestSupport.cls"
::requires "RelationshipCRMService.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
