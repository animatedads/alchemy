call load
ports=.FBBranchCashServiceTestSupport~ports; a=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-A","IOM-DOUGLAS","GBP",50000); b=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-B","IOM-DOUGLAS","GBP",10000); ports["TILL:TILL-A"]=a; ports["TILL:TILL-B"]=b
s=.FBBranchCashServiceTestSupport~service(ports); t=.FBBranchCashServiceTestSupport~transfer("TX-TT","TILL","TILL-A","TILL","TILL-B",15000,"STAFF-A","TILL_TO_TILL"); r=s~submit("CMD-TT","CORR-TT",t,.FBBranchCashServiceTestSupport~approval(t))
.FBBranchCashServiceTestSupport~assertTrue(r~ok); .FBBranchCashServiceTestSupport~assertEq(a~expectedMinor,35000); .FBBranchCashServiceTestSupport~assertEq(b~expectedMinor,25000)
say "PASS: till-to-till movement is explicit internal custody transfer"
exit 0
load: return
::requires "TestSupport.cls"
