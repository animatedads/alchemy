d=.FederationBankBranchDay~new("DAY-3","IOM-DOUGLAS","2026-08-26"); es=.array~of(.FBBranchDayTest~endpoint("E-V","VAULT","VAULT-1","OPEN",80000,79900,-100),.FBBranchDayTest~endpoint("E-T","TILL","TILL-04","OPEN",20000)); ps=.FBBranchDayTest~positions(99900); maker="MGR-A"; apr=.FederationBankBranchDayApproval~new("A",d~openActionIdentity(es,ps,maker),"MGR-B","AUTH:MGR-B")
r=d~open(es,ps,maker,apr,.FederationBankBranchDayFixturePolicy~new)
.FBBranchDayTest~assertTrue(\r~ok); .FBBranchDayTest~assertEq("ENDPOINT_DISCREPANCY",r~code)
say "PASS: branch opening cannot hide a vault/till physical discrepancy"
::requires "TestSupport.cls"
