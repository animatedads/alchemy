call load
ports=.FBBranchCashServiceTestSupport~ports; till=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-1","IOM-DOUGLAS","GBP",10000); till~failNextAccept; ports["TILL:TILL-1"]=till
s=.FBBranchCashServiceTestSupport~service(ports); v=.FBBranchCashServiceTestSupport~openVault; ignore=s~addVault(v); t=.FBBranchCashServiceTestSupport~transfer("TX-REC","VAULT","VAULT-1","TILL","TILL-1",25000)
ignore=s~submit("CMD-REC","CORR-REC",t,.FBBranchCashServiceTestSupport~approval(t)); r=s~resolve("TX-REC","RETRY_DESTINATION")
.FBBranchCashServiceTestSupport~assertTrue(r~ok); .FBBranchCashServiceTestSupport~assertEq(r~value~state,"COMPLETED"); .FBBranchCashServiceTestSupport~assertEq(s~inTransitMinor("IOM-DOUGLAS","GBP"),0); .FBBranchCashServiceTestSupport~assertEq(till~expectedMinor,35000)
say "PASS: reconciliation retry completes the same in-transit transfer"
exit 0
load: return
::requires "TestSupport.cls"
