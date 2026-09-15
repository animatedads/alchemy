e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelTestSupport~openAccounts(e,"SUP-02")
.FBStaffChannelTestSupport~seed(e,5000000)
sup=.FBStaffChannelTestSupport~context("SUP-02","SUPERVISOR","S-SUP")
mgr=.FBStaffChannelTestSupport~context("MGR-01","BRANCH_MANAGER","S-MGR")
contexts=.FBStaffChannelTestSupport~contexts(sup,mgr)
request=.FBStaffChannelTestSupport~directRequest("CORE-DENY","SUP-02","S-SUP",3000000)
orch=.FBStaffChannelTestSupport~orchestrator(e)
r=orch~begin(request,contexts)
.FBStaffChannelTestSupport~assertEq("APPROVAL_REQUIRED",r~value~state,"manager checker")
ap=.FederationBankStaffApproval~new("AP:MGR",r~value~action,"MGR-01","S-MGR","BRANCH_MANAGER","EVID:MGR")~seal
r=orch~resume(r~value,contexts,.array~of(ap))
.FBStaffChannelTestSupport~assertTrue(r~ok,"orchestration completed")
.FBStaffChannelTestSupport~assertEq("CORE_REJECTED",r~value~state,"Core Banking remains final")
.FBStaffChannelTestSupport~assertEq("CORPORATE_POLICY_DENIED",r~value~coreCode,"customer/product policy denial retained")
.FBStaffChannelTestSupport~assertEq(5000000,e~ledger~balanceMinor("GBP-SRC"),"no money moved")
.FBStaffChannelTestSupport~pass("Staff Channel cannot turn staff authority into Core Banking authority")
::requires "TestSupport.cls"
