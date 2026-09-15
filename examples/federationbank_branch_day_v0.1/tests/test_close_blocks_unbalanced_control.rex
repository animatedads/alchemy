d=.FBBranchDayTest~openDay(100000); ignore=.FBBranchDayTest~beginClose(d)
es=.FBBranchDayTest~endpoints("CLOSED",85000,20000); ps=.FBBranchDayTest~positions(105000); t=.FederationBankBranchDayControlTotals~new("GBP",100000,10000,4000,0,0,0,"",105000,"CTRL"); ts=.array~of(t); apr=.FBBranchDayTest~closeApproval(d,es,ps,ts)
r=d~close(es,ps,ts,"BRANCH-MGR-A",apr,.FederationBankBranchDayFixturePolicy~new)
.FBBranchDayTest~assertTrue(\r~ok); .FBBranchDayTest~assertEq("CASH_CONTROL_TOTALS_UNBALANCED",r~code); .FBBranchDayTest~assertEq("CLOSING",d~state)
say "PASS: a superficially balanced drawer cannot close a day when cash control totals do not explain it"
::requires "TestSupport.cls"
