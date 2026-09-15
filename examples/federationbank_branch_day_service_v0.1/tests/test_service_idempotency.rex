s=.FBBranchDayServiceTest~service; d=.FBBranchDayServiceTest~create(s,"DAY-IDEMP"); es=.FBBranchDayServiceTest~endpoints; ps=.FBBranchDayServiceTest~positions; maker="MGR-A"; apr=.FederationBankBranchDayApproval~new("APR",d~openActionIdentity(es,ps,maker),"MGR-B","AUTH:MGR-B")
r1=s~openDay("CMD-OPEN-IDEMP","CORR",d~dayId,es,ps,maker,apr); r2=s~openDay("CMD-OPEN-IDEMP","CORR",d~dayId,es,ps,maker,apr)
.FBBranchDayServiceTest~assertTrue(r1~ok); .FBBranchDayServiceTest~assertTrue(r2~ok); .FBBranchDayServiceTest~assertEq(d~state,"OPEN")
say "PASS: semantic command replay cannot open or close a branch day twice"
::requires "TestSupport.cls"
