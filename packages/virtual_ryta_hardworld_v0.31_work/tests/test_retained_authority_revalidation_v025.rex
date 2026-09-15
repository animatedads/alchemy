say 'RETAINED AUTHORITY REVALIDATION V0.25 START'

ledgerPath = '/tmp/ryta_retained_authority_' || .DateTime~new~microseconds || '.ledger'
queueRoot = '/tmp/ryta_retained_queue_' || .DateTime~new~microseconds
ignore = SysFileDelete(ledgerPath)

manager = .ObjectQueueManager~new(queueRoot, .QueueGraphPayloadCodec~new, 'admin')
call AssertOk manager~createQueue('Q.RETAINED', 'PERMANENT', 'AUTHORITY', 20, 'admin'), 'create retained authority queue'
topics = .QueueTopicFabric~new(manager)
call AssertOk topics~defineTopic('AUTHORITY', 'authority', 'PERMANENT', 'AUTHORITY', 'admin'), 'define authority topic'

/* Publish while nobody is listening.  Queue Fabric stores the retained event. */
payload = .table~new
payload['offer_id'] = 'OFFER-001'
payload['publisher_status'] = 'ADMISSIBLE'
publishOptions = .table~new
publishOptions['subtopic'] = 'seat/offers'
publishOptions['retain'] = .true
publishOptions['persistent'] = .true
publishOptions['correlationId'] = 'offer-001'
published = topics~publish('AUTHORITY', payload, publishOptions, 'admin')
call AssertOk published, 'publish retained authority-bearing event'
call AssertTrue published~value~retained, 'publish receipt says retained'
publicationId = published~value~publicationId

/* A late subscriber receives Queue Fabric's native retained replay marker. */
subscribed = topics~subscribe('S.AUTHORITY', 'AUTHORITY', 'seat/#', 'Q.RETAINED', 'PERMANENT', 'admin')
call AssertOk subscribed, 'late subscription'
call AssertEqual 1, manager~depth('Q.RETAINED', 'admin')~value['ready'], 'one retained replay queued'
claim = manager~claim('Q.RETAINED', 'admin')
call AssertOk claim, 'claim retained replay'
package = claim~value
claimToken = package~claimToken
call AssertEqual 1, package~headers['oqf.topic.retained'], 'native retained replay header'
call AssertEqual publicationId, package~headers['oqf.topic.publication_id'], 'native publication id preserved'

publisherSet = BuildPromotionSet('PUB-P1', 'TRUST_PUBLISHER_TIME_APPROVAL', .true, 'PUBLISHER_TIME')
world = .RYTAWorldState~new('RETAINED-AUTHORITY-WORLD')
ledger = .QueueAuthorityExecutionLedger~new(ledgerPath)

/* Direct replay of publisher-time authority is forbidden before ledger START. */
noRevalidation = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.RETAINED', package, claimToken, 'admin', publisherSet, world, 'NODE-B/RETAINED-AUTHORITY', ledger)
call AssertTrue \noRevalidation~ok, 'retained publisher authority refused without consumer revalidation'
call AssertEqual 'RETAINED_AUTHORITY_REVALIDATION_REQUIRED', noRevalidation~code, 'missing revalidation code'
call AssertEqual 'UNKNOWN', world~knowledgeOf('TRUST_PUBLISHER_TIME_APPROVAL'), 'publisher-time promotion not applied'
call AssertEqual 'NONE', ledger~stateFor(noRevalidation~workIdentity~executionKey), 'refusal occurs before ledger START'
call AssertEqual 'INFLIGHT', package~state, 'refused retained work remains claimed for caller policy'

/* A refusal from the consumer authority remains a refusal; it cannot be treated as delivery success. */
blocked = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.RETAINED', package, claimToken, 'admin', publisherSet, world, 'NODE-B/RETAINED-AUTHORITY', ledger, .nil, .BlockingConsumerRevalidator~new(publicationId))
call AssertTrue \blocked~ok, 'consumer-time blocked outcome refused'
call AssertEqual 'CONSUMER_AUTHORITY_BLOCKED', blocked~code, 'consumer block code preserved'
call AssertTrue blocked~revalidationEvidence \== .nil, 'consumer refusal evidence retained'
call AssertEqual 'UNKNOWN', world~knowledgeOf('TRUST_PUBLISHER_TIME_APPROVAL'), 'blocked revalidation still cannot apply publisher authority'

/* Receipt/event mismatch is rejected even when the revalidator says success. */
mismatch = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.RETAINED', package, claimToken, 'admin', publisherSet, world, 'NODE-B/RETAINED-AUTHORITY', ledger, .nil, .ConsumerBlockPromotionRevalidator~new('WRONG-PUBLICATION'))
call AssertTrue \mismatch~ok, 'mismatched publication refused'
call AssertEqual 'RETAINED_AUTHORITY_PUBLICATION_MISMATCH', mismatch~code, 'publication mismatch code'

