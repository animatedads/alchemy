fx=.FBRelationshipServiceTestSupport~transaction("TX1")
port=.FakeRelationshipBankPort~new
svc=.FederationBankRelationshipAdapterService~new(.FBRelationshipServiceTestSupport~fixture,port)
env=.FederationBankRelationshipServiceEnvelope~new("SVC-CMD-1","FBREL.ACTION.SUBMIT","TEL-1","TELLER",fx)
r=svc~handle(env)
.FBRelationshipServiceTestSupport~assertTrue(r~ok,"submit")
.FBRelationshipServiceTestSupport~assertEq("SUBMITTED",r~value~status,"submitted state")
.FBRelationshipServiceTestSupport~assertEq(1,port~commands~items,"one bank command")
.FBRelationshipServiceTestSupport~assertEq("STAFF",port~commands[1]~channel,"honest staff channel")
p=.directory~new; p["bankCommandId"]="BANKCMD-TX1"; p["ok"]=.false; p["code"]="CORPORATE_POLICY_DENIED"; p["detail"]="Core Banking declined"
r2=svc~handle(.FederationBankRelationshipServiceEnvelope~new("SVC-RES-1","FBREL.ACTION.RESULT.RECORD","fb-result-router","SYSTEM",p))
.FBRelationshipServiceTestSupport~assertTrue(r2~ok,"result recorded")
.FBRelationshipServiceTestSupport~assertEq("BANK_REJECTED",r2~value~status,"Core rejection preserved")
.FBRelationshipServiceTestSupport~assertEq("CORPORATE_POLICY_DENIED",r2~value~bankResultCode,"result code")
.FBRelationshipServiceTestSupport~pass("submission/result correlation retains Core Banking authority")
::requires "FakeBankPort.cls"
::requires "TestSupport.cls"
