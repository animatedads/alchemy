say 'LEGAL V0.10 LEDGER AUTH V0.27 START'
call main
exit 0

main:
  legalRoot = value('LEGAL_EFFECT_ROOT',, 'ENVIRONMENT')
  runtimeRoot = value('RUNTIME_REGISTRY_ROOT',, 'ENVIRONMENT')
  cryptoSrc = value('OOREXX_CRYPTO_SRC',, 'ENVIRONMENT')
  if cryptoSrc = '' then cryptoSrc = value('CRYPTO_SRC',, 'ENVIRONMENT')
  if legalRoot = '' then raise syntax 88.900 array('LEGAL_EFFECT_ROOT required')
  if runtimeRoot = '' then raise syntax 88.900 array('RUNTIME_REGISTRY_ROOT required')
  if cryptoSrc = '' then raise syntax 88.900 array('OOREXX_CRYPTO_SRC or CRYPTO_SRC required')

  /* Build and acquire the current Legal Effect v0.10 runtime exactly as the native adapter test does. */
  builder = .RuntimeBundleBuilder~new
  call MustOk builder~addFile(legalRoot || '/src/LegalEffect.cls', 'LegalEffect.cls'), 'add LegalEffect'
  call MustOk builder~addFile(legalRoot || '/src/LegalRuntimeCryptoBridge.cls', 'LegalRuntimeCryptoBridge.cls'), 'add crypto bridge'
  call MustOk builder~addFile(cryptoSrc || '/crypto.cls', 'crypto.cls'), 'add standalone crypto'
  call MustOk builder~addFile(legalRoot || '/tests/fixtures/DemoLegalRules_v1.cls', 'DemoLegalRules_v1.cls'), 'add legal fixture'
  built = builder~build
  call MustOk built, 'build legal runtime closure'
  bundle = built~value

  verifier = .RuntimePinnedSourceVerifier~new
  artifactId = 'hardworld-v027:legal-effect-v010:ledger-auth'
  call MustOk verifier~pin(artifactId, bundle~sourceLines), 'pin legal runtime closure'
  artifact = .RuntimeArtifact~new('legal.effect.v010.retained', 'LEGAL_RULES', '0.10', artifactId, 'DemoLegalRules', bundle~sourceLines, .LegalEffectBuild~API_VERSION, 'hardworld-v027-ledger-auth-proof')
  kernel = .RuntimeKernel~new(verifier)
  staged = kernel~stage('prod', artifact)
  call MustOk staged, 'stage legal runtime closure'
  call MustOk kernel~activate('prod', artifact~moduleId, staged~value~generationId), 'activate legal runtime closure'

  trustProfile = .LegalAuthorityTestSupport~trustProfile
  authorityVerifier = .LegalAuthorityTestSupport~verifier
  acquired = .LegalRuntimeRuleResolver~new~acquire(kernel, 'prod', artifact~moduleId, trustProfile, authorityVerifier)
  call MustOk acquired, 'acquire v0.10 legal runtime lease'
  legalLease = acquired~value

  consumerContext = .LegalContext~new('RETAINED-CONSUMER-2026-08-23', '2026-08-23')
  ignored = consumerContext~bindSource('DEMO-CONTRACT', 'retained consumer-time legal proof')
  action = .LegalAction~new('RATE_CHANGE', 'synthetic rate change')
  ignored = action~setFact('RATE_CHANGE', .true)
  /* Do not precompute the authority envelope here. The retained revalidator must
     execute both the pinned and runtime-bound Legal evaluations at consumption. */

  /* Queue a retained replay carrying stale publisher-time authority evidence. */
  queueRoot = '/tmp/ryta_legal_retained_' || .DateTime~new~microseconds
  ledgerPath = '/tmp/ryta_legal_retained_' || .DateTime~new~microseconds || '.ledger'
  ignore = SysFileDelete(ledgerPath)
  manager = .ObjectQueueManager~new(queueRoot, .QueueGraphPayloadCodec~new, 'admin')
  call MustOk manager~createQueue('Q.LEGAL', 'PERMANENT', 'AUTHORITY', 20, 'admin'), 'create legal queue'
  topics = .QueueTopicFabric~new(manager)
  call MustOk topics~defineTopic('LEGAL', 'legal', 'PERMANENT', 'AUTHORITY', 'admin'), 'define legal topic'
  publishOptions = .table~new
  publishOptions['subtopic'] = 'offers/rate-change'
  publishOptions['retain'] = .true
  publishOptions['persistent'] = .true
  publishOptions['correlationId'] = 'legal-retained-1'
  published = topics~publish('LEGAL', 'publisher-time-admissible', publishOptions, 'admin')
  call MustOk published, 'publish retained event'
  publicationId = published~value~publicationId
  call MustOk manager~createQueue('Q.LEGAL.CONSUMER', 'PERMANENT', 'AUTHORITY', 20, 'admin'), 'create consumer queue'
  call MustOk topics~subscribe('S.LEGAL.CONSUMER', 'LEGAL', 'offers/#', 'Q.LEGAL.CONSUMER', 'PERMANENT', 'admin'), 'late consumer subscription'
  claim = manager~claim('Q.LEGAL.CONSUMER', 'admin')
  call MustOk claim, 'claim retained legal event'
  package = claim~value
  call AssertEqual 1, package~headers['oqf.topic.retained'], 'Queue Fabric marks retained replay'
  call AssertEqual publicationId, package~headers['oqf.topic.publication_id'], 'publication identity preserved'

  publisherSet = PublisherPromotionSet()
  world = .RYTAWorldState~new('LEGAL-RETAINED-CONSUMER-WORLD')
  ledgerRing = .CryptoMacKeyRing~new
  ignored = ledgerRing~addSipHash128Key('legal-ledger-k1', '202122232425262728292a2b2c2d2e2f')
  ignored = ledgerRing~activate('legal-ledger-k1')
  ledger = .QueueAuthorityExecutionLedger~new(ledgerPath, ledgerRing)

  withoutCurrent = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.LEGAL.CONSUMER', package, package~claimToken, 'admin', publisherSet, world, 'NODE-B/LEGAL-RETAINED', ledger)
  call AssertTrue \withoutCurrent~ok, 'stale publisher promotions cannot execute directly'
  call AssertEqual 'RETAINED_AUTHORITY_REVALIDATION_REQUIRED', withoutCurrent~code, 'consumer-time Legal revalidation required'
  call AssertEqual 'UNKNOWN', world~knowledgeOf('PUBLISHER_TIME_LEGAL_APPROVAL'), 'stale publisher approval not applied'

  legalRevalidator = .LegalEffectV010RetainedAuthorityRevalidator~new(.LegalEffectEngine~new, legalLease, action, consumerContext)
  executionResult = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.LEGAL.CONSUMER', package, package~claimToken, 'admin', publisherSet, world, 'NODE-B/LEGAL-RETAINED', ledger, .nil, legalRevalidator)
  call AssertTrue executionResult~ok, 'native Legal Effect v0.10 consumer-time revalidation executes'
  call AssertTrue executionResult~revalidationEvidence \== .nil, 'Legal consumer-time revalidation evidence retained'
  call AssertEqual publicationId, executionResult~revalidationEvidence~publicationId, 'Legal revalidation bound to queue publication'
  call AssertTrue world~isKnownTrue('LEGAL_ACTION_BLOCKED'), 'current Legal Effect blocked fact applied'
  call AssertEqual 'UNKNOWN', world~knowledgeOf('PUBLISHER_TIME_LEGAL_APPROVAL'), 'publisher-time approval remains evidence-only'
  call AssertEqual 'ACKED', package~state, 'retained legal event acknowledged after current authority applied'

  appliedBlocked = world~fact('LEGAL_ACTION_BLOCKED')
  call AssertTrue appliedBlocked \== .nil, 'blocked world fact exists'
  call AssertTrue appliedBlocked~authority~pos('LEGAL_EFFECT/0.10/') == 1, 'consumer fact carries native v0.10 authority namespace'
  call AssertTrue appliedBlocked~authority~pos('+sourceauth:') > 0, 'consumer fact authority includes host source-authority closure'

  /* v0.26: authority was valid and the HardWorld mutation completed, but ACK
     failed.  A later transport retry must not need to mint new Legal authority. */
  call MustOk topics~defineTopic('LEGAL.ACKRECOVERY', 'legal ack recovery', 'PERMANENT', 'AUTHORITY', 'admin'), 'define ack-recovery topic'
  ackOptions = .table~new
  ackOptions['subtopic'] = 'offers/rate-change'
  ackOptions['retain'] = .true
  ackOptions['persistent'] = .true
  ackPublished = topics~publish('LEGAL.ACKRECOVERY', 'publisher-time-ack-recovery', ackOptions, 'admin')
  call MustOk ackPublished, 'publish ack-recovery retained event'
  call MustOk manager~createQueue('Q.LEGAL.ACKRECOVERY', 'PERMANENT', 'AUTHORITY', 20, 'admin'), 'create ack-recovery queue'
  call MustOk topics~subscribe('S.LEGAL.ACKRECOVERY', 'LEGAL.ACKRECOVERY', 'offers/#', 'Q.LEGAL.ACKRECOVERY', 'PERMANENT', 'admin'), 'late ack-recovery subscription'
  ackClaim1 = manager~claim('Q.LEGAL.ACKRECOVERY', 'admin')
  call MustOk ackClaim1, 'claim ack-recovery attempt 1'
  ackPackage1 = ackClaim1~value
  ackToken1 = ackPackage1~claimToken
  ackWorld = .RYTAWorldState~new('LEGAL-RETAINED-ACK-RECOVERY-WORLD')
  ackManager = .AckFailOnceQueueManager~new(manager)
  ackRevalidator = .LegalEffectV010RetainedAuthorityRevalidator~new(.LegalEffectEngine~new, legalLease, action, consumerContext)
  ackFirst = .QueueAuthorityPromotionExecutor~execute(ackManager, 'Q.LEGAL.ACKRECOVERY', ackPackage1, ackToken1, 'admin', publisherSet, ackWorld, 'NODE-B/LEGAL-ACKRECOVERY', ledger, .nil, ackRevalidator)
  call AssertTrue \ackFirst~ok, 'injected ACK failure reported after Legal application'
  call AssertEqual 'ACK_FAILED_AFTER_COMPLETE', ackFirst~code, 'Legal side effect completed before ACK failure'
  call AssertTrue ackWorld~isKnownTrue('LEGAL_ACTION_BLOCKED'), 'Legal authority-bearing mutation completed'
  call AssertEqual 'COMPLETE', ledger~stateFor(ackFirst~workIdentity~executionKey), 'authenticated ledger durable COMPLETE recorded'
  call AssertEqual 'V3', ledger~recordVersionFor(ackFirst~workIdentity~executionKey), 'Legal completed work recorded as V3'
  call AssertTrue ledger~trustedRecordFor(ackFirst~workIdentity~executionKey), 'Legal completed V3 record authenticated'
  legalLedgerCheckpoint = ledger~chainCheckpointText
  call AssertEqual 'INFLIGHT', ackPackage1~state, 'package remains inflight after failed ACK'

  /* Remove the authority source after completion.  It must block new work, but
     it must not prevent ACK-only cleanup of work already durably COMPLETE. */
  call MustOk legalLease~release, 'release legal runtime lease after completed mutation'
  call MustOk manager~release('Q.LEGAL.ACKRECOVERY', ackPackage1~packageId, ackToken1, 'admin', 'transport retry after complete'), 'release completed package for redelivery'
  ackClaim2 = manager~claim('Q.LEGAL.ACKRECOVERY', 'admin')
  call MustOk ackClaim2, 'claim ack-recovery attempt 2'
  ackPackage2 = ackClaim2~value
  call AssertEqual 2, ackPackage2~deliveryCount, 'ack recovery is a new delivery attempt'
  restartedLedger = .QueueAuthorityExecutionLedger~new(ledgerPath, ledgerRing, legalLedgerCheckpoint)
  revokedRevalidator = .LegalEffectV010RetainedAuthorityRevalidator~new(.LegalEffectEngine~new, legalLease, action, consumerContext)
  ackRecovered = .QueueAuthorityPromotionExecutor~execute(ackManager, 'Q.LEGAL.ACKRECOVERY', ackPackage2, ackPackage2~claimToken, 'admin', publisherSet, ackWorld, 'NODE-B/LEGAL-ACKRECOVERY', restartedLedger, .nil, revokedRevalidator)
  call AssertTrue ackRecovered~ok, 'released authority does not block transport-only ACK recovery'
  call AssertEqual 'ALREADY_COMPLETE_ACKED', ackRecovered~code, 'Legal ACK-only recovery code'
  call AssertTrue ackRecovered~replaySuppressed, 'Legal mutation not replayed'
  call AssertTrue ackRecovered~revalidationEvidence == .nil, 'ACK-only recovery mints no new Legal revalidation evidence'
  call AssertTrue ackRecovered~applyResult == .nil, 'ACK-only recovery performs no new HardWorld apply'
  call AssertEqual 'ACKED', ackPackage2~state, 'completed package finally acknowledged'

  /* Prove the revalidator does not cache the successful envelope: a second
     retained replay after lease release must fail at the live Legal call. */
  call MustOk topics~defineTopic('LEGAL.RELEASED', 'legal released lease', 'PERMANENT', 'AUTHORITY', 'admin'), 'define released-lease topic'
  releasedOptions = .table~new
  releasedOptions['subtopic'] = 'offers/rate-change'
  releasedOptions['retain'] = .true
  releasedOptions['persistent'] = .true
  releasedPublished = topics~publish('LEGAL.RELEASED', 'publisher-time-admissible-2', releasedOptions, 'admin')
  call MustOk releasedPublished, 'publish second retained event'
  call MustOk manager~createQueue('Q.LEGAL.RELEASED', 'PERMANENT', 'AUTHORITY', 20, 'admin'), 'create released-lease consumer queue'
  call MustOk topics~subscribe('S.LEGAL.RELEASED', 'LEGAL.RELEASED', 'offers/#', 'Q.LEGAL.RELEASED', 'PERMANENT', 'admin'), 'late released-lease subscription'
  releasedClaim = manager~claim('Q.LEGAL.RELEASED', 'admin')
  call MustOk releasedClaim, 'claim released-lease retained event'
  releasedPackage = releasedClaim~value
  call AssertEqual 1, releasedPackage~headers['oqf.topic.retained'], 'released-lease case is retained replay'

  releasedWorld = .RYTAWorldState~new('LEGAL-RETAINED-RELEASED-LEASE-WORLD')
  releasedRevalidator = .LegalEffectV010RetainedAuthorityRevalidator~new(.LegalEffectEngine~new, legalLease, action, consumerContext)
  releasedExecution = .QueueAuthorityPromotionExecutor~execute(manager, 'Q.LEGAL.RELEASED', releasedPackage, releasedPackage~claimToken, 'admin', publisherSet, releasedWorld, 'NODE-B/LEGAL-RETAINED', restartedLedger, .nil, releasedRevalidator)
  call AssertTrue \releasedExecution~ok, 'released Legal lease cannot authorize retained replay'
  call AssertEqual 'LEGAL_RETAINED_LIVE_EVALUATION_REFUSED', releasedExecution~code, 'released lease refusal comes from fresh live evaluation'
  call AssertTrue releasedExecution~detail~pos('LEGAL_LEASE_RELEASED') > 0, 'released lease detail preserved'
  call AssertEqual 'UNKNOWN', releasedWorld~knowledgeOf('PUBLISHER_TIME_LEGAL_APPROVAL'), 'released lease cannot revive publisher approval'
  call AssertEqual 'INFLIGHT', releasedPackage~state, 'released-lease refusal remains unacked'
  call AssertEqual 'NONE', restartedLedger~stateFor(releasedExecution~workIdentity~executionKey), 'released-lease refusal occurs before ledger START'

  ignore = SysFileDelete(ledgerPath)
  say '  publication=' || publicationId
  say '  consumer_context_identity=' || executionResult~revalidationEvidence~consumerContextIdentity
  say '  applied_authority=' || appliedBlocked~authority
  say 'LEGAL V0.10 LEDGER AUTH V0.27: OK'
  return

