e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelTestSupport~openAccounts(e)
.FBStaffChannelTestSupport~seed(e,3000000)
teller=.FBStaffChannelTestSupport~context("TELLER-04","TELLER","S-TEL")
supervisor=.FBStaffChannelTestSupport~context("SUP-01","SUPERVISOR","S-SUP")
contexts=.FBStaffChannelTestSupport~contexts(teller,supervisor)
request=.FBStaffChannelTestSupport~directRequest("CHECKER","TELLER-04","S-TEL",1000000)
orch=.FBStaffChannelTestSupport~orchestrator(e)
r=orch~begin(request,contexts)
.FBStaffChannelTestSupport~assertTrue(r~ok,"begin")
w=r~value
.FBStaffChannelTestSupport~assertEq("APPROVAL_REQUIRED",w~state,"checker workflow")
.FBStaffChannelTestSupport~assertEq(3000000,e~ledger~balanceMinor("GBP-SRC"),"nothing posted before checker")
ap=.FederationBankStaffApproval~new("AP:CHECKER",w~action,"SUP-01","S-SUP","SUPERVISOR","EVID:AP")~seal
r=orch~resume(w,contexts,.array~of(ap))
.FBStaffChannelTestSupport~assertTrue(r~ok,"resume")
.FBStaffChannelTestSupport~assertEq("COMPLETED",r~value~state,"completed after checker")
.FBStaffChannelTestSupport~assertEq(2000000,e~ledger~balanceMinor("GBP-SRC"),"source")
.FBStaffChannelTestSupport~assertEq(1000000,e~ledger~balanceMinor("GBP-DST"),"target")
.FBStaffChannelTestSupport~pass("maker/checker is resumable coordination, not UI state")
::requires "TestSupport.cls"
