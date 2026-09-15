e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelServiceTestSupport~openAccounts(e)
.FBStaffChannelServiceTestSupport~seed(e,2000000)
ctx=.FBStaffChannelServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
now=.DateTime~new
caseId="CASE:FULL"; elemId="E:FULL"; authRef="AUTH:FULL"
decision=.FederationBankRelationshipDecision~new("DEC:FULL",caseId,elemId,"CUST-001","FB-COMPLIANCE","STAFF_TRANSACTION_AUTHORITY",authRef,"CUSTOMER_INSTRUCTION_VALIDATED","TRANSFER","POL:FULL","",now)~seal
element=.RelationshipCaseElement~new(elemId,"DECISION","CUSTOMER_INSTRUCTION_VALIDATED","AUTHORISES_BANK_ACTION","FB-COMPLIANCE",authRef,"STAFF_TRANSACTION_AUTHORITY",now,"RESTRICTED")~seal
rr=.FederationBankRelationshipActionRequest~new("RELREQ:FULL","CMD:FULL","IDEM:FULL",caseId,"CUST-001","TRANSFER","TELLER-04","TELLER",now,"GBP-SRC","GBP-DST","GBP",250000)~seal
adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(.FederationBankRelationshipPolicyFixtures~publishedCatalog))
tr=adapter~translate(decision,rr,element)
.FBStaffChannelServiceTestSupport~assertTrue(tr~ok,"relationship adapter")
br=.FederationBankRelationshipStaffChannelBridge~requestFromTranslation("REQ:FULL","WORK:FULL",tr~value,ctx)
.FBStaffChannelServiceTestSupport~assertTrue(br~ok,"channel bridge")
svc=.FBStaffChannelServiceTestSupport~service(e)
r=svc~handle(.FBStaffChannelServiceTestSupport~submitEnvelope("SUBMIT:FULL",br~value,.FBStaffChannelServiceTestSupport~contexts(ctx)))
.FBStaffChannelServiceTestSupport~assertTrue(r~ok,"service")
w=r~value
.FBStaffChannelServiceTestSupport~assertEq("COMPLETED",w~state,"completed")
.FBStaffChannelServiceTestSupport~assertEq(caseId,w~relationshipEvidence~caseId,"case evidence")
.FBStaffChannelServiceTestSupport~assertEq("DEC:FULL",w~boundCommand~details["relationshipDecisionId"],"relationship decision survives")
.FBStaffChannelServiceTestSupport~assertEq(w~staffEnvelope~envelopeId,w~boundCommand~details["staffAuthorityEnvelopeId"],"staff authority survives")
.FBStaffChannelServiceTestSupport~assertEq(1750000,e~ledger~balanceMinor("GBP-SRC"),"posted")
.FBStaffChannelServiceTestSupport~pass("Relationship Case authority -> Staff Channel Service -> Staff Authority Service -> Core Banking")
::requires "FederationBankRelationshipStaffChannelBridge.cls"
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "RelationshipCase.cls"
::requires "TestSupport.cls"
