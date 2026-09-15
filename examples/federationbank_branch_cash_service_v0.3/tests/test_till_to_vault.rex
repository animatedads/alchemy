call load
ports=.FBBranchCashServiceTestSupport~ports; till=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-1","IOM-DOUGLAS","GBP",50000); ports["TILL:TILL-1"]=till
s=.FBBranchCashServiceTestSupport~service(ports); v=.FBBranchCashServiceTestSupport~openVault("VAULT-1",100000); ignore=s~addVault(v)
t=.FBBranchCashServiceTestSupport~transfer("TX-TV","TILL","TILL-1","VAULT","VAULT-1",20000,"STAFF-A","TILL_SKIM"); r=s~submit("CMD-TV","CORR-TV",t,.FBBranchCashServiceTestSupport~approval(t))
.FBBranchCashServiceTestSupport~assertTrue(r~ok); .FBBranchCashServiceTestSupport~assertEq(till~expectedMinor,30000); .FBBranchCashServiceTestSupport~assertEq(v~expectedMinor,120000)
say "PASS: till skim enters branch vault as internal physical cash movement"
exit 0
load: return
::requires "TestSupport.cls"
