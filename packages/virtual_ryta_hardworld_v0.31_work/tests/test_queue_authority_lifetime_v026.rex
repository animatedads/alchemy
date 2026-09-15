say 'QUEUE AUTHORITY LIFETIME V0.26 START'

ledgerPath = '/tmp/ryta_queue_authority_v026_' || .DateTime~new~microseconds || '.ledger'
queueRoot = '/tmp/ryta_queue_authority_v026_' || .DateTime~new~microseconds
ignore = SysFileDelete(ledgerPath)
manager = .ObjectQueueManager~new(queueRoot, .QueueGraphPayloadCodec~new, 'admin')
call AssertOk manager~createQueue('Q.BIND', 'PERMANENT', 'AUTHORITY', 30, 'admin'), 'create binding queue'
topics = .QueueTopicFabric~new(manager)
call AssertOk topics~defineTopic('AUTH.V026', 'authority lifetime', 'PERMANENT', 'AUTHORITY', 'admin'), 'define topic'

opts = .table~new
opts['subtopic'] = 'retained/state'
opts['retain'] = .true
opts['persistent'] = .true
published = topics~publish('AUTH.V026', 'publisher-envelope', opts, 'admin')
call AssertOk published, 'publish retained work'
publicationId = published~value~publicationId
call AssertOk topics~subscribe('S.BIND', 'AUTH.V026', 'retained/#', 'Q.BIND', 'PERMANENT', 'admin'), 'late binding subscriber'
claim1 = manager~claim('Q.BIND', 'admin')
call AssertOk claim1, 'claim binding attempt 1'
package1 = claim1~value
token1 = package1~claimToken
publisherSet = BuildPromotionSet('PUB-V026', 'PUBLISHER_V026_SHOULD_NOT_APPLY', .true, 'PUBLISHER')
world1 = .RYTAWorldState~new('V026-BINDING-WORLD')
ledger = .QueueAuthorityExecutionLedger~new(ledgerPath)

/* Prime a cached successful consumer result, but refuse this attempt before START. */
cache = .CacheThenRefuseRevalidator~new(publicationId)
primed = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.BIND', package1, token1, 'admin', publisherSet, world1, 'NODE-V026/BIND', ledger, .nil, cache)
call AssertTrue \primed~ok, 'cache priming call refused'
call AssertEqual 'TEST_CACHE_PRIMED_REFUSAL', primed~code, 'cache priming refusal code'
call AssertTrue cache~cachedResult \== .nil, 'successful result cached internally for attack'
call AssertEqual 'NONE', ledger~stateFor(primed~workIdentity~executionKey), 'cache priming refusal before START'

/* A second claim is a different delivery attempt. Replaying attempt-1 authority is refused. */
call AssertOk manager~release('Q.BIND', package1~packageId, token1, 'admin', 'retry cached authority attack'), 'release attempt 1'
claim2 = manager~claim('Q.BIND', 'admin')
call AssertOk claim2, 'claim binding attempt 2'
package2 = claim2~value
token2 = package2~claimToken
call AssertEqual package1~packageId, package2~packageId, 'same stable package on retry'
call AssertEqual 2, package2~deliveryCount, 'delivery count advances on retry'
replayedAttempt = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.BIND', package2, token2, 'admin', publisherSet, world1, 'NODE-V026/BIND', ledger, .nil, cache)
call AssertTrue \replayedAttempt~ok, 'cached prior-attempt consumer authority refused'
call AssertEqual 'RETAINED_AUTHORITY_ATTEMPT_BINDING_MISMATCH', replayedAttempt~code, 'attempt binding mismatch code'
call AssertEqual 'NONE', ledger~stateFor(replayedAttempt~workIdentity~executionKey), 'attempt mismatch remains before START'
call AssertEqual 'UNKNOWN', world1~knowledgeOf('CONSUMER_V026_CURRENT'), 'cached attempt cannot mutate world'

