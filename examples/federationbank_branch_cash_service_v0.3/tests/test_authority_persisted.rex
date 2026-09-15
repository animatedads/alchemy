call load
root="/tmp/fbbranchcash-auth-state-"||time("S")||"-"||random(100000,999999); store=.FederationBankBranchCashServiceStore~new(root)
ports=.FBBranchCashServiceTestSupport~ports; till=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-1","IOM-DOUGLAS","GBP",10000); ports["TILL:TILL-1"]=till
s1=.FBBranchCashServiceTestSupport~service(ports,store); v=.FBBranchCashServiceTestSupport~openVault; ignore=s1~addVault(v)
t=.FBBranchCashServiceTestSupport~transfer("TX-AUTHP","VAULT","VAULT-1","TILL","TILL-1",25000); r=s1~submit("CMD-AUTHP","CORR-AUTHP",t,.FBBranchCashServiceTestSupport~approval(t)); .FBBranchCashServiceTestSupport~assertTrue(r~ok)
a=r~value~authority; .FBBranchCashServiceTestSupport~assertTrue(a~isA(.FederationBankBranchCashAuthorityEnvelope)); .FBBranchCashServiceTestSupport~assertTrue(a~matchesTransfer(t))
store2=.FederationBankBranchCashServiceStore~new(root); s2=.FBBranchCashServiceTestSupport~service(ports,store2); a2=s2~work("TX-AUTHP")~authority
.FBBranchCashServiceTestSupport~assertTrue(a2~isA(.FederationBankBranchCashAuthorityEnvelope)); .FBBranchCashServiceTestSupport~assertEq(a~semanticIdentity,a2~semanticIdentity); .FBBranchCashServiceTestSupport~assertTrue(a2~matchesTransfer(s2~work("TX-AUTHP")~transfer))
say "PASS: exact Branch Cash authority survives durable service restart"
exit 0
load: return
::requires "FederationBankBranchCashServicePersistence.cls"
::requires "TestSupport.cls"
