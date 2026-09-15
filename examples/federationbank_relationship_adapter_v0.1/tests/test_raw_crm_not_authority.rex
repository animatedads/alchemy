catalog=.FederationBankRelationshipPolicyFixtures~publishedCatalog
adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(catalog))
crm=.RelationshipCRMEntry~new("DIR-1","SERVICE_DIRECTIVE","HIGH_TOUCH","ACTIVE","CRM","PROFILE:ALAN","SERVICE_GUIDANCE",.nil,"INTERNAL","CASE-104","RM-1","RELATIONSHIP",.nil,"HIGH","COMMUNICATION_STYLE","FORMAL_PERSONAL")~seal
req=.FederationBankRelationshipActionRequest~new("REQ-1","CMD-1","IDEM-1","CASE-104","CUST-ALAN","TRANSFER","TELLER-7","TELLER",.nil,"A1","A2","GBP",1000)~seal
r=adapter~translate(crm,req,.nil)
.FBRelationshipTestSupport~assertFalse(r~ok,"CRM entry rejected as bank authority")
.FBRelationshipTestSupport~assertEq("BANK_ACTION_DECISION_REQUIRED",r~code,"typed decision boundary")
.FBRelationshipTestSupport~pass("raw CRM/service directive cannot authorise Core Banking")
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "RelationshipCRM.cls"
::requires "TestSupport.cls"
