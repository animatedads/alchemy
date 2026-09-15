call load
ports=.FBBranchCashServiceTestSupport~ports; till=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-1","IOM-DOUGLAS","GBP",10000); till~failNextAccept; ports["TILL:TILL-1"]=till
s=.FBBranchCashServiceTestSupport~service(ports); v=.FBBranchCashServiceTestSupport~openVault; ignore=s~addVault(v); t=.FBBranchCashServiceTestSupport~transfer("TX-FAIL","VAULT","VAULT-1","TILL","TILL-1",25000)
r=s~submit("CMD-FAIL","CORR-FAIL",t,.FBBranchCashServiceTestSupport~approval(t)); .FBBranchCashServiceTestSupport~assertEq(r~code,"RECONCILIATION_REQUIRED")
.FBBranchCashServiceTestSupport~assertEq(v~expectedMinor,75000); .FBBranchCashServiceTestSupport~assertEq(till~expectedMinor,10000); .FBBranchCashServiceTestSupport~assertEq(s~inTransitMinor("IOM-DOUGLAS","GBP"),25000)
.FBBranchCashServiceTestSupport~assertEq(s~work("TX-FAIL")~detail~pos("TRANSIT:TX-FAIL")>0,.true)
say "PASS: failed destination leaves cash in explicit transit custody"
exit 0
load: return
::requires "TestSupport.cls"
