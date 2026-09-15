e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelServiceTestSupport~openAccounts(e)
.FBStaffChannelServiceTestSupport~seed(e,2000000)
ctx=.FBStaffChannelServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
req=.FBStaffChannelServiceTestSupport~request("S1")
svc=.FBStaffChannelServiceTestSupport~service(e)
r=svc~handle(.FBStaffChannelServiceTestSupport~submitEnvelope("SUBMIT:S1",req,.FBStaffChannelServiceTestSupport~contexts(ctx)))
.FBStaffChannelServiceTestSupport~assertTrue(r~ok,"service submit")
.FBStaffChannelServiceTestSupport~assertEq("COMPLETED",r~value~state,"completed")
.FBStaffChannelServiceTestSupport~assertEq(1750000,e~ledger~balanceMinor("GBP-SRC"),"source")
.FBStaffChannelServiceTestSupport~assertEq(250000,e~ledger~balanceMinor("GBP-DST"),"target")
.FBStaffChannelServiceTestSupport~assertTrue(r~value~staffEnvelope<>.nil,"Staff Authority Service evidence retained")
.FBStaffChannelServiceTestSupport~pass("Staff Channel Service delegates staff authority and submits Core command")
::requires "TestSupport.cls"
