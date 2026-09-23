assertions = 0
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call assertOk manager~createQueue("A", "TEMPORARY", "OPS", 2, "admin"), "create A"
call assertOk manager~createQueue("B", "TEMPORARY", "OPS", 1, "admin"), "create B"
call assertOk manager~createQueue("C", "TEMPORARY", "OPS", 2, "admin"), "create C"
call assertOk manager~put("B", "already-full", .nil, "admin"), "fill B"
routeCopy = manager~registerRoute("A", "x", "B", .QueueRouteMode~COPY, 0, .false, "admin")
call assertOk routeCopy, "copy route to B"
opts = .table~new; opts["routingKey"] = "x"
blocked = manager~put("A", "must-not-partially-arrive", opts, "admin")
call assertFalse blocked~ok, "full copy destination blocks whole put"
call assertEqual "QUEUE_FULL_OR_DISABLED", blocked~code, "full destination error"
call assertEqual 0, manager~depth("A", "admin")~value["ready"], "source unchanged on failed routed put"
call assertEqual 1, manager~depth("B", "admin")~value["ready"], "destination unchanged on failed routed put"
call assertOk manager~deregisterRoute(routeCopy~value~routeId, "admin"), "remove copy route"

r1 = manager~registerRoute("A", "y", "B", .QueueRouteMode~REDIRECT, 0, .false, "admin")
r2 = manager~registerRoute("A", "y", "C", .QueueRouteMode~REDIRECT, 0, .false, "admin")
call assertOk r1, "first redirect"
call assertOk r2, "second redirect"
opts = .table~new; opts["routingKey"] = "y"
ambiguous = manager~put("A", "ambiguous", opts, "admin")
call assertFalse ambiguous~ok, "ambiguous redirect rejected"
call assertEqual "AMBIGUOUS_REDIRECT", ambiguous~code, "ambiguous redirect code"
call assertEqual 0, manager~depth("A", "admin")~value["ready"], "ambiguous redirect no source mutation"
call assertEqual 0, manager~depth("C", "admin")~value["ready"], "ambiguous redirect no destination mutation"
call assertOk manager~deregisterRoute(r1~value~routeId, "admin"), "remove redirect one"
call assertOk manager~deregisterRoute(r2~value~routeId, "admin"), "remove redirect two"

call assertOk manager~createQueue("SECRET", "TEMPORARY", "SECRET", 2, "admin"), "create SECRET"
crossDenied = manager~registerRoute("A", "s", "SECRET", .QueueRouteMode~REDIRECT, 0, .false, "admin")
call assertFalse crossDenied~ok, "cross-domain route requires explicit bridge"
call assertEqual "ROUTE_SECURITY_DOMAIN_DENIED", crossDenied~code, "cross-domain denial code"
crossAllowed = manager~registerRoute("A", "s", "SECRET", .QueueRouteMode~REDIRECT, 0, .true, "admin")
call assertOk crossAllowed, "admin may register explicit cross-domain bridge"
opts = .table~new; opts["routingKey"] = "s"
crossPut = manager~put("A", "classified", opts, "admin")
call assertOk crossPut, "cross-domain bridge routes"
call assertEqual 1, manager~depth("SECRET", "admin")~value["ready"], "cross-domain destination receives package"

call assertOk manager~createQueue("TRIG", "TEMPORARY", "OPS", 10, "admin"), "create TRIG"
failProbe = .FailingTrigger~new
tr = manager~registerTrigger("TRIG", .QueueTriggerKind~PUT, .QueueDirectTriggerTarget~new(failProbe, "fail"), 0, "admin")
call assertOk tr, "register failing trigger"
putWithFailure = manager~put("TRIG", "payload", .nil, "admin")
call assertTrue putWithFailure~ok, "post-commit trigger failure does not roll back put"
call assertEqual 1, putWithFailure~triggerFailures~items, "trigger failure surfaced"
call assertEqual 1, manager~depth("TRIG", "admin")~value["ready"], "message remains after trigger failure"
call assertOk manager~deregisterTrigger(tr~value~triggerId, "admin"), "deregister trigger"
putAfterDereg = manager~put("TRIG", "payload2", .nil, "admin")
call assertEqual 0, putAfterDereg~triggerFailures~items, "deregistered trigger no longer runs"
call assertEqual 1, failProbe~count, "failing trigger invoked exactly once"

call assertOk manager~createQueue("CAP", "TEMPORARY", "OPS", 1, "admin"), "create CAP"
call assertOk manager~put("CAP", "one", .nil, "admin"), "fill CAP"
claim = manager~claim("CAP", "admin")
call assertOk claim, "claim CAP item"
call assertEqual 0, manager~depth("CAP", "admin")~value["ready"], "ready depth zero while claimed"
call assertEqual 1, manager~depth("CAP", "admin")~value["inflight"], "inflight depth one"
fullWithClaim = manager~put("CAP", "two", .nil, "admin")
call assertFalse fullWithClaim~ok, "max depth counts inflight work"
call assertEqual "QUEUE_FULL_OR_DISABLED", fullWithClaim~code, "inflight capacity refusal"

/* NoSQL projection is read-only; SQL cannot mutate queue manager state. */
noSql = .QueueNoSQLAdapter~new(manager)
mutation = noSql~query("admin", "UPDATE mq_queues SET state='DISABLED' WHERE queue_name='A'")
call assertTrue mutation~status \= .Error~SUCCESS, "NoSQL management projection rejects UPDATE"
call assertEqual .QueueState~ACTIVE, manager~queue("A")~state, "SQL mutation did not touch live queue"

