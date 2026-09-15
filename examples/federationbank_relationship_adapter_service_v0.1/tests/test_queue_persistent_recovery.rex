root="/tmp/fbrel-queue-"||time("S")||"-"||random(100000,999999)
codec=.FederationBankRelationshipServicePersistenceSupport~newCodec
manager=.ObjectQueueManager~new(root,codec,"queue-admin")
port=.FakeRelationshipBankPort~new; svc=.FederationBankRelationshipAdapterService~new(.FBRelationshipServiceTestSupport~fixture,port)
sink=.FederationBankRelationshipQueueEventSink~new(manager)
svc=.FederationBankRelationshipAdapterService~new(.FBRelationshipServiceTestSupport~fixture,port,.nil,sink)
worker=.FederationBankRelationshipQueueWorker~new(svc,manager,"FB.REL.CMD","FB.REL.EVT","fb-relationship-service","queue-admin","PERMANENT")
.FBRelationshipServiceTestSupport~assertTrue(worker~install~ok,"install")
ignore=manager~grant("FB.REL.CMD","client",.QueueAccess~PUT,"queue-admin")
fx=.FBRelationshipServiceTestSupport~transaction("QUEUE")
env=.FederationBankRelationshipServiceEnvelope~new("Q-CMD","FBREL.ACTION.SUBMIT","TEL-1","TELLER",fx)
o=.table~new; o["persistent"]=.true; put=manager~put("FB.REL.CMD",env,o,"client")
.FBRelationshipServiceTestSupport~assertTrue(put~ok,"queued")
/* Re-open manager before processing to prove typed command graph recovery. */
manager2=.ObjectQueueManager~new(root,codec,"queue-admin")
svc2=.FederationBankRelationshipAdapterService~new(.FBRelationshipServiceTestSupport~fixture,.FakeRelationshipBankPort~new,.nil,.FederationBankRelationshipQueueEventSink~new(manager2,"FB.REL.EVT","fb-relationship-service"))
worker2=.FederationBankRelationshipQueueWorker~new(svc2,manager2,"FB.REL.CMD","FB.REL.EVT","fb-relationship-service","queue-admin","PERMANENT")
.FBRelationshipServiceTestSupport~assertTrue(worker2~install~ok,"reinstall")
r=worker2~processOne
.FBRelationshipServiceTestSupport~assertTrue(r~ok,"process recovered typed command")
.FBRelationshipServiceTestSupport~assertEq("SUBMITTED",r~value~value~status,"recovered command semantics")
.FBRelationshipServiceTestSupport~pass("permanent Queue Fabric recovers typed decision/request/case command")
::requires "FederationBankRelationshipServiceQueue.cls"
::requires "FakeBankPort.cls"
::requires "TestSupport.cls"
