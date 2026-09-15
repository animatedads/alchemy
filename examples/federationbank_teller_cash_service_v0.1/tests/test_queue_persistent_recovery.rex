e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
.FBTellerCashTestSupport~seedCustomer(e,"GBP-SRC",2000000)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
root="/tmp/fbtelcash-queue-"||time("S")||"-"||random(100000,999999)
codec=.FederationBankTellerCashServicePersistenceSupport~newCodec
manager=.ObjectQueueManager~new(root,codec,"queue-admin")
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
worker=.FederationBankTellerCashQueueWorker~new(svc,manager,"FB.TELCASH.CMD","FB.TELCASH.EVT","fb-teller-cash-service","queue-admin","PERMANENT")
.FBTellerCashTestSupport~assertTrue(worker~install~ok,"install permanent teller-cash queues")
ignore=manager~grant("FB.TELCASH.CMD","client",.QueueAccess~PUT,"queue-admin")
req=.FBTellerCashTestSupport~cashRequest("QUEUE","WITHDRAWAL",10000)
inst=.FBTellerCashTestSupport~instruction("QUEUE",req,"WITHDRAWAL",10000,"TILL-04",ctx)
env=.FBTellerCashTestSupport~envelope("QUEUE",req,inst,.FBTellerCashTestSupport~contexts(.FBTellerCashTestSupport~context))
o=.table~new; o["persistent"]=.true
.FBTellerCashTestSupport~assertTrue(manager~put("FB.TELCASH.CMD",env,o,"client")~ok,"typed teller cash command queued")
/* Destroy/recreate both queue manager and service boundary before consume. */
codec2=.FederationBankTellerCashServicePersistenceSupport~newCodec
manager2=.ObjectQueueManager~new(root,codec2,"queue-admin")
svc2=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
worker2=.FederationBankTellerCashQueueWorker~new(svc2,manager2,"FB.TELCASH.CMD","FB.TELCASH.EVT","fb-teller-cash-service","queue-admin","PERMANENT")
.FBTellerCashTestSupport~assertTrue(worker2~install~ok,"reinstall recovered queues")
r=worker2~processOne
.FBTellerCashTestSupport~assertTrue(r~ok,"typed teller cash command recovered and processed")
.FBTellerCashTestSupport~assertEq("COMPLETED",r~value~value~state,"cash work semantics retained")
.FBTellerCashTestSupport~assertEq(inst~semanticIdentity,r~value~value~instruction~semanticIdentity,"exact physical instruction retained")
.FBTellerCashTestSupport~assertEq(1990000,e~ledger~balanceMinor("GBP-SRC"),"Core posted once")
.FBTellerCashTestSupport~assertEq(990000,till~expectedMinor,"physical cash released once")
.FBTellerCashTestSupport~pass("permanent Queue Fabric recovers typed Teller Cash command graph")
::requires "FederationBankTellerCashServiceQueue.cls"
::requires "TestSupport.cls"
