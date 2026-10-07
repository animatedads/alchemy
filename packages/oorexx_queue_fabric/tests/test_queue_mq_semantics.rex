/* ObjectQueueFabric v0.8 MQ-style semantics acceptance. */
assertions = 0
clock = .FakeQueueTimeSource~new(1000000)
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin", .nil, .nil, "STRICT", clock)

call assertOk manager~createQueue("WORK", "TEMPORARY", "OPS", 20, "admin"), "create WORK"
call assertOk manager~createQueue("DLQ", "TEMPORARY", "OPS", 20, "admin"), "create DLQ"
call assertOk manager~createQueue("BO", "TEMPORARY", "OPS", 20, "admin"), "create BO"
call assertOk manager~setDeadLetterQueue("DLQ", "admin"), "configure DLQ"
call assertOk manager~configureBackout("WORK", 2, "BO", "admin"), "configure backout"
probe = .DispositionProbe~new
call assertOk manager~registerTrigger("WORK", .QueueTriggerKind~EXPIRE, .QueueDirectTriggerTarget~new(probe, "onExpire"), 0, "admin"), "register expiry trigger"
call assertOk manager~registerTrigger("DLQ", .QueueTriggerKind~DEAD_LETTER, .QueueDirectTriggerTarget~new(probe, "onDeadLetter"), 0, "admin"), "register dead-letter trigger"
call assertOk manager~registerTrigger("BO", .QueueTriggerKind~BACKOUT, .QueueDirectTriggerTarget~new(probe, "onBackout"), 0, "admin"), "register backout trigger"
call assertEqual 2, manager~queue("WORK")~backoutThreshold, "backout threshold visible"
call assertEqual "BO", manager~queue("WORK")~backoutQueue, "backout queue visible"

expiryOptions = .table~new
expiryOptions["expirySeconds"] = 10
expiring = manager~put("WORK", "short-lived", expiryOptions, "admin")
call assertOk expiring, "put expiring package"
call assertTrue expiring~value~expiryTick \= 0, "expiry tick recorded"
call assertEqual 1, manager~queue("WORK")~expiringDepth, "expiring depth tracked"
clock~advance(11)
workDepth = manager~depth("WORK", "admin")
call assertOk workDepth, "depth sweeps expiry"
call assertEqual 0, workDepth~value["total"], "expired removed from source"
call assertEqual 0, manager~queue("WORK")~expiringDepth, "expiry counter decremented"
dlqDepth = manager~depth("DLQ", "admin")
call assertEqual 1, dlqDepth~value["ready"], "expired package dead-lettered"
dlqPackage = manager~browse("DLQ", "admin")~value
call assertEqual "EXPIRED", dlqPackage~deadLetterReason, "expiry disposition recorded"
call assertEqual "WORK", dlqPackage~deadLetterSourceQueue, "expiry source recorded"
call assertEqual 0, dlqPackage~expiryTick, "dead-lettered package no longer immediately expires"
call assertEqual 1, probe~expireCount, "expiry trigger fired"
call assertEqual 1, probe~deadLetterCount, "dead-letter trigger fired"

normal = manager~put("WORK", "retry-me", .nil, "admin")
call assertOk normal, "put retry package"
claim1 = manager~claim("WORK", "admin")
call assertOk claim1, "first claim"
nack1 = manager~nack("WORK", claim1~value~packageId, claim1~value~claimToken, "admin")
call assertOk nack1, "first nack"
call assertEqual 1, nack1~value~backoutCount, "first nack increments backout count"
call assertEqual "WORK", nack1~value~currentQueue, "below threshold requeues source"
claim2 = manager~claim("WORK", "admin")
call assertOk claim2, "second claim"
nack2 = manager~nack("WORK", claim2~value~packageId, claim2~value~claimToken, "admin")
call assertOk nack2, "second nack"
call assertEqual 2, nack2~value~backoutCount, "second nack increments backout count"
call assertEqual "BO", nack2~value~currentQueue, "threshold moves to backout queue"
call assertEqual "BACKOUT_THRESHOLD", nack2~value~deadLetterReason, "backout disposition recorded"
call assertEqual 0, manager~depth("WORK", "admin")~value["total"], "source empty after backout"
call assertEqual 1, manager~depth("BO", "admin")~value["ready"], "backout queue receives package"
call assertEqual 1, probe~backoutCount, "backout trigger fired"

