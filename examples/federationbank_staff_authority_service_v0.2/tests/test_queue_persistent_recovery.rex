root="/tmp/fbstaff-queue-"||time("S")||"-"||random(100000,999999)
codec=.FederationBankStaffAuthorityServicePersistenceSupport~newCodec
manager=.ObjectQueueManager~new(root,codec,"queue-admin")
svc=.FBStaffServiceTestSupport~service
worker=.FederationBankStaffAuthorityQueueWorker~new(svc,manager,"FB.STAFF.CMD","FB.STAFF.EVT","fb-staff-authority-service","queue-admin","PERMANENT")
.FBStaffServiceTestSupport~assertTrue(worker~install~ok,"install")
ignore=manager~grant("FB.STAFF.CMD","client",.QueueAccess~PUT,"queue-admin")
ctx=.FBStaffServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
p=.directory~new; p["context"]=ctx
env=.FederationBankStaffServiceEnvelope~new("Q-CTX","FBSTAFF.CONTEXT.PUT","IAM-SYNC","IAM",p)
o=.table~new; o["persistent"]=.true
.FBStaffServiceTestSupport~assertTrue(manager~put("FB.STAFF.CMD",env,o,"client")~ok,"queued")
/* Destroy/recreate manager before consumption. */
manager2=.ObjectQueueManager~new(root,codec,"queue-admin")
svc2=.FBStaffServiceTestSupport~service
worker2=.FederationBankStaffAuthorityQueueWorker~new(svc2,manager2,"FB.STAFF.CMD","FB.STAFF.EVT","fb-staff-authority-service","queue-admin","PERMANENT")
.FBStaffServiceTestSupport~assertTrue(worker2~install~ok,"reinstall")
r=worker2~processOne
.FBStaffServiceTestSupport~assertTrue(r~ok,"typed command recovered")
.FBStaffServiceTestSupport~assertEq("CONTEXT_STORED",r~value~code,"semantics retained")
.FBStaffServiceTestSupport~assertTrue(svc2~state~context("TELLER-04")<>.nil,"typed staff context recovered")
.FBStaffServiceTestSupport~pass("permanent Queue Fabric recovers typed staff authority command graph")
::requires "FederationBankStaffAuthorityServiceQueue.cls"
::requires "TestSupport.cls"
