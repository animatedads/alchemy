root=value("CRM_TEST_ROOT",,"ENVIRONMENT"); if root="" then raise syntax 88.900 array("CRM_TEST_ROOT required")
qroot=root||"/queue"; mgr=.ObjectQueueManager~new(qroot)
c=.FederationBankCRMPolicyFixtures~publishedCatalog; svc=.RelationshipCRMService~new(c)
sink=.RelationshipCRMQueueEventSink~new(mgr); svc2=.RelationshipCRMService~new(c,,.nil,sink)
w=.RelationshipCRMQueueWorker~new(svc2,mgr); call assert w~install~ok
ignore=mgr~grant("RELATIONSHIP.CRM.COMMANDS","client",.QueueAccess~PUT,"queue-admin")
ignore=mgr~createQueue("CLIENT.REPLY","TEMPORARY","CLIENT",0,"queue-admin"); ignore=mgr~grant("CLIENT.REPLY","relationship-crm-service",.QueueAccess~PUT,"queue-admin"); ignore=mgr~grant("CLIENT.REPLY","client",.QueueAccess~GET,"queue-admin")
r=.RelationshipRecord~new("REL-QS","COREBANK","CUST-QS"); p=.directory~new; p["relationship"]=r; env=.RelationshipCRMServiceEnvelope~new("QS1","CRM.RELATIONSHIP.OPEN","T1","TELLER",p,"CORR-1","",.DateTime~new,"CLIENT.REPLY")
put=mgr~put("RELATIONSHIP.CRM.COMMANDS",env,.nil,"client"); call assert put~ok
worked=w~processOne; call assert worked~ok
claimed=mgr~claim("CLIENT.REPLY","client"); call assert claimed~ok; reply=claimed~value~payload; .CRMServiceTest~assertTrue(reply~ok); .CRMServiceTest~assertEqual("CORR-1",reply~correlationId)
say "PASS queue adapter"
exit 0
assert: procedure; use arg v; .CRMServiceTest~assertTrue(v); return
::requires "TestSupport.cls"
::requires "RelationshipCRMServiceQueue.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