/* Empty backoutQueue means use the configured same-domain DLQ. */
call assertOk manager~createQueue("FALLBACK", "TEMPORARY", "OPS", 10, "admin"), "create fallback queue"
call assertOk manager~configureBackout("FALLBACK", 1, "", "admin"), "configure DLQ fallback backout"
call assertOk manager~put("FALLBACK", "fallback-retry", .nil, "admin"), "put fallback retry"
fallbackClaim = manager~claim("FALLBACK", "admin")
call assertOk fallbackClaim, "claim fallback retry"
fallbackNack = manager~nack("FALLBACK", fallbackClaim~value~packageId, fallbackClaim~value~claimToken, "admin")
call assertOk fallbackNack, "nack fallback retry"
call assertEqual "DLQ", fallbackNack~value~currentQueue, "threshold falls back to manager DLQ"
call assertEqual "BACKOUT_TO_DEAD_LETTER", fallbackNack~value~deadLetterReason, "DLQ fallback disposition recorded"
call assertEqual 2, probe~deadLetterCount, "DLQ fallback fires dead-letter trigger"

/* Earliest-expiry watermark prevents repeated scans and is recomputed when due work leaves. */
call assertOk manager~createQueue("TTLQ", "TEMPORARY", "OPS", 10, "admin"), "create TTLQ"
ttl10 = .table~new; ttl10["expirySeconds"] = 10
ttl20 = .table~new; ttl20["expirySeconds"] = 20
firstTtl = manager~put("TTLQ", "first-ttl", ttl10, "admin")
secondTtl = manager~put("TTLQ", "second-ttl", ttl20, "admin")
call assertOk firstTtl, "put first TTL"
call assertOk secondTtl, "put second TTL"
call assertEqual firstTtl~value~expiryTick, manager~queue("TTLQ")~earliestExpiryTick, "earliest expiry watermark selects first TTL"
clock~advance(11)
call assertEqual 1, manager~sweepExpired("TTLQ", "admin")~value, "first TTL sweep removes only due package"
call assertEqual 1, manager~queue("TTLQ")~expiringDepth, "one TTL remains"
call assertEqual secondTtl~value~expiryTick, manager~queue("TTLQ")~earliestExpiryTick, "earliest expiry watermark recomputed"
clock~advance(10)
call assertEqual 1, manager~sweepExpired("TTLQ", "admin")~value, "second TTL eventually expires"
call assertEqual 0, manager~queue("TTLQ")~earliestExpiryTick, "empty expiry watermark resets"

call assertOk manager~createQueue("SECRET_BO", "TEMPORARY", "SECRET", 10, "admin"), "create mismatched backout"
badBackout = manager~configureBackout("WORK", 1, "SECRET_BO", "admin")
call assertFalse badBackout~ok, "cross-domain backout rejected"
call assertEqual "BACKOUT_SECURITY_DOMAIN_DENIED", badBackout~code, "cross-domain backout code"

