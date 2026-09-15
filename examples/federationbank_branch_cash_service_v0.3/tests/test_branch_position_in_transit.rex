call load
ports=.FBBranchCashServiceTestSupport~ports; till=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-1","IOM-DOUGLAS","GBP",10000); till~failNextAccept; ports["TILL:TILL-1"]=till
s=.FBBranchCashServiceTestSupport~service(ports); ignore=s~addVault(.FBBranchCashServiceTestSupport~openVault("VAULT-1",100000)); t=.FBBranchCashServiceTestSupport~transfer("TX-POS","VAULT","VAULT-1","TILL","TILL-1",25000); ignore=s~submit("CMD-POS","CORR-POS",t,.FBBranchCashServiceTestSupport~approval(t)); p=s~branchPosition("IOM-DOUGLAS","GBP")
.FBBranchCashServiceTestSupport~assertEq(p~expectedMinor,85000); .FBBranchCashServiceTestSupport~assertEq(p~inTransitMinor,25000); .FBBranchCashServiceTestSupport~assertEq(p~totalCustodyMinor,110000)
say "PASS: branch cash position includes explicit in-transit custody"
exit 0
load: return
::requires "TestSupport.cls"
