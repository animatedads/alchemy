s=.FBBranchDayServiceTest~service; d=.FBBranchDayServiceTest~create(s,"DAY-FAIL"); .FBBranchDayServiceTest~assertTrue(.FBBranchDayServiceTest~open(s,d)~ok); .FBBranchDayServiceTest~assertTrue(.FBBranchDayServiceTest~beginClose(s,d)~ok)
es=.FBBranchDayServiceTest~endpoints("CLOSED",85000,20000); ps=.FBBranchDayServiceTest~positions(105000,1000,0); ts=.FBBranchDayServiceTest~totals(100000,10000,5000,105000); maker="MGR-A"; apr=.FederationBankBranchDayApproval~new("APR-X",d~closeActionIdentity(es,ps,ts,maker),"MGR-B","AUTH:MGR-B"); r=s~closeDay("CMD-BAD-CLOSE","CORR",d~dayId,es,ps,ts,maker,apr)
.FBBranchDayServiceTest~assertTrue(\r~ok); .FBBranchDayServiceTest~assertEq(r~code,"CASH_IN_TRANSIT"); .FBBranchDayServiceTest~assertEq(d~state,"CLOSING")
say "PASS: failed end-of-day certification leaves the day explicitly CLOSING"
::requires "TestSupport.cls"
