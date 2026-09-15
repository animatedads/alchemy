call load
root="/tmp/fbbranchday-state-"||time("S")||"-"||random(100000,999999); store=.FederationBankBranchDayServiceStore~new(root); s1=.FBBranchDayServiceTest~service(store); d=.FBBranchDayServiceTest~create(s1,"DAY-RST"); .FBBranchDayServiceTest~assertTrue(.FBBranchDayServiceTest~open(s1,d)~ok); .FBBranchDayServiceTest~assertTrue(.FBBranchDayServiceTest~beginClose(s1,d)~ok)
s2=.FBBranchDayServiceTest~service(.FederationBankBranchDayServiceStore~new(root)); d2=s2~day("DAY-RST"); .FBBranchDayServiceTest~assertEq(d2~state,"CLOSING"); .FBBranchDayServiceTest~assertEq(d2~openingPositions[1]~expectedMinor,100000); r=.FBBranchDayServiceTest~close(s2,d2); .FBBranchDayServiceTest~assertTrue(r~ok); .FBBranchDayServiceTest~assertEq(d2~state,"CLOSED")
say "PASS: durable restart preserves branch-day evidence and resumes closing"
exit 0
load: return
::requires "FederationBankBranchDayServicePersistence.cls"
::requires "TestSupport.cls"
