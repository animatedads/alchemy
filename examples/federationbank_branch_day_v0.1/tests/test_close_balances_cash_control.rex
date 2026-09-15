d=.FBBranchDayTest~openDay(100000); ignore=.FBBranchDayTest~beginClose(d)
closing=105000; es=.FBBranchDayTest~endpoints("CLOSED",85000,20000); ps=.FBBranchDayTest~positions(closing); ts=.array~of(.FBBranchDayTest~totals(100000,10000,5000,0,0,0,"",closing)); apr=.FBBranchDayTest~closeApproval(d,es,ps,ts)
r=d~close(es,ps,ts,"BRANCH-MGR-A",apr,.FederationBankBranchDayFixturePolicy~new)
.FBBranchDayTest~assertTrue(r~ok,"close failed "||r~code); .FBBranchDayTest~assertEq("CLOSED",d~state)
say "PASS: end-of-day closes only when physical custody matches authoritative cash control totals"
::requires "TestSupport.cls"