/* Unit of work reserves GETs, stages PUTs, then makes both visible at commit. */
call assertOk manager~createQueue("TXIN", "TEMPORARY", "OPS", 10, "admin"), "create TXIN"
call assertOk manager~createQueue("TXOUT", "TEMPORARY", "OPS", 10, "admin"), "create TXOUT"
call assertOk manager~registerTrigger("TXOUT", .QueueTriggerKind~UOW_COMMIT, .QueueDirectTriggerTarget~new(probe, "onUowCommit"), 0, "admin"), "register UOW commit trigger"
call assertOk manager~registerTrigger("TXIN", .QueueTriggerKind~UOW_ROLLBACK, .QueueDirectTriggerTarget~new(probe, "onUowRollback"), 0, "admin"), "register UOW rollback trigger"
call assertOk manager~put("TXIN", "input", .nil, "admin"), "seed TXIN"
uowResult = manager~beginUnitOfWork("admin")
call assertOk uowResult, "begin UOW"
uow = uowResult~value
reserved = manager~uowGet(uow, "TXIN")
call assertOk reserved, "reserve get in UOW"
call assertEqual .QueuePackageState~INFLIGHT, reserved~value~state, "UOW get reserves package"
call assertTrue reserved~value~claimedBy~startsWith("UOW:"), "UOW reservation has non-user claim owner"
directAck = manager~ack("TXIN", reserved~value~packageId, reserved~value~claimToken, "admin")
call assertFalse directAck~ok, "ordinary ACK cannot escape UOW"
call assertEqual "CLAIM_TOKEN_MISMATCH", directAck~code, "UOW direct ACK denied by claim owner"
call assertOk manager~uowPut(uow, "TXOUT", "output", .nil), "stage UOW put"
call assertEqual 0, manager~depth("TXOUT", "admin")~value["ready"], "staged put invisible before commit"
call assertEqual 1, manager~depth("TXIN", "admin")~value["inflight"], "reserved get visible as inflight"
commit = manager~commitUnitOfWork(uow)
call assertOk commit, "commit UOW"
call assertEqual .QueueUnitOfWorkState~COMMITTED, uow~state, "UOW committed state"
call assertEqual 0, manager~depth("TXIN", "admin")~value["total"], "UOW committed get removed"
call assertEqual 1, manager~depth("TXOUT", "admin")~value["ready"], "UOW committed put visible"
call assertEqual 1, probe~uowCommitCount, "UOW commit trigger fired"
call assertFalse uow~markCommittedInternal(.nil), "caller cannot forge UOW state"

/* UOW PUT honours routing and capacity is checked on the transaction's net effect. */
call assertOk manager~createQueue("ROUTESRC", "TEMPORARY", "OPS", 10, "admin"), "create routed UOW source"
call assertOk manager~createQueue("ROUTEDST", "TEMPORARY", "OPS", 10, "admin"), "create routed UOW destination"
call assertOk manager~registerRoute("ROUTESRC", "tx", "ROUTEDST", .QueueRouteMode~REDIRECT, 0, .false, "admin"), "register routed UOW redirect"
routingOptions = .table~new; routingOptions["routingKey"] = "tx"
uowRoute = manager~beginUnitOfWork("admin")~value
call assertOk manager~uowPut(uowRoute, "ROUTESRC", "routed-uow", routingOptions), "stage routed UOW put"
call assertOk manager~commitUnitOfWork(uowRoute), "commit routed UOW"
call assertEqual 0, manager~depth("ROUTESRC", "admin")~value["total"], "routed UOW does not land on source"
call assertEqual 1, manager~depth("ROUTEDST", "admin")~value["ready"], "routed UOW lands on destination"

call assertOk manager~createQueue("SWAP", "TEMPORARY", "OPS", 1, "admin"), "create max-depth-one swap queue"
call assertOk manager~put("SWAP", "old", .nil, "admin"), "seed swap queue"
uowSwap = manager~beginUnitOfWork("admin")~value
call assertOk manager~uowGet(uowSwap, "SWAP"), "reserve swap input"
call assertOk manager~uowPut(uowSwap, "SWAP", "new", .nil), "stage replacement at nominal full depth"
call assertOk manager~commitUnitOfWork(uowSwap), "net-zero capacity UOW commits"
call assertEqual 1, manager~depth("SWAP", "admin")~value["ready"], "swap queue remains at max depth one"
call assertEqual "new", manager~browse("SWAP", "admin")~value~payload, "swap queue contains committed replacement"

/* Rollback returns reserved work and increments the backout count. */
call assertOk manager~put("TXIN", "rollback-me", .nil, "admin"), "seed rollback"
uow2 = manager~beginUnitOfWork("admin")~value
reserved2 = manager~uowGet(uow2, "TXIN")
call assertOk reserved2, "reserve rollback package"
call assertOk manager~uowPut(uow2, "TXOUT", "must-not-appear", .nil), "stage rollback put"
rollback = manager~rollbackUnitOfWork(uow2)
call assertOk rollback, "rollback UOW"
call assertEqual .QueueUnitOfWorkState~ROLLEDBACK, uow2~state, "UOW rolled back state"
call assertEqual 1, manager~depth("TXIN", "admin")~value["ready"], "rollback returns reserved package"
rolledBackPackage = manager~browse("TXIN", "admin")~value
call assertEqual 1, rolledBackPackage~backoutCount, "UOW rollback increments backout count"
call assertEqual 1, probe~uowRollbackCount, "UOW rollback trigger fired"
call assertEqual 1, manager~depth("TXOUT", "admin")~value["ready"], "rolled-back staged put not added"