::routine PublisherPromotionSet
  p = .EvidencePromotion~new('PUBLISHER-LEGAL-P1', 'LEGAL_EFFECT_PUBLISHER_TIME', 'PUBLISHER-ASSESSMENT-2026-08-20', 'PUBLISHER_TIME_LEGAL_APPROVAL', 'KNOWN', .true, 'HISTORICAL_PUBLISHER_AUTHORITY', 'PUBLISHER_POLICY', 'PUBLISHER_RULE', 'PERMITTED', 'AUTHORIZED')
  s = .EvidencePromotionSet~new
  if \s~add(p) then raise syntax 88.900 array('could not create publisher promotion set')
  ignored = s~seal
  return s

::routine MustOk
  use arg object, label
  if object == .nil then raise syntax 88.900 array(label || ': nil result')
  if \object~ok then raise syntax 88.900 array(label || ': ' || object~code || ' ' || object~detail)
  return

::routine AssertTrue
  use arg conditionValue, label
  if \conditionValue then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return

::routine AssertEqual
  use arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return

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

::requires 'crypto.cls'
::requires 'ObjectQueueFabric.cls'
::requires 'ObjectQueueTopics.cls'
::requires 'LegalRuntimeCryptoBridge.cls'
::requires 'RuntimeRegistry.cls'
::requires 'RuntimeBundleBuilder.cls'
::requires 'LegalEffectAuthorityTestSupport.cls'
::requires '../integration/LegalEffectV010RetainedAuthorityRevalidator.cls'
::requires '../HardWorld.cls'