/* The same cached result also cannot cross to a second subscriber/work identity. */
call AssertOk manager~createQueue('Q.BIND.2', 'PERMANENT', 'AUTHORITY', 30, 'admin'), 'create second binding queue'
call AssertOk topics~subscribe('S.BIND.2', 'AUTH.V026', 'retained/#', 'Q.BIND.2', 'PERMANENT', 'admin'), 'second late subscriber'
claimOther = manager~claim('Q.BIND.2', 'admin')
call AssertOk claimOther, 'claim other subscriber package'
otherPackage = claimOther~value
otherWorld = .RYTAWorldState~new('V026-OTHER-WORLD')
staticCached = .StaticResultRevalidator~new(cache~cachedResult)
crossWork = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.BIND.2', otherPackage, otherPackage~claimToken, 'admin', publisherSet, otherWorld, 'NODE-V026/BIND', ledger, .nil, staticCached)
call AssertTrue \crossWork~ok, 'cached consumer authority cannot cross work identity'
call AssertEqual 'RETAINED_AUTHORITY_WORK_BINDING_MISMATCH', crossWork~code, 'work binding mismatch code'
call AssertEqual 'UNKNOWN', otherWorld~knowledgeOf('CONSUMER_V026_CURRENT'), 'cross-work replay cannot mutate world'
call AssertOk manager~ack('Q.BIND.2', otherPackage~packageId, otherPackage~claimToken, 'admin'), 'operator cleanup other package'

/* A genuinely fresh result for attempt 2 may execute. */
fresh = .CurrentConsumerRevalidator~new(publicationId)
freshResult = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.BIND', package2, token2, 'admin', publisherSet, world1, 'NODE-V026/BIND', ledger, .nil, fresh)
call AssertTrue freshResult~ok, 'fresh attempt-bound consumer authority executes'
call AssertEqual 'APPLIED_AND_ACKED', freshResult~code, 'fresh result code'
call AssertTrue world1~isKnownTrue('CONSUMER_V026_CURRENT'), 'fresh consumer authority applied'
call AssertEqual 'UNKNOWN', world1~knowledgeOf('PUBLISHER_V026_SHOULD_NOT_APPLY'), 'publisher authority remains stale evidence'
call AssertEqual 'V2', ledger~recordVersionFor(freshResult~workIdentity~executionKey), 'new execution uses v2 ledger record'
call AssertTrue ledger~envelopeFingerprintFor(freshResult~workIdentity~executionKey) \= '', 'v2 envelope fingerprint recorded'
call AssertTrue ledger~authorityFingerprintFor(freshResult~workIdentity~executionKey) \= '', 'v2 authority fingerprint recorded'

/* Stable decision canonical text excludes per-delivery binding, while binding text does not. */
a1 = .QueueAuthorityRevalidationResult~success(BuildConsumerSet(), publicationId, 'CTX-V026', 'TEST-V026/1', .nil, '', '', 'WORK-A', 'ATTEMPT-1')
a2 = .QueueAuthorityRevalidationResult~success(BuildConsumerSet(), publicationId, 'CTX-V026', 'TEST-V026/1', .nil, '', '', 'WORK-A', 'ATTEMPT-2')
call AssertEqual a1~algorithmCanonicalText, a2~algorithmCanonicalText, 'attempt binding excluded from stable authority decision canonical text'
call AssertTrue a1~executionBindingCanonicalText \= a2~executionBindingCanonicalText, 'attempt binding separately canonicalised'

/* COMPLETE-before-ACK: current authority may later disappear, but no new mutation
   is needed.  V2 permits ACK-only recovery after matching the immutable envelope. */
call AssertOk manager~createQueue('Q.ACK', 'PERMANENT', 'AUTHORITY', 30, 'admin'), 'create ack-recovery queue'
call AssertOk topics~subscribe('S.ACK', 'AUTH.V026', 'retained/#', 'Q.ACK', 'PERMANENT', 'admin'), 'ack-recovery late subscriber'
ackClaim1 = manager~claim('Q.ACK', 'admin')
call AssertOk ackClaim1, 'claim ack-recovery attempt 1'
ackPackage1 = ackClaim1~value
ackToken1 = ackPackage1~claimToken
ackWorld = .RYTAWorldState~new('V026-ACK-WORLD')
ackWrapper = .AckFailOnceQueueManager~new(manager)
ackRevalidator = .CurrentConsumerRevalidator~new(publicationId)
firstExecution = .QueueAuthorityPromotionExecutor~execute(ackWrapper, 'Q.ACK', ackPackage1, ackToken1, 'admin', publisherSet, ackWorld, 'NODE-V026/ACK', ledger, .nil, ackRevalidator)
call AssertTrue \firstExecution~ok, 'first execution reports injected ACK failure'
call AssertEqual 'ACK_FAILED_AFTER_COMPLETE', firstExecution~code, 'ACK failure occurs after durable COMPLETE'
call AssertTrue ackWorld~isKnownTrue('CONSUMER_V026_CURRENT'), 'authority-bearing mutation completed before ACK failure'
call AssertEqual 'COMPLETE', ledger~stateFor(firstExecution~workIdentity~executionKey), 'ledger records COMPLETE before ACK retry'
call AssertEqual 'INFLIGHT', ackPackage1~state, 'package remains inflight after injected ACK failure'

