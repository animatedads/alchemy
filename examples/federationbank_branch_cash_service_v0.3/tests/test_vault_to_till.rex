call load
ports=.FBBranchCashServiceTestSupport~ports; till=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-1","IOM-DOUGLAS","GBP",10000); ports["TILL:TILL-1"]=till
s=.FBBranchCashServiceTestSupport~service(ports); v=.FBBranchCashServiceTestSupport~openVault; .FBBranchCashServiceTestSupport~assertTrue(s~addVault(v)~ok)
t=.FBBranchCashServiceTestSupport~transfer("TX-VT","VAULT","VAULT-1","TILL","TILL-1",25000); r=s~submit("CMD-VT","CORR-VT",t,.FBBranchCashServiceTestSupport~approval(t))
.FBBranchCashServiceTestSupport~assertTrue(r~ok,"vault to till")
.FBBranchCashServiceTestSupport~assertEq(v~expectedMinor,75000); .FBBranchCashServiceTestSupport~assertEq(till~expectedMinor,35000); .FBBranchCashServiceTestSupport~assertEq(r~value~state,"COMPLETED")
say "PASS: vault replenishment moves physical custody without customer transaction semantics"
exit 0
load: return
::requires "TestSupport.cls"