/* Returned queue/package objects do not expose manager-owned envelope mutation. */
externalQueue = manager~queue("A")
call assertFalse externalQueue~setStateInternal(.QueueState~DISABLED, .nil), "caller cannot disable queue through returned endpoint"
call assertEqual .QueueState~ACTIVE, externalQueue~state, "endpoint state remains manager-owned"
call assertFalse externalQueue~allowAccess("intruder", .QueueAccess~PUT, .nil), "caller cannot forge ACL mutation"
visiblePackage = manager~browse("TRIG", "admin")~value
call assertFalse visiblePackage~markAcked(.nil), "caller cannot forge package ACK transition"
call assertTrue visiblePackage~state \= .QueuePackageState~ACKED, "package state remains manager-owned"

/* PERMANENT is an enforceable lifecycle, not a label. */
noStoreManager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
noStorePermanent = noStoreManager~createQueue("IMPOSSIBLE", "PERMANENT", "OPS", 10, "admin")
call assertFalse noStorePermanent~ok, "permanent queue requires durable store"
call assertEqual "PERSISTENCE_UNAVAILABLE", noStorePermanent~code, "permanent queue no-store code"

/* Durable queue rejects an arbitrary non-persistable domain object. */
stateRoot = "./tmp_adversarial_" || .DateTime~new~microseconds
persistentManager = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin")
call assertOk persistentManager~createQueue("P", "PERMANENT", "OPS", 10, "admin"), "create persistent P"
popt = .table~new; popt["persistent"] = .true
notPersistable = persistentManager~put("P", .Unpersistable~new, popt, "admin")
call assertFalse notPersistable~ok, "unpersistable object rejected"
call assertEqual "PAYLOAD_NOT_PERSISTABLE", notPersistable~code, "persistence rejection code"
call assertEqual 0, persistentManager~depth("P", "admin")~value["ready"], "rejected persistent object not enqueued"

/* A TEMP source redirected into a PERMANENT queue still performs persistence preflight. */
call assertOk persistentManager~createQueue("TSRC", "TEMPORARY", "OPS", 10, "admin"), "create temp source"
call assertOk persistentManager~registerRoute("TSRC", "p", "P", .QueueRouteMode~REDIRECT, 0, .false, "admin"), "temp to permanent redirect"
popt["routingKey"] = "p"
notPersistable2 = persistentManager~put("TSRC", .Unpersistable~new, popt, "admin")
call assertFalse notPersistable2~ok, "redirect to permanent preflights codec"
call assertEqual 0, persistentManager~depth("P", "admin")~value["ready"], "redirect failure has no partial durable mutation"

/* An in-flight durable package is redelivered after restart, not stranded. */
call assertOk persistentManager~put("P", "recover-me", popt~copy, "admin"), "durable string put"
claimP = persistentManager~claim("P", "admin")
call assertOk claimP, "claim durable package before simulated crash"
call assertEqual 1, persistentManager~depth("P", "admin")~value["inflight"], "durable package inflight before restart"
persistentManager2 = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin")
postCrashDepth = persistentManager2~depth("P", "admin")
call assertEqual 1, postCrashDepth~value["ready"], "inflight package redelivered READY after restart"
call assertEqual 0, postCrashDepth~value["inflight"], "no stranded inflight claim after restart"
redelivered = persistentManager2~browse("P", "admin")~value
call assertEqual 1, redelivered~deliveryCount, "delivery count retained across redelivery"
call assertEqual "", redelivered~claimToken, "stale claim token cleared"

/* Queue deletion is authoritative during replay: old durable wiring cannot resurrect. */
call assertOk persistentManager2~createQueue("DEL", "PERMANENT", "OPS", 10, "admin"), "create durable queue to delete"
call assertOk persistentManager2~createQueue("KEEP", "PERMANENT", "OPS", 10, "admin"), "create durable route destination"
registryTarget = .QueueRegistryTriggerTarget~new("PROD", "deleted-trigger-module", "onQueueTrigger")
delTrigger = persistentManager2~registerTrigger("DEL", .QueueTriggerKind~PUT, registryTarget, 0, "admin")
call assertOk delTrigger, "register durable trigger before queue deletion"
delRoute = persistentManager2~registerRoute("DEL", "*", "KEEP", .QueueRouteMode~COPY, 0, .false, "admin")
call assertOk delRoute, "register durable route before queue deletion"
call assertOk persistentManager2~deleteQueue("DEL", "admin"), "delete queue with durable wiring"
persistentManager3 = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin")
call assertTrue persistentManager3~queue("DEL") == .nil, "deleted durable queue does not recover"
call assertEqual 0, persistentManager3~triggers~items, "deleted queue durable trigger does not resurrect"
routeSurvivors = 0
do rule over persistentManager3~routes
  if rule~sourceQueue = "DEL" | rule~destinationQueue = "DEL" then routeSurvivors += 1
end
call assertEqual 0, routeSurvivors, "deleted queue durable route does not resurrect"

say "OBJECT QUEUE FABRIC V0.8 ADVERSARIAL: OK"
say "assertions=" || assertions
exit 0

assertOk: procedure expose assertions
  use arg operationResult, label
  assertions += 1
  if \operationResult~ok then do
    say "ASSERT FAILED:" label "code=" operationResult~code "detail=" operationResult~detail
    exit 1
  end
  return
assertTrue: procedure expose assertions
  use arg condition, label
  assertions += 1
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return
assertFalse: procedure expose assertions
  use arg condition, label
  assertions += 1
  if condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return
assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::class FailingTrigger
::attribute count get
::method init
  expose count
  count = 0
::method fail
  expose count
  use arg event
  count += 1
  raise syntax 88.900 array("intentional trigger failure")

::class Unpersistable
::attribute value
::method init
  self~value = "opaque"

::requires "ObjectQueueNoSQL.cls"