/* Changing the submitted publisher envelope cannot exploit COMPLETE to get a blind ACK. */
tamperedPublisherSet = BuildPromotionSet('PUB-V026-TAMPER', 'TAMPERED_PUBLISHER_AUTHORITY', .true, 'PUBLISHER')
tampered = .QueueAuthorityPromotionExecutor~execute(ackWrapper, 'Q.ACK', ackPackage1, ackToken1, 'admin', tamperedPublisherSet, ackWorld, 'NODE-V026/ACK', ledger, .nil, .ExplodingRevalidator~new)
call AssertTrue \tampered~ok, 'tampered envelope refused even after COMPLETE'
call AssertEqual 'WORK_ENVELOPE_CONFLICT', tampered~code, 'tampered envelope conflict code'
call AssertEqual 'INFLIGHT', ackPackage1~state, 'tampered retry not ACKed'

/* Redelivery creates a new claim/attempt.  No current authority evaluation is
   allowed or required because COMPLETE proves the side effect already happened. */
call AssertOk manager~release('Q.ACK', ackPackage1~packageId, ackToken1, 'admin', 'simulate transport retry after complete'), 'release completed-but-unacked package'
ackClaim2 = manager~claim('Q.ACK', 'admin')
call AssertOk ackClaim2, 'claim ack-recovery attempt 2'
ackPackage2 = ackClaim2~value
call AssertEqual 2, ackPackage2~deliveryCount, 'ACK retry is a new delivery attempt'
ackOnly = .QueueAuthorityPromotionExecutor~execute(ackWrapper, 'Q.ACK', ackPackage2, ackPackage2~claimToken, 'admin', publisherSet, ackWorld, 'NODE-V026/ACK', ledger, .nil, .ExplodingRevalidator~new)
call AssertTrue ackOnly~ok, 'matching COMPLETE retry performs ACK-only recovery'
call AssertEqual 'ALREADY_COMPLETE_ACKED', ackOnly~code, 'ACK-only recovery code'
call AssertTrue ackOnly~replaySuppressed, 'ACK-only recovery suppresses authority replay'
call AssertTrue ackOnly~revalidationEvidence == .nil, 'ACK-only recovery mints no new revalidation evidence'
call AssertTrue ackOnly~applyResult == .nil, 'ACK-only recovery performs no promotion application'
call AssertEqual 'ACKED', ackPackage2~state, 'package ACKed after transport-only recovery'
call AssertEqual 1, ackRevalidator~calls, 'original authority evaluator called exactly once'

/* Bearer-like claim tokens remain absent from both v1/v2 ledger material. */
ledgerText = ReadFile(ledgerPath)
call AssertEqual 0, pos(token2, ledgerText), 'retry claim token absent from ledger'
call AssertEqual 0, pos(c2x(token2), ledgerText), 'retry claim token hex absent from ledger'
call AssertEqual 0, pos(ackToken1, ledgerText), 'failed-ACK claim token absent from ledger'
call AssertEqual 0, pos(c2x(ackToken1), ledgerText), 'failed-ACK claim token hex absent from ledger'

ignore = SysFileDelete(ledgerPath)
say 'QUEUE AUTHORITY LIFETIME V0.26: OK'
exit 0

