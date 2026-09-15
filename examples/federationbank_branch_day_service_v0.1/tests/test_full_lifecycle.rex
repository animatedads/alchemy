s=.FBBranchDayServiceTest~service; d=.FBBranchDayServiceTest~create(s); r=.FBBranchDayServiceTest~open(s,d); .FBBranchDayServiceTest~assertTrue(r~ok); r=.FBBranchDayServiceTest~beginClose(s,d); .FBBranchDayServiceTest~assertTrue(r~ok); r=.FBBranchDayServiceTest~close(s,d); .FBBranchDayServiceTest~assertTrue(r~ok); .FBBranchDayServiceTest~assertEq(d~state,"CLOSED")
say "PASS: Branch Day service durably models create/open/closing/closed lifecycle"
::requires "TestSupport.cls"
