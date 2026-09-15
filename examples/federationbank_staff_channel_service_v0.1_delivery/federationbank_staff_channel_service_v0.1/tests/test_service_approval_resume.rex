e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelServiceTestSupport~openAccounts(e)
.FBStaffChannelServiceTestSupport~seed(e,3000000)
teller=.FBStaffChannelServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
sup=.FBStaffChannelServiceTestSupport~context("SUP-01","SUPERVISOR","S-SUP")
contexts=.FBStaffChannelServiceTestSupport~contexts(teller,sup)
req=.FBStaffChannelServiceTestSupport~request("S2","TELLER-04","S-TEL",1000000)
svc=.FBStaffChannelServiceTestSupport~service(e)
r=svc~handle(.FBStaffChannelServiceTestSupport~submitEnvelope("SUBMIT:S2",req,contexts))
.FBStaffChannelServiceTestSupport~assertTrue(r~ok,"submit")
w=r~value
.FBStaffChannelServiceTestSupport~assertEq("APPROVAL_REQUIRED",w~state,"maker/checker durable work")
.FBStaffChannelServiceTestSupport~assertEq(3000000,e~ledger~balanceMinor("GBP-SRC"),"no posting yet")
ap=.FederationBankStaffApproval~new("AP:S2",w~action,"SUP-01","S-SUP","SUPERVISOR","EVID:S2")~seal
r=svc~handle(.FBStaffChannelServiceTestSupport~resumeEnvelope("RESUME:S2",w~workId,contexts,.array~of(ap)))
.FBStaffChannelServiceTestSupport~assertTrue(r~ok,"resume")
.FBStaffChannelServiceTestSupport~assertEq("COMPLETED",r~value~state,"completed")
.FBStaffChannelServiceTestSupport~assertEq(2000000,e~ledger~balanceMinor("GBP-SRC"),"source")
.FBStaffChannelServiceTestSupport~pass("maker/checker resumes through Staff Authority Service")
::requires "TestSupport.cls"
