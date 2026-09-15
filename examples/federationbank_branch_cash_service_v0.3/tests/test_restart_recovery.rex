call load
root="/tmp/fbbranchcash-state-"||time("S")||"-"||random(100000,999999); store=.FederationBankBranchCashServiceStore~new(root)
ports=.FBBranchCashServiceTestSupport~ports; till=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-1","IOM-DOUGLAS","GBP",10000); till~failNextAccept; ports["TILL:TILL-1"]=till
s1=.FBBranchCashServiceTestSupport~service(ports,store); v=.FBBranchCashServiceTestSupport~openVault; ignore=s1~addVault(v); t=.FBBranchCashServiceTestSupport~transfer("TX-RST","VAULT","VAULT-1","TILL","TILL-1",25000); ignore=s1~submit("CMD-RST","CORR-RST",t,.FBBranchCashServiceTestSupport~approval(t))
/* New service boundary; durable state must retain the in-transit custody. */
store2=.FederationBankBranchCashServiceStore~new(root); s2=.FBBranchCashServiceTestSupport~service(ports,store2)
.FBBranchCashServiceTestSupport~assertEq(s2~work("TX-RST")~state,"RECONCILIATION_REQUIRED"); .FBBranchCashServiceTestSupport~assertEq(s2~state~vault("VAULT-1")~expectedMinor,75000); .FBBranchCashServiceTestSupport~assertEq(s2~inTransitMinor("IOM-DOUGLAS","GBP"),25000)
r=s2~resolve("TX-RST","RETRY_DESTINATION"); .FBBranchCashServiceTestSupport~assertTrue(r~ok); .FBBranchCashServiceTestSupport~assertEq(till~expectedMinor,35000)
say "PASS: durable restart preserves vault state and in-transit reconciliation"
exit 0
load: return
::requires "FederationBankBranchCashServicePersistence.cls"
::requires "TestSupport.cls"
