d=.FederationBankBranchDay~new("DAY-1","IOM-DOUGLAS","2026-08-26"); es=.FBBranchDayTest~endpoints; ps=.FBBranchDayTest~positions; maker="MGR-A"; apr=.FederationBankBranchDayApproval~new("A",d~openActionIdentity(es,ps,maker),"MGR-B","AUTH:MGR-B")
r=d~open(es,ps,maker,apr,.FederationBankBranchDayFixturePolicy~new)
.FBBranchDayTest~assertTrue(r~ok); .FBBranchDayTest~assertEq("OPEN",d~state)
say "PASS: balanced physical branch evidence can open the business day under dual approval"
::requires "TestSupport.cls"
