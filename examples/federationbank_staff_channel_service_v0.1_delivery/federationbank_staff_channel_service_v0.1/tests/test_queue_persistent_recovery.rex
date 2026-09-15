e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelServiceTestSupport~openAccounts(e)
.FBStaffChannelServiceTestSupport~seed(e,2000000)
root="/tmp/fbstaffch-queue-"||time("S")||"-"||random(100000,999999)
codec=.FederationBankStaffChannelServicePersistenceSupport~newCodec
manager=.ObjectQueueManager~new(root,codec,"queue-admin")
svc=.FBStaffChannelServiceTestSupport~service(e)
worker=.FederationBankStaffChannelQueueWorker~new(svc,manager,"FB.STAFFCH.CMD","FB.STAFFCH.EVT","fb-staff-channel-service","queue-admin","PERMANENT")
.FBStaffChannelServiceTestSupport~assertTrue(worker~install~ok,"install")
ignore=manager~grant("FB.STAFFCH.CMD","client",.QueueAccess~PUT,"queue-admin")
ctx=.FBStaffChannelServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
env=.FBStaffChannelServiceTestSupport~submitEnvelope("Q:SUBMIT",.FBStaffChannelServiceTestSupport~request("QUEUE"),.FBStaffChannelServiceTestSupport~contexts(ctx))
o=.table~new; o["persistent"]=.true
.FBStaffChannelServiceTestSupport~assertTrue(manager~put("FB.STAFFCH.CMD",env,o,"client")~ok,"queued")
/* Destroy/recreate queue manager before the command is consumed. */
manager2=.ObjectQueueManager~new(root,codec,"queue-admin")
svc2=.FBStaffChannelServiceTestSupport~service(e)
worker2=.FederationBankStaffChannelQueueWorker~new(svc2,manager2,"FB.STAFFCH.CMD","FB.STAFFCH.EVT","fb-staff-channel-service","queue-admin","PERMANENT")
.FBStaffChannelServiceTestSupport~assertTrue(worker2~install~ok,"reinstall")
r=worker2~processOne
.FBStaffChannelServiceTestSupport~assertTrue(r~ok,"typed command recovered")
.FBStaffChannelServiceTestSupport~assertEq("COMPLETED",r~value~value~state,"work semantics retained")
.FBStaffChannelServiceTestSupport~assertEq(1750000,e~ledger~balanceMinor("GBP-SRC"),"Core posted")
.FBStaffChannelServiceTestSupport~pass("permanent Queue Fabric recovers typed Staff Channel command graph")
::requires "FederationBankStaffChannelServiceQueue.cls"
::requires "TestSupport.cls"
