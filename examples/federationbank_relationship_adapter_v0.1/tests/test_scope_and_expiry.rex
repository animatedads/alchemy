now=.DateTime~new
past=now-.TimeSpan~new(0,0,0,1)
dec=.FederationBankRelationshipDecision~new("DEC-OLD","CASE-X","E-OLD","CUST-A","FB-STAFF-AUTH","STAFF_TRANSACTION_AUTHORITY","AUTH:OLD","CUSTOMER_INSTRUCTION_VALIDATED","TRANSFER","POL:OLD","",past,past)~seal
el=.FBRelationshipTestSupport~decisionElement("E-OLD","FB-STAFF-AUTH","AUTH:OLD","STAFF_TRANSACTION_AUTHORITY")
req=.FederationBankRelationshipActionRequest~new("REQ-OLD","CMD-OLD","IDEM-OLD","CASE-X","CUST-A","TRANSFER","TELLER-1","TELLER",now,"A","B","USD",10)~seal
adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(.FederationBankRelationshipPolicyFixtures~publishedCatalog))
r=adapter~translate(dec,req,el)
.FBRelationshipTestSupport~assertFalse(r~ok,"expired decision rejected")
.FBRelationshipTestSupport~assertEq("BANK_ACTION_DECISION_NOT_EFFECTIVE",r~code,"expiry")
dec2=.FederationBankRelationshipDecision~new("DEC-SCOPE","CASE-X","E-SCOPE","CUST-A","FB-STAFF-AUTH","STAFF_TRANSACTION_AUTHORITY","AUTH:SCOPE","CUSTOMER_INSTRUCTION_VALIDATED","TRANSFER","POL:SCOPE","",now)~seal
el2=.FBRelationshipTestSupport~decisionElement("E-SCOPE","FB-STAFF-AUTH","AUTH:SCOPE","STAFF_TRANSACTION_AUTHORITY")
req2=.FederationBankRelationshipActionRequest~new("REQ-SCOPE","CMD-SCOPE","IDEM-SCOPE","CASE-X","CUST-B","TRANSFER","TELLER-1","TELLER",now,"A","B","USD",10)~seal
r2=adapter~translate(dec2,req2,el2)
.FBRelationshipTestSupport~assertFalse(r2~ok,"customer scope mismatch rejected")
.FBRelationshipTestSupport~assertEq("CUSTOMER_SCOPE_MISMATCH",r2~code,"scope guard")
.FBRelationshipTestSupport~pass("decision temporal and customer scopes enforced")
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "TestSupport.cls"
