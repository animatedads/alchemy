fx=.FBRelationshipServiceTestSupport~transaction("OUT")
port=.FakeRelationshipBankPort~new; sink=.FederationBankRelationshipMemoryEventSink~new; sink~failNext
svc=.FederationBankRelationshipAdapterService~new(.FBRelationshipServiceTestSupport~fixture,port,.nil,sink)
r=svc~handle(.FederationBankRelationshipServiceEnvelope~new("OUT-CMD","FBREL.ACTION.SUBMIT","TEL-1","TELLER",fx))
.FBRelationshipServiceTestSupport~assertTrue(r~ok,"mutation committed despite event sink")
.FBRelationshipServiceTestSupport~assertEq(1,svc~state~outbox~items,"event retained")
fr=svc~flushOutbox
.FBRelationshipServiceTestSupport~assertTrue(fr~ok,"retry")
.FBRelationshipServiceTestSupport~assertEq(0,svc~state~outbox~items,"outbox cleared")
.FBRelationshipServiceTestSupport~pass("outbox decouples relationship state from event delivery")
::requires "FakeBankPort.cls"
::requires "TestSupport.cls"
