e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelServiceTestSupport~openAccounts(e)
.FBStaffChannelServiceTestSupport~seed(e,2000000)
ctx=.FBStaffChannelServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
req=.FBStaffChannelServiceTestSupport~request("IDEMP")
svc=.FBStaffChannelServiceTestSupport~service(e)
env=.FBStaffChannelServiceTestSupport~submitEnvelope("SUBMIT:IDEMP",req,.FBStaffChannelServiceTestSupport~contexts(ctx))
r1=svc~handle(env); .FBStaffChannelServiceTestSupport~assertTrue(r1~ok,"first")
bal=e~ledger~balanceMinor("GBP-SRC")
r2=svc~handle(env); .FBStaffChannelServiceTestSupport~assertTrue(r2~ok,"replay")
.FBStaffChannelServiceTestSupport~assertEq("IDEMPOTENT_REPLAY",r2~code,"service receipt")
.FBStaffChannelServiceTestSupport~assertEq(bal,e~ledger~balanceMinor("GBP-SRC"),"no second posting")
.FBStaffChannelServiceTestSupport~pass("Staff Channel service command idempotency")
::requires "TestSupport.cls"