/* Failed commit preflight leaves every staged/reserved action uncommitted. */
call assertOk manager~createQueue("FULL", "TEMPORARY", "OPS", 1, "admin"), "create FULL"
call assertOk manager~createQueue("ATOMICIN", "TEMPORARY", "OPS", 10, "admin"), "create ATOMICIN"
call assertOk manager~put("FULL", "occupied", .nil, "admin"), "fill FULL"
call assertOk manager~put("ATOMICIN", "atomic-input", .nil, "admin"), "seed atomic UOW"
uowFail = manager~beginUnitOfWork("admin")~value
reservedFail = manager~uowGet(uowFail, "ATOMICIN")
call assertOk reservedFail, "reserve atomic UOW input"
call assertOk manager~uowPut(uowFail, "FULL", "cannot-fit", .nil), "stage full-target put"
failedCommit = manager~commitUnitOfWork(uowFail)
call assertFalse failedCommit~ok, "full target aborts UOW commit"
call assertEqual "QUEUE_FULL_OR_DISABLED", failedCommit~code, "failed UOW capacity code"
call assertEqual 1, manager~depth("ATOMICIN", "admin")~value["inflight"], "failed UOW retains reservation rather than partially committing"
call assertEqual 1, manager~depth("FULL", "admin")~value["total"], "failed UOW leaves full target unchanged"
call assertOk manager~rollbackUnitOfWork(uowFail), "rollback after failed commit"
call assertEqual 1, manager~depth("ATOMICIN", "admin")~value["ready"], "rollback after failed commit restores source"

/* Durable UOW is represented by one replayable commit record. */
stateRoot = "./tmp_mq_semantics_" || .DateTime~new~microseconds
persistentClock = .FakeQueueTimeSource~new(5000000)
persistentManager = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, .nil, "STRICT", persistentClock)
call assertOk persistentManager~createQueue("P1", "PERMANENT", "OPS", 10, "admin"), "create P1"
call assertOk persistentManager~createQueue("P2", "PERMANENT", "OPS", 10, "admin"), "create P2"
persistentOptions = .table~new; persistentOptions["persistent"] = .true
call assertOk persistentManager~put("P1", "durable-in", persistentOptions, "admin"), "seed durable UOW"
uow3 = persistentManager~beginUnitOfWork("admin")~value
call assertOk persistentManager~uowGet(uow3, "P1"), "reserve durable input"
call assertOk persistentManager~uowPut(uow3, "P2", "durable-out", persistentOptions), "stage durable output"
call assertOk persistentManager~commitUnitOfWork(uow3), "commit durable UOW"
persistentManager2 = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, .nil, "STRICT", persistentClock)
call assertEqual 0, persistentManager2~depth("P1", "admin")~value["total"], "durable UOW get replays"
call assertEqual 1, persistentManager2~depth("P2", "admin")~value["ready"], "durable UOW put replays"
call assertEqual "durable-out", persistentManager2~browse("P2", "admin")~value~payload, "durable UOW payload replays"

