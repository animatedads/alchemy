c=.FederationBankCRMPolicyFixtures~publishedCatalog; s=.RelationshipCRMService~new(c)
r=.RelationshipRecord~new("REL-S1","COREBANK","CUST-S1","T1","TELLER")
p=.directory~new; p["relationship"]=r
a=s~handle(.RelationshipCRMServiceEnvelope~new("C1","CRM.RELATIONSHIP.OPEN","T1","TELLER",p)); .CRMServiceTest~assertTrue(a~ok)
i=.RelationshipInteractionRef~new("I-S1","REL-S1","INTERACTION-EVENT","IE-S1","BRANCH","INBOUND",.DateTime~new)
p=.directory~new; p["interaction"]=i
b=s~handle(.RelationshipCRMServiceEnvelope~new("C2","CRM.INTERACTION.RECORD","T1","TELLER",p)); .CRMServiceTest~assertTrue(b~ok)
p=.directory~new; p["relationshipId"]="REL-S1"
q=s~handle(.RelationshipCRMServiceEnvelope~new("Q1","CRM.PROJECT","T1","TELLER",p)); .CRMServiceTest~assertTrue(q~ok); .CRMServiceTest~assertEqual("1",q~value~interactions~items)
say "PASS service commands"
::requires "TestSupport.cls"
::requires "RelationshipCRMService.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
