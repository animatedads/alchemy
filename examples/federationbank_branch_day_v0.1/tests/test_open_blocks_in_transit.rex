d=.FederationBankBranchDay~new("DAY-2","IOM-DOUGLAS","2026-08-26"); es=.FBBranchDayTest~endpoints; ps=.FBBranchDayTest~positions(100000,5000,0); maker="MGR-A"; apr=.FederationBankBranchDayApproval~new("A",d~openActionIdentity(es,ps,maker),"MGR-B","AUTH:MGR-B")
r=d~open(es,ps,maker,apr,.FederationBankBranchDayFixturePolicy~new)
.FBBranchDayTest~assertTrue(\r~ok); .FBBranchDayTest~assertEq("CASH_IN_TRANSIT",r~code); .FBBranchDayTest~assertEq("CREATED",d~state)
say "PASS: branch day cannot open while physical cash remains in transit"
::requires "TestSupport.cls"