/* Permanent DLQ/backout configuration and expiry metadata survive restart. */
call assertOk persistentManager2~createQueue("PWORK", "PERMANENT", "OPS", 10, "admin"), "create PWORK"
call assertOk persistentManager2~createQueue("PDLQ", "PERMANENT", "OPS", 10, "admin"), "create PDLQ"
call assertOk persistentManager2~createQueue("PBO", "PERMANENT", "OPS", 10, "admin"), "create PBO"
call assertOk persistentManager2~setDeadLetterQueue("PDLQ", "admin"), "persist DLQ configuration"
call assertOk persistentManager2~configureBackout("PWORK", 1, "PBO", "admin"), "persist backout configuration"
expiringPersistent = persistentOptions~copy; expiringPersistent["expirySeconds"] = 5
call assertOk persistentManager2~put("PWORK", "expire-after-restart", expiringPersistent, "admin"), "put durable expiring package"
persistentClock~advance(6)
persistentManager3 = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, .nil, "STRICT", persistentClock)
call assertEqual "PDLQ", persistentManager3~deadLetterQueue, "DLQ configuration recovered"
call assertEqual 1, persistentManager3~queue("PWORK")~backoutThreshold, "backout threshold recovered"
call assertEqual "PBO", persistentManager3~queue("PWORK")~backoutQueue, "backout target recovered"
call assertEqual 1, persistentManager3~queue("PWORK")~expiringDepth, "expiry metadata recovered"
call assertEqual 0, persistentManager3~depth("PWORK", "admin")~value["total"], "post-restart expiry removed source package"
call assertEqual 1, persistentManager3~depth("PDLQ", "admin")~value["ready"], "post-restart expiry dead-lettered package"
expiredRecovered = persistentManager3~browse("PDLQ", "admin")~value
call assertEqual "EXPIRED", expiredRecovered~deadLetterReason, "post-restart expiry reason retained"
call assertEqual "PWORK", expiredRecovered~deadLetterSourceQueue, "post-restart expiry source retained"
call assertEqual 0, expiredRecovered~expiryTick, "post-restart dead-letter clears expiry"

call assertOk persistentManager3~put("PWORK", "backout-after-restart", persistentOptions, "admin"), "put durable backout package"
persistentClaim = persistentManager3~claim("PWORK", "admin")
call assertOk persistentClaim, "claim durable backout package"
call assertOk persistentManager3~nack("PWORK", persistentClaim~value~packageId, persistentClaim~value~claimToken, "admin"), "nack durable backout package"
call assertEqual 1, persistentManager3~depth("PBO", "admin")~value["ready"], "recovered backout config routes package"
persistentManager4 = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, .nil, "STRICT", persistentClock)
call assertEqual 1, persistentManager4~depth("PBO", "admin")~value["ready"], "backout movement survives restart"
backedOutRecovered = persistentManager4~browse("PBO", "admin")~value
call assertEqual 1, backedOutRecovered~backoutCount, "backout count survives restart"
call assertEqual "BACKOUT_THRESHOLD", backedOutRecovered~deadLetterReason, "backout reason survives restart"

say "OBJECT QUEUE FABRIC V0.8 MQ SEMANTICS: OK"
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

::class DispositionProbe
::attribute expireCount get
::attribute deadLetterCount get
::attribute backoutCount get
::attribute uowCommitCount get
::attribute uowRollbackCount get
::method init
  expose expireCount deadLetterCount backoutCount uowCommitCount uowRollbackCount
  expireCount = 0; deadLetterCount = 0; backoutCount = 0; uowCommitCount = 0; uowRollbackCount = 0
::method onExpire
  expose expireCount
  use arg event
  expireCount += 1
  return .true
::method onDeadLetter
  expose deadLetterCount
  use arg event
  deadLetterCount += 1
  return .true
::method onBackout
  expose backoutCount
  use arg event
  backoutCount += 1
  return .true
::method onUowCommit
  expose uowCommitCount
  use arg event
  uowCommitCount += 1
  return .true
::method onUowRollback
  expose uowRollbackCount
  use arg event
  uowRollbackCount += 1
  return .true

::class FakeQueueTimeSource
::attribute tick get
::method init
  expose tick
  use arg initialTick
  numeric digits 30
  tick = initialTick
::method nowTick
  expose tick
  return tick
::method addSeconds
  use arg baseTick, seconds
  numeric digits 30
  return baseTick + (seconds * 1000000)
::method isExpired
  expose tick
  use arg expiryTick
  if expiryTick = 0 then return .false
  numeric digits 30
  return tick >= expiryTick
::method advance
  expose tick
  use arg seconds
  numeric digits 30
  tick = tick + (seconds * 1000000)
  return tick

::requires "ObjectQueueFabric.cls"