/* A pass-through "revalidator" cannot simply return the publisher set object. */
passThrough = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.RETAINED', package, claimToken, 'admin', publisherSet, world, 'NODE-B/RETAINED-AUTHORITY', ledger, .nil, .PassThroughRevalidator~new(publicationId))
call AssertTrue \passThrough~ok, 'pass-through publisher set refused'
call AssertEqual 'RETAINED_AUTHORITY_REUSED_PUBLISHER_PROMOTION_SET', passThrough~code, 'publisher set reuse code'

/* A copied object with the same canonical publisher authority is equally stale. */
semanticCopy = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.RETAINED', package, claimToken, 'admin', publisherSet, world, 'NODE-B/RETAINED-AUTHORITY', ledger, .nil, .SemanticCopyRevalidator~new(publicationId))
call AssertTrue \semanticCopy~ok, 'semantic copy of publisher set refused'
call AssertEqual 'RETAINED_AUTHORITY_REUSED_PUBLISHER_PROMOTION_SEMANTICS', semanticCopy~code, 'publisher semantic reuse code'

/* Real consumer-time revalidation supplies a distinct sealed set. */
revalidator = .ConsumerBlockPromotionRevalidator~new(publicationId)
revalidated = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.RETAINED', package, claimToken, 'admin', publisherSet, world, 'NODE-B/RETAINED-AUTHORITY', ledger, .nil, revalidator)
call AssertTrue revalidated~ok, 'consumer-time revalidated retained work executes'
call AssertEqual 'APPLIED_AND_ACKED', revalidated~code, 'revalidated result code'
call AssertTrue revalidated~revalidationEvidence \== .nil, 'consumer-time evidence retained on result'
call AssertEqual publicationId, revalidated~revalidationEvidence~publicationId, 'result evidence bound to retained publication'
call AssertEqual 'CONSUMER-CONTEXT-2026-08-22', revalidated~revalidationEvidence~consumerContextIdentity, 'consumer context identity retained'
call AssertEqual 'TEST-CONSUMER-REVALIDATOR/1', revalidated~revalidationEvidence~revalidatorIdentity, 'revalidator identity retained'
call AssertEqual 'UNKNOWN', world~knowledgeOf('TRUST_PUBLISHER_TIME_APPROVAL'), 'publisher-time approval never applied'
call AssertTrue world~isKnownTrue('CONSUMER_TIME_BLOCK_REQUIRED'), 'consumer-time promotion applied instead'
call AssertEqual 'ACKED', package~state, 'revalidated retained package acknowledged'

/* Alchemy identity stays evidence only; it does not enter canonical revalidation identity. */
r1 = .ConsumerBlockPromotionRevalidator~new(publicationId)~buildResult
r2 = .ConsumerBlockPromotionRevalidator~new(publicationId)~buildResult
call AssertTrue r1~alchemyObjectId \== r2~alchemyObjectId, 'revalidation Alchemy ids are per object'
call AssertEqual r1~algorithmCanonicalText, r2~algorithmCanonicalText, 'Alchemy object id excluded from revalidation canonical identity'

/* Live topic delivery is not a retained replay and remains backward-compatible. */
call AssertOk manager~createQueue('Q.LIVE', 'TEMPORARY', 'AUTHORITY', 20, 'admin'), 'create live queue'
call AssertOk topics~subscribe('S.LIVE', 'AUTHORITY', 'live/#', 'Q.LIVE', 'TEMPORARY', 'admin'), 'live subscription'
liveOptions = .table~new
liveOptions['subtopic'] = 'live/now'
livePublished = topics~publish('AUTHORITY', 'live', liveOptions, 'admin')
call AssertOk livePublished, 'live publish'
liveClaim = manager~claim('Q.LIVE', 'admin')
call AssertOk liveClaim, 'claim live publication'
livePackage = liveClaim~value
call AssertEqual 0, livePackage~headers['oqf.topic.retained'], 'live package is not retained replay'
liveSet = BuildPromotionSet('LIVE-P1', 'LIVE_QUEUE_AUTHORITY_APPLIED', .true, 'LIVE_CONSUMER')
liveWorld = .RYTAWorldState~new('LIVE-AUTHORITY-WORLD')
liveResult = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.LIVE', livePackage, livePackage~claimToken, 'admin', liveSet, liveWorld, 'NODE-B/LIVE-AUTHORITY', ledger)
call AssertTrue liveResult~ok, 'live queue authority remains compatible without retained revalidator'
call AssertTrue liveWorld~isKnownTrue('LIVE_QUEUE_AUTHORITY_APPLIED'), 'live promotion applied'

ignore = SysFileDelete(ledgerPath)
say 'RETAINED AUTHORITY REVALIDATION V0.25: OK'
exit 0

