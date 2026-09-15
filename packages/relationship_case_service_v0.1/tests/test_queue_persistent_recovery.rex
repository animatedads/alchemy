parse arg queueRoot
if queueRoot = "" then do; say "FAIL: queue root required"; exit 1; end
catalog=.FederationBankCasePolicyFixtures~publishedCatalog
codec1=.RelationshipCaseServicePersistenceSupport~newCodec
manager1=.ObjectQueueManager~new(queueRoot, codec1, "queue-admin")
/* Install permanent queues before the service exists. */
service1=.RelationshipCaseService~new(catalog)
worker1=.RelationshipCaseQueueWorker~new(service1, manager1, "RELATIONSHIP.CASE.COMMANDS", "RELATIONSHIP.CASE.EVENTS", "relationship-case-service", "queue-admin", "PERMANENT")
.RelationshipCaseServiceTestSupport~assertTrue(worker1~install~ok, "install permanent queues")
p=.directory~new; p["caseId"]="QUEUE-RECOVER-1"; p["caseType"]="SERVICE_CASE"
envelope=.RelationshipCaseServiceEnvelope~new("Q-RECOVER-CMD", "CASE.OPEN", "STAFF-Q", "SERVICE", p, "Q-RECOVER-CORR")
options=.table~new; options["persistent"]=.true
.RelationshipCaseServiceTestSupport~assertTrue(manager1~put("RELATIONSHIP.CASE.COMMANDS", envelope, options, "queue-admin")~ok, "persist command")
/* Re-open Queue Fabric from disk before delivery. The typed envelope must recover. */
codec2=.RelationshipCaseServicePersistenceSupport~newCodec
manager2=.ObjectQueueManager~new(queueRoot, codec2, "queue-admin")
sink2=.RelationshipCaseQueueEventSink~new(manager2)
service2=.RelationshipCaseService~new(catalog, .nil, .nil, sink2)
worker2=.RelationshipCaseQueueWorker~new(service2, manager2, "RELATIONSHIP.CASE.COMMANDS", "RELATIONSHIP.CASE.EVENTS", "relationship-case-service", "queue-admin", "PERMANENT")
.RelationshipCaseServiceTestSupport~assertTrue(worker2~install~ok, "recovered queues")
browse=manager2~browse("RELATIONSHIP.CASE.COMMANDS", "queue-admin")
.RelationshipCaseServiceTestSupport~assertTrue(browse~ok, "command recovered")
.RelationshipCaseServiceTestSupport~assertTrue(browse~value~payload~isA(.RelationshipCaseServiceEnvelope), "typed command object recovered")
.RelationshipCaseServiceTestSupport~assertEqual("Q-RECOVER-CORR", browse~value~payload~correlationId, "recovered correlation")
processed=worker2~processOne
.RelationshipCaseServiceTestSupport~assertTrue(processed~ok, "process recovered command")
eventPkg=manager2~get("RELATIONSHIP.CASE.EVENTS", "queue-admin")
.RelationshipCaseServiceTestSupport~assertTrue(eventPkg~ok, "persistent event emitted")
.RelationshipCaseServiceTestSupport~assertEqual("QUEUE-RECOVER-1", eventPkg~value~payload~caseId, "event case")
say "PASS test_queue_persistent_recovery"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCaseServiceQueue.cls"
::requires "InstitutionalPolicy.cls"
