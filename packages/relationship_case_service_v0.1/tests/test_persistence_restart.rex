parse arg storeRoot
if storeRoot = "" then do; say "FAIL: store root required"; exit 1; end
catalog=.FederationBankCasePolicyFixtures~publishedCatalog
sink1=.RelationshipCaseMemoryEventSink~new~failNext
store1=.RelationshipCaseServiceStore~new(storeRoot)
service1=.RelationshipCaseService~new(catalog, .nil, store1, sink1)
p=.directory~new; p["caseId"]="RESTART-1"; p["caseType"]="SERVICE_CASE"
cmd=.RelationshipCaseServiceEnvelope~new("R-OPEN", "CASE.OPEN", "S1", "SERVICE", p)
r=service1~handle(cmd)
.RelationshipCaseServiceTestSupport~assertTrue(r~ok, "mutation commits despite temporary event sink failure")
.RelationshipCaseServiceTestSupport~assertEqual(1, service1~state~outbox~items, "failed publish remains in durable outbox")
/* New process object, same append-only store. */
sink2=.RelationshipCaseMemoryEventSink~new
store2=.RelationshipCaseServiceStore~new(storeRoot)
service2=.RelationshipCaseService~new(catalog, .nil, store2, sink2)
.RelationshipCaseServiceTestSupport~assertTrue(\service2~faulted, "restart recovered")
.RelationshipCaseServiceTestSupport~assertEqual(1, service2~repository~get("RESTART-1")~value~events~items, "domain event recovered")
.RelationshipCaseServiceTestSupport~assertEqual(1, service2~state~outbox~items, "outbox recovered")
flushed=service2~flushOutbox
.RelationshipCaseServiceTestSupport~assertTrue(flushed~ok, "outbox redelivered")
.RelationshipCaseServiceTestSupport~assertEqual(0, service2~state~outbox~items, "outbox ack persisted")
.RelationshipCaseServiceTestSupport~assertEqual(1, sink2~events~items, "one stable event delivered")
replay=service2~handle(cmd)
.RelationshipCaseServiceTestSupport~assertTrue(replay~ok, "idempotency survives restart")
.RelationshipCaseServiceTestSupport~assertEqual("IDEMPOTENT_REPLAY", replay~code, "restart replay code")
/* Continue mutating restored case; domain event sequence must not collide. */
tp=.directory~new; tp["caseId"]="RESTART-1"; tp["action"]="START_TRIAGE"
r=service2~handle(.RelationshipCaseServiceEnvelope~new("R-TRIAGE", "CASE.TRANSITION", "S1", "SERVICE", tp))
.RelationshipCaseServiceTestSupport~assertTrue(r~ok, "post-restart mutation")
caseObject=service2~repository~get("RESTART-1")~value
.RelationshipCaseServiceTestSupport~assertEqual("RESTART-1:EV:2:STATE_CHANGED", caseObject~events[2]~eventId, "restart-safe domain event id")
say "PASS test_persistence_restart"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCaseServicePersistence.cls"
::requires "InstitutionalPolicy.cls"
