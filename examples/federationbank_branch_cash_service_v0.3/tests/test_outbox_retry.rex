call load
ports=.FBBranchCashServiceTestSupport~ports; a=.FederationBankBranchCashMemoryEndpoint~new("TILL","A","IOM-DOUGLAS","GBP",50000); b=.FederationBankBranchCashMemoryEndpoint~new("TILL","B","IOM-DOUGLAS","GBP",10000); ports["TILL:A"]=a; ports["TILL:B"]=b; sink=.FederationBankBranchCashMemoryEventSink~new; sink~failNext
s=.FBBranchCashServiceTestSupport~service(ports,.nil,sink); t=.FBBranchCashServiceTestSupport~transfer("TX-EVT","TILL","A","TILL","B",10000); ignore=s~submit("CMD-EVT","CORR-EVT",t,.FBBranchCashServiceTestSupport~approval(t))
r=s~flushOutbox; .FBBranchCashServiceTestSupport~assertEq(r~code,"EVENT_DELIVERY_FAILED"); .FBBranchCashServiceTestSupport~assertTrue(s~state~outbox~items>0)
r=s~flushOutbox; .FBBranchCashServiceTestSupport~assertTrue(r~ok); .FBBranchCashServiceTestSupport~assertEq(s~state~outbox~items,0)
say "PASS: branch cash event delivery is at-least-once without rolling back custody"
exit 0
load: return
::requires "TestSupport.cls"
