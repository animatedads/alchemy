e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelServiceTestSupport~openAccounts(e)
.FBStaffChannelServiceTestSupport~seed(e,2000000)
ctx=.FBStaffChannelServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
sink=.FederationBankStaffChannelMemoryEventSink~new; sink~failNext
svc=.FBStaffChannelServiceTestSupport~service(e,.nil,sink)
r=svc~handle(.FBStaffChannelServiceTestSupport~submitEnvelope("SUBMIT:OUT",.FBStaffChannelServiceTestSupport~request("OUT"),.FBStaffChannelServiceTestSupport~contexts(ctx)))
.FBStaffChannelServiceTestSupport~assertTrue(r~ok,"bank work committed despite event sink failure")
.FBStaffChannelServiceTestSupport~assertTrue(svc~state~outbox~items>0,"events retained")
r=svc~flushOutbox
.FBStaffChannelServiceTestSupport~assertTrue(r~ok,"retry")
.FBStaffChannelServiceTestSupport~assertEq(0,svc~state~outbox~items,"outbox cleared")
.FBStaffChannelServiceTestSupport~pass("Staff Channel event publication is at-least-once")
::requires "TestSupport.cls"
