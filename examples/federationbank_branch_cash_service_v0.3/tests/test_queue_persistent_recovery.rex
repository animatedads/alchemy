call load
root="/tmp/fbbranchcash-queue-"||time("S")||"-"||random(100000,999999); codec=.FederationBankBranchCashServicePersistenceSupport~newCodec; manager=.ObjectQueueManager~new(root,codec,"queue-admin")
ports=.FBBranchCashServiceTestSupport~ports; till=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-1","IOM-DOUGLAS","GBP",10000); ports["TILL:TILL-1"]=till; s=.FBBranchCashServiceTestSupport~service(ports); ignore=s~addVault(.FBBranchCashServiceTestSupport~openVault)
worker=.FederationBankBranchCashQueueWorker~new(s,manager,"FB.BRANCH.CASH.CMD","FB.BRANCH.CASH.EVT","fb-branch-cash-service","queue-admin","PERMANENT"); .FBBranchCashServiceTestSupport~assertTrue(worker~install~ok)
ignore=manager~grant("FB.BRANCH.CASH.CMD","client",.QueueAccess~PUT,"queue-admin")
t=.FBBranchCashServiceTestSupport~transfer("TX-Q","VAULT","VAULT-1","TILL","TILL-1",10000); env=.FBBranchCashServiceTestSupport~envelope("Q",t,.FBBranchCashServiceTestSupport~approval(t)); o=.table~new; o["persistent"]=.true; .FBBranchCashServiceTestSupport~assertTrue(manager~put("FB.BRANCH.CASH.CMD",env,o,"client")~ok)
/* Destroy/recreate queue manager and service before consume. */
codec2=.FederationBankBranchCashServicePersistenceSupport~newCodec; manager2=.ObjectQueueManager~new(root,codec2,"queue-admin"); ports2=.FBBranchCashServiceTestSupport~ports; till2=.FederationBankBranchCashMemoryEndpoint~new("TILL","TILL-1","IOM-DOUGLAS","GBP",10000); ports2["TILL:TILL-1"]=till2; s2=.FBBranchCashServiceTestSupport~service(ports2); ignore=s2~addVault(.FBBranchCashServiceTestSupport~openVault)
worker2=.FederationBankBranchCashQueueWorker~new(s2,manager2,"FB.BRANCH.CASH.CMD","FB.BRANCH.CASH.EVT","fb-branch-cash-service","queue-admin","PERMANENT"); .FBBranchCashServiceTestSupport~assertTrue(worker2~install~ok); r=worker2~processOne
.FBBranchCashServiceTestSupport~assertTrue(r~ok); .FBBranchCashServiceTestSupport~assertTrue(r~value~ok); .FBBranchCashServiceTestSupport~assertEq(r~value~value~state,"COMPLETED"); .FBBranchCashServiceTestSupport~assertEq(till2~expectedMinor,20000)
say "PASS: permanent Queue Fabric recovers typed Branch Cash transfer command graph"
exit 0
load: return
::requires "FederationBankBranchCashServiceQueue.cls"
::requires "TestSupport.cls"
