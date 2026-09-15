ports=.FBBranchCashServiceTestSupport~ports; a=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-A","IOM-DOUGLAS","GBP",50000); b=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-B","IOM-DOUGLAS","GBP",10000); ports["TILL:TILL-A"]=a; ports["TILL:TILL-B"]=b
s=.FBBranchCashServiceTestSupport~service(ports); t=.FBBranchCashServiceTestSupport~transfer("TX-DENY","TILL","TILL-A","TILL","TILL-B",10000,"STAFF-A"); bad=.FederationBankBranchCashApproval~new("APR-BAD",t~semanticIdentity,"STAFF-A","STAFF-AUTH:STAFF-A")
r=s~submit("CMD-DENY","CORR-DENY",t,bad)
.FBBranchCashServiceTestSupport~assertTrue(\r~ok); .FBBranchCashServiceTestSupport~assertEq(r~code,"SEPARATION_OF_DUTIES"); .FBBranchCashServiceTestSupport~assertEq(a~expectedMinor,50000); .FBBranchCashServiceTestSupport~assertEq(b~expectedMinor,10000)
say "PASS: non-vault route cannot bypass Branch Cash authority policy and checker separation"
::requires "TestSupport.cls"