::routine BuildPromotionSet
  use arg promotionId, targetFact, value, sourcePhase
  promotion = .EvidencePromotion~new(promotionId, 'QUEUE_V026_' || sourcePhase, 'SRC-' || promotionId, targetFact, 'KNOWN', value, 'TEST_AUTHORITY', 'TEST_POLICY', 'TEST_RULE', 'REQUIRED', 'AUTHORIZED')
  set = .EvidencePromotionSet~new
  if \set~add(promotion) then raise syntax 88.900 array('could not add promotion ' || promotionId)
  ignored = set~seal
  return set

::routine BuildConsumerSet
  return BuildPromotionSet('CONSUMER-V026-P1', 'CONSUMER_V026_CURRENT', .true, 'CONSUMER')

::routine ReadFile
  use arg path
  stream = .Stream~new(path)
  if stream~open('read') \= 'READY:' then return ''
  count = stream~chars
  if count = 0 then do; ignored = stream~close; return ''; end
  text = stream~charIn(1, count)
  ignored = stream~close
  return text

::routine AssertOk
  use arg resultObject, label
  if resultObject == .nil then raise syntax 88.900 array('ASSERT OK FAILED: ' || label || ' nil')
  if \resultObject~ok then raise syntax 88.900 array('ASSERT OK FAILED: ' || label || ' code=' || resultObject~code || ' detail=' || resultObject~detail)
  return 0

::routine AssertTrue
  use arg conditionValue, label
  if \conditionValue then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0

::routine AssertEqual
  use arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::class CurrentConsumerRevalidator public
::attribute publicationId get
::attribute calls get
::method init
  expose publicationId calls
  use arg publicationIdArg
  publicationId = publicationIdArg~string
  calls = 0
::method revalidate
  expose publicationId calls
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence
  calls += 1
  currentSet = BuildConsumerSet()
  attemptIdentity = .QueueAuthorityPromotionExecutor~attemptIdentity(attemptEvidence)
  evidence = .directory~new
  evidence['phase'] = 'CONSUMER_TIME'
  evidence['delivery_count'] = attemptEvidence~deliveryCount
  return .QueueAuthorityRevalidationResult~success(currentSet, publicationId, 'CTX-V026', 'TEST-V026/1', evidence, '', '', workIdentity~executionKey, attemptIdentity)

::class CacheThenRefuseRevalidator public
::attribute publicationId get
::attribute cachedResult get
::attribute calls get
::method init
  expose publicationId cachedResult calls
  use arg publicationIdArg
  publicationId = publicationIdArg~string
  cachedResult = .nil
  calls = 0
::method revalidate
  expose publicationId cachedResult calls
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence
  calls += 1
  if calls = 1 then do
    attemptIdentity = .QueueAuthorityPromotionExecutor~attemptIdentity(attemptEvidence)
    cachedResult = .QueueAuthorityRevalidationResult~success(BuildConsumerSet(), publicationId, 'CTX-V026', 'TEST-CACHED-V026/1', .nil, '', '', workIdentity~executionKey, attemptIdentity)
    return .QueueAuthorityRevalidationResult~failure('TEST_CACHE_PRIMED_REFUSAL', 'cached success retained for replay adversary', publicationId, 'CTX-V026', 'TEST-CACHED-V026/1')
  end
  return cachedResult

::class StaticResultRevalidator public
::method init
  expose stored
  use arg storedArg
  stored = storedArg
::method revalidate
  expose stored
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence
  return stored

::class ExplodingRevalidator public
::method revalidate
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence
  raise syntax 88.900 array('EXPLODING_REVALIDATOR_MUST_NOT_BE_CALLED')

::class AckFailOnceQueueManager public
::method init
  expose manager failed
  use arg managerArg
  manager = managerArg
  failed = .false
::method ack
  expose manager failed
  use arg queueName, packageId, claimToken, principal
  if \failed then do
    failed = .true
    return .QueueOperationResult~failure('TEST_ACK_FAILURE', packageId)
  end
  return manager~ack(queueName, packageId, claimToken, principal)
::method transferReceipt
  expose manager
  use arg transferId
  return manager~transferReceipt(transferId)

::requires 'ObjectQueueFabric.cls'
::requires 'ObjectQueueTopics.cls'
::requires '../integration/QueueFabricAuthorityExecution.cls'
::requires '../HardWorld.cls'
