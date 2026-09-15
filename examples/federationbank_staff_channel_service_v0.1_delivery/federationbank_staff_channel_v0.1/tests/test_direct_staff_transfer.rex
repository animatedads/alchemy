e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelTestSupport~openAccounts(e)
.FBStaffChannelTestSupport~seed(e,2000000)
ctx=.FBStaffChannelTestSupport~context("TELLER-04","TELLER","S-TEL")
request=.FBStaffChannelTestSupport~directRequest("DIRECT")
r=.FBStaffChannelTestSupport~orchestrator(e)~begin(request,.FBStaffChannelTestSupport~contexts(ctx))
.FBStaffChannelTestSupport~assertTrue(r~ok,"orchestration result")
w=r~value
.FBStaffChannelTestSupport~assertEq("COMPLETED",w~state,"completed")
.FBStaffChannelTestSupport~assertEq("PAYMENTS",w~route,"payments route")
.FBStaffChannelTestSupport~assertEq(1750000,e~ledger~balanceMinor("GBP-SRC"),"source")
.FBStaffChannelTestSupport~assertEq(250000,e~ledger~balanceMinor("GBP-DST"),"target")
.FBStaffChannelTestSupport~pass("direct customer instruction -> staff authority -> Core Banking")
::requires "TestSupport.cls"
