root="/tmp/fbrel-service-"||time("S")||"-"||random(100000,999999)
store=.FederationBankRelationshipServiceStore~new(root)
fx=.FBRelationshipServiceTestSupport~transaction("PERSIST")
port=.FakeRelationshipBankPort~new; svc=.FederationBankRelationshipAdapterService~new(.FBRelationshipServiceTestSupport~fixture,port,store)
r=svc~handle(.FederationBankRelationshipServiceEnvelope~new("PERSIST-CMD","FBREL.ACTION.SUBMIT","TEL-1","TELLER",fx))
.FBRelationshipServiceTestSupport~assertTrue(r~ok,"first submit")
svc2=.FederationBankRelationshipAdapterService~new(.FBRelationshipServiceTestSupport~fixture,.FakeRelationshipBankPort~new,store)
a=svc2~state~action("ACTION-PERSIST")
.FBRelationshipServiceTestSupport~assertTrue(a<>.nil,"action recovered")
.FBRelationshipServiceTestSupport~assertEq("SUBMITTED",a~status,"state recovered")
r2=svc2~handle(.FederationBankRelationshipServiceEnvelope~new("PERSIST-CMD","FBREL.ACTION.SUBMIT","TEL-1","TELLER",fx))
.FBRelationshipServiceTestSupport~assertEq("IDEMPOTENT_REPLAY",r2~code,"receipt recovered")
.FBRelationshipServiceTestSupport~pass("durable state/idempotency recover across service restart")
::requires "FederationBankRelationshipServicePersistence.cls"
::requires "FakeBankPort.cls"
::requires "TestSupport.cls"
