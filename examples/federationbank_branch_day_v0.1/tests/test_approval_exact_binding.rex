d=.FederationBankBranchDay~new("DAY-4","IOM-DOUGLAS","2026-08-26"); es=.FBBranchDayTest~endpoints; ps=.FBBranchDayTest~positions; maker="MGR-A"; wrong=.FederationBankBranchDayApproval~new("A","SOME-OTHER-DAY-ACTION","MGR-B","AUTH:MGR-B")
r=d~open(es,ps,maker,wrong,.FederationBankBranchDayFixturePolicy~new)
.FBBranchDayTest~assertTrue(\r~ok); .FBBranchDayTest~assertEq("APPROVAL_ACTION_MISMATCH",r~code)
say "PASS: branch open/close approval binds to the exact evidence set"
::requires "TestSupport.cls"
