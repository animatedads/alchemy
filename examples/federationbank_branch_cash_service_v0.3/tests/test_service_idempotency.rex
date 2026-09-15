call load
ports=.FBBranchCashServiceTestSupport~ports; a=.FederationBankBranchCashMemoryEndpoint~new("TILL","A","IOM-DOUGLAS","GBP",50000); b=.FederationBankBranchCashMemoryEndpoint~new("TILL","B","IOM-DOUGLAS","GBP",10000); ports["TILL:A"]=a; ports["TILL:B"]=b
s=.FBBranchCashServiceTestSupport~service(ports); t=.FBBranchCashServiceTestSupport~transfer("TX-IDEM","TILL","A","TILL","B",10000); ap=.FBBranchCashServiceTestSupport~approval(t)
r1=s~submit("CMD-IDEM","CORR-IDEM",t,ap); r2=s~submit("CMD-IDEM","CORR-IDEM",t,ap)
.FBBranchCashServiceTestSupport~assertTrue(r1~ok & r2~ok); .FBBranchCashServiceTestSupport~assertEq(a~releaseCount,1); .FBBranchCashServiceTestSupport~assertEq(b~acceptCount,1); .FBBranchCashServiceTestSupport~assertEq(a~expectedMinor,40000); .FBBranchCashServiceTestSupport~assertEq(b~expectedMinor,20000)
say "PASS: semantic command replay cannot duplicate physical cash movement"
exit 0
load: return
::requires "TestSupport.cls"
