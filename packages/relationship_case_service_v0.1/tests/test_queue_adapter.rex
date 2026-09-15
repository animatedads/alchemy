catalog=.FederationBankCasePolicyFixtures~publishedCatalog
codec=.RelationshipCaseServicePersistenceSupport~newCodec
manager=.ObjectQueueManager~new("", codec, "queue-admin")
sink=.RelationshipCaseQueueEventSink~new(manager)
service=.RelationshipCaseService~new(catalog, .nil, .nil, sink)
worker=.RelationshipCaseQueueWorker~new(service, manager)
.RelationshipCaseServiceTestSupport~assertTrue(worker~install~ok, "install command/event queues")
p=.directory~new; p["caseId"]="QUEUE-1"; p["caseType"]="SERVICE_CASE"
envelope=.RelationshipCaseServiceEnvelope~new("Q-CMD-1", "CASE.OPEN", "STAFF-Q", "SERVICE", p, "Q-CORR-1", "", .DateTime~new, "CASE.REPLIES.TEST")
put=manager~put("RELATIONSHIP.CASE.COMMANDS", envelope, .table~new, "queue-admin")
.RelationshipCaseServiceTestSupport~assertTrue(put~ok, "enqueue command")
processed=worker~processOne
.RelationshipCaseServiceTestSupport~assertTrue(processed~ok, "worker processes command")
replyPkg=manager~get("CASE.REPLIES.TEST", "queue-admin")
.RelationshipCaseServiceTestSupport~assertTrue(replyPkg~ok, "reply available")
reply=replyPkg~value~payload
.RelationshipCaseServiceTestSupport~assertTrue(reply~ok, "reply success")
.RelationshipCaseServiceTestSupport~assertEqual("Q-CORR-1", reply~correlationId, "reply correlation")
eventPkg=manager~get("RELATIONSHIP.CASE.EVENTS", "queue-admin")
.RelationshipCaseServiceTestSupport~assertTrue(eventPkg~ok, "event available")
event=eventPkg~value~payload
.RelationshipCaseServiceTestSupport~assertEqual("CASE.OPENED", event~eventType, "event type")
.RelationshipCaseServiceTestSupport~assertEqual("Q-CORR-1", event~correlationId, "event correlation")
say "PASS test_queue_adapter"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCaseServiceQueue.cls"
::requires "InstitutionalPolicy.cls"
