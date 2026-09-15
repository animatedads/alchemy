catalog=.FederationBankRelationshipPolicyFixtures~publishedCatalog
adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(catalog))
signal=.RelationshipCaseElement~new("E-SIGNAL","EXTERNAL_SIGNAL","POLITICAL_TRADE_PRESSURE","TRIGGERS_REVIEW","REPUTATION_FEED","HYPOTHESIS:991","OBSERVATION_NOT_DECISION",.nil,"RESTRICTED")~seal
req=.FederationBankRelationshipActionRequest~new("REQ-2","CMD-2","IDEM-2","CASE-104","CUST-ALAN","TRANSFER","TELLER-7","TELLER",.nil,"A1","A2","GBP",1000)~seal
r=adapter~translate(signal,req,signal)
.FBRelationshipTestSupport~assertFalse(r~ok,"external signal rejected")
.FBRelationshipTestSupport~assertEq("BANK_ACTION_DECISION_REQUIRED",r~code,"observation is not decision")
.FBRelationshipTestSupport~pass("external political/reputation signal cannot become a bank command")
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "TestSupport.cls"
