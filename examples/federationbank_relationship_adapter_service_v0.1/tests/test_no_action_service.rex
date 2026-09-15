fx=.FBRelationshipServiceTestSupport~transaction("NO1","NONE","CUST-ALAN")
port=.FakeRelationshipBankPort~new
svc=.FederationBankRelationshipAdapterService~new(.FBRelationshipServiceTestSupport~fixture,port)
r=svc~handle(.FederationBankRelationshipServiceEnvelope~new("NO-CMD-1","FBREL.ACTION.SUBMIT","CMP-1","COMPLIANCE",fx))
.FBRelationshipServiceTestSupport~assertTrue(r~ok,"no action")
.FBRelationshipServiceTestSupport~assertEq("NO_BANK_ACTION",r~value~status,"state")
.FBRelationshipServiceTestSupport~assertEq(0,port~commands~items,"nothing submitted to bank")
.FBRelationshipServiceTestSupport~assertEq("FBREL.ACTION.NO_BANK_ACTION",svc~eventSink~events[1]~eventType,"event")
.FBRelationshipServiceTestSupport~pass("no-action decision is service-visible without Core command")
::requires "FakeBankPort.cls"
::requires "TestSupport.cls"
