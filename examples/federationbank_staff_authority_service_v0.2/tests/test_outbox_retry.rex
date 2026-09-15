sink=.FederationBankStaffMemoryEventSink~new; sink~failNext
svc=.FBStaffServiceTestSupport~service(.nil,sink)
ctx=.FBStaffServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
r=.FBStaffServiceTestSupport~putContext(svc,"CTX-OUT",ctx)
.FBStaffServiceTestSupport~assertTrue(r~ok,"mutation committed")
.FBStaffServiceTestSupport~assertEq(1,svc~state~outbox~items,"event retained after sink failure")
r=svc~flushOutbox
.FBStaffServiceTestSupport~assertTrue(r~ok,"retry succeeds")
.FBStaffServiceTestSupport~assertEq(0,svc~state~outbox~items,"outbox cleared")
.FBStaffServiceTestSupport~pass("staff authority outbox is at-least-once")
::requires "TestSupport.cls"
