now=.DateTime~new
dec=.FederationBankRelationshipDecision~new("DEC-104-NOACT","CASE-104","E-DEC-104","CUST-ALAN","FB-COMPLIANCE-IOM","COMPLIANCE_DECISION","CMP:DEC:104","NO_BANK_ACTION","NONE","POLICY:104","",now)~seal
el=.FBRelationshipTestSupport~decisionElement("E-DEC-104","FB-COMPLIANCE-IOM","CMP:DEC:104","COMPLIANCE_DECISION","NO_BANK_ACTION")
req=.FederationBankRelationshipActionRequest~new("REQ-NOACT","CMD-NOACT","IDEM-NOACT","CASE-104","CUST-ALAN","NONE","CMP-17","COMPLIANCE",now)~seal
adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(.FederationBankRelationshipPolicyFixtures~publishedCatalog))
r=adapter~translate(dec,req,el)
.FBRelationshipTestSupport~assertTrue(r~ok,"no-action decision accepted")
.FBRelationshipTestSupport~assertEq("NO_BANK_ACTION",r~value~outcome,"outcome")
.FBRelationshipTestSupport~assertTrue(r~value~bankCommand==.nil,"no Core Banking command exists")
.FBRelationshipTestSupport~pass("explicit NO_BANK_ACTION is durable integration outcome")
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "TestSupport.cls"