::routine BuildPromotionSet
  use arg promotionId, targetFact, value, sourcePhase
  promotion = .EvidencePromotion~new(promotionId, 'QUEUE_RETAINED_' || sourcePhase, 'SRC-' || promotionId || '-' || sourcePhase, targetFact, 'KNOWN', value, 'TEST_AUTHORITY', 'TEST_POLICY', 'TEST_RULE', 'REQUIRED', 'AUTHORIZED')
  promotionSet = .EvidencePromotionSet~new
  if \promotionSet~add(promotion) then raise syntax 88.900 array('could not add promotion ' || promotionId)
  ignored = promotionSet~seal
  return promotionSet

::routine AssertOk
  use arg operationResult, label
  if operationResult == .nil then raise syntax 88.900 array('ASSERT OK FAILED: ' || label || ' nil result')
  if \operationResult~ok then raise syntax 88.900 array('ASSERT OK FAILED: ' || label || ' code=' || operationResult~code || ' detail=' || operationResult~detail)
  return 0

::routine AssertTrue
  use arg condition, label
  if \condition then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0

::routine AssertEqual
  use arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::class BlockingConsumerRevalidator public
::attribute publicationId get
::method init
  expose publicationId
  use arg publicationIdArg
  publicationId = publicationIdArg~string
::method revalidate
  expose publicationId
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence
  evidence = .directory~new
  evidence['publisher_promotion_text'] = publisherPromotionSet~algorithmCanonicalText
  evidence['delivery_count'] = attemptEvidence~deliveryCount
  return .QueueAuthorityRevalidationResult~failure('CONSUMER_AUTHORITY_BLOCKED', 'consumer-time policy prohibits action', publicationId, 'CONSUMER-CONTEXT-2026-08-22', 'TEST-CONSUMER-REVALIDATOR/1', evidence)

::class ConsumerBlockPromotionRevalidator public
::attribute publicationId get
::method init
  expose publicationId
  use arg publicationIdArg
  publicationId = publicationIdArg~string
::method buildResult
  expose publicationId
  use arg workExecutionKey = '', attemptIdentity = ''
  currentSet = BuildConsumerPromotionSet()
  evidence = .directory~new
  evidence['assessment'] = 'BLOCKED'
  evidence['phase'] = 'CONSUMER_TIME'
  return .QueueAuthorityRevalidationResult~success(currentSet, publicationId, 'CONSUMER-CONTEXT-2026-08-22', 'TEST-CONSUMER-REVALIDATOR/1', evidence, '', '', workExecutionKey, attemptIdentity)
::method revalidate
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence
  attemptIdentity = .QueueAuthorityPromotionExecutor~attemptIdentity(attemptEvidence)
  return self~buildResult(workIdentity~executionKey, attemptIdentity)

::class PassThroughRevalidator public
::attribute publicationId get
::method init
  expose publicationId
  use arg publicationIdArg
  publicationId = publicationIdArg~string
::method revalidate
  expose publicationId
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence
  attemptIdentity = .QueueAuthorityPromotionExecutor~attemptIdentity(attemptEvidence)
  return .QueueAuthorityRevalidationResult~success(publisherPromotionSet, publicationId, 'CONSUMER-CONTEXT-2026-08-22', 'TEST-PASS-THROUGH/1', .nil, '', '', workIdentity~executionKey, attemptIdentity)

::class SemanticCopyRevalidator public
::attribute publicationId get
::method init
  expose publicationId
  use arg publicationIdArg
  publicationId = publicationIdArg~string
::method revalidate
  expose publicationId
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence
  copiedPublisherSet = BuildPromotionSet('PUB-P1', 'TRUST_PUBLISHER_TIME_APPROVAL', .true, 'PUBLISHER_TIME')
  attemptIdentity = .QueueAuthorityPromotionExecutor~attemptIdentity(attemptEvidence)
  return .QueueAuthorityRevalidationResult~success(copiedPublisherSet, publicationId, 'CONSUMER-CONTEXT-2026-08-22', 'TEST-SEMANTIC-COPY/1', .nil, '', '', workIdentity~executionKey, attemptIdentity)

::routine BuildConsumerPromotionSet
  promotion = .EvidencePromotion~new('CONSUMER-P1', 'QUEUE_RETAINED_CONSUMER_TIME', 'CONSUMER-AUTHORITY-2026-08-22', 'CONSUMER_TIME_BLOCK_REQUIRED', 'KNOWN', .true, 'TEST_CONSUMER_AUTHORITY', 'TEST_POLICY_CURRENT', 'TEST_RULE_CURRENT', 'REQUIRED', 'AUTHORIZED')
  promotionSet = .EvidencePromotionSet~new
  if \promotionSet~add(promotion) then raise syntax 88.900 array('could not add consumer promotion')
  ignored = promotionSet~seal
  return promotionSet

::requires 'ObjectQueueFabric.cls'
::requires 'ObjectQueueTopics.cls'
::requires '../integration/QueueFabricAuthorityExecution.cls'
::requires '../HardWorld.cls'
