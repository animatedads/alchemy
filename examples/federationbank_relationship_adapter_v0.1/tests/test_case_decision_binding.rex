now=.DateTime~new
dec=.FederationBankRelationshipDecision~new("DEC-TX-1","CASE-1","E-DEC-1","CUST-001","FB-STAFF-AUTH","STAFF_TRANSACTION_AUTHORITY","AUTH:PAY:1","CUSTOMER_INSTRUCTION_VALIDATED","TRANSFER","POL:PAY:1","",now)~seal
req=.FederationBankRelationshipActionRequest~new("REQ-TX-1","CMD-TX-1","IDEM-TX-1","CASE-1","CUST-001","TRANSFER","TELLER-4","TELLER",now,"SRC","DST","USD",250000)~seal
adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(.FederationBankRelationshipPolicyFixtures~publishedCatalog))
bad=.FBRelationshipTestSupport~decisionElement("E-DEC-1","FB-STAFF-AUTH","AUTH:DIFFERENT","STAFF_TRANSACTION_AUTHORITY")
r=adapter~translate(dec,req,bad)
.FBRelationshipTestSupport~assertFalse(r~ok,"mismatched case reference rejected")
.FBRelationshipTestSupport~assertEq("CASE_DECISION_REFERENCE_MISMATCH",r~code,"binding guard")
good=.FBRelationshipTestSupport~decisionElement("E-DEC-1","FB-STAFF-AUTH","AUTH:PAY:1","STAFF_TRANSACTION_AUTHORITY")
r2=adapter~translate(dec,req,good)
.FBRelationshipTestSupport~assertTrue(r2~ok,"matching case decision accepted")
cmd=r2~value~bankCommand
.FBRelationshipTestSupport~assertEq("STAFF",cmd~channel,"staff channel retained honestly")
.FBRelationshipTestSupport~assertEq("CASE-1",cmd~detail("relationshipCaseId"),"case provenance")
.FBRelationshipTestSupport~assertEq("AUTH:PAY:1",cmd~detail("relationshipAuthorityRef"),"decision provenance")
.FBRelationshipTestSupport~pass("case decision reference and authority are bound to bank command")
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "TestSupport.cls"
