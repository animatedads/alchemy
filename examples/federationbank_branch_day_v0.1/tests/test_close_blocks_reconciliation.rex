d=.FBBranchDayTest~openDay(100000); ignore=.FBBranchDayTest~beginClose(d)
es=.FBBranchDayTest~endpoints("CLOSED",80000,20000); ps=.FBBranchDayTest~positions(100000,0,1); ts=.array~of(.FBBranchDayTest~totals(100000,0,0,0,0,0,"",100000)); apr=.FBBranchDayTest~closeApproval(d,es,ps,ts)
r=d~close(es,ps,ts,"BRANCH-MGR-A",apr,.FederationBankBranchDayFixturePolicy~new)
.FBBranchDayTest~assertTrue(\r~ok); .FBBranchDayTest~assertEq("OUTSTANDING_RECONCILIATION",r~code)
say "PASS: end-of-day refuses to close around unresolved physical-cash work"
::requires "TestSupport.cls"
