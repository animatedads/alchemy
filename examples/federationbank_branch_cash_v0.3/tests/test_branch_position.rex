call load
s=.array~new; s~append(.FederationBankBranchCashEndpointSnapshot~new("VAULT","V1","B1","GBP",10000,10000,0)); s~append(.FederationBankBranchCashEndpointSnapshot~new("TILL","T1","B1","GBP",5000,4990,-10))
p=.FederationBankBranchCashPosition~new("B1","GBP",s,2000)
.FBBranchCashTestSupport~assertEq(p~expectedMinor,15000); .FBBranchCashTestSupport~assertEq(p~discrepancyMinor,-10); .FBBranchCashTestSupport~assertEq(p~totalCustodyMinor,17000)
say "PASS: branch position keeps endpoint cash and in-transit cash explicit"
exit 0
load: return
::requires "TestSupport.cls"
