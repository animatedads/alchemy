say 'QUEUE AUTHORITY EXECUTION V0.21 START'
ledgerPath = '/tmp/ryta_queue_authority_' || .DateTime~new~microseconds || '.ledger'
ignore = SysFileDelete(ledgerPath)
ledger = .QueueAuthorityExecutionLedger~new(ledgerPath)
manager = .ObjectQueueManager~new('', .nil, 'admin')
call AssertOk manager~createQueue('AUTH', 'TEMPORARY', 'AUTHORITY', 50, 'admin'), 'create AUTH queue'
call AssertOk manager~createQueue('TRANSFERQ', 'TEMPORARY', 'AUTHORITY', 50, 'admin'), 'create TRANSFERQ queue'

/* Normal local work: START -> apply -> COMPLETE -> ACK. */
localSet = BuildPromotionSet('LOCAL-P1', 'QUEUE_LOCAL_APPLIED', .true)
putLocal = manager~put('AUTH', 'local-work', .nil, 'admin')
call AssertOk putLocal, 'put local work'
claimLocal = manager~claim('AUTH', 'admin')
call AssertOk claimLocal, 'claim local work'
localPackage = claimLocal~value
localToken = localPackage~claimToken
world = .RYTAWorldState~new('QUEUE-AUTHORITY-WORLD')
localResult = .QueueAuthorityPromotionExecutor~execute(manager, 'AUTH', localPackage, localToken, 'admin', localSet, world, 'NODE-A/AUTHORITY', ledger)
call AssertTrue localResult~ok, 'local execution succeeds'
call AssertEqual 'APPLIED_AND_ACKED', localResult~code, 'local result code'
call AssertTrue world~isKnownTrue('QUEUE_LOCAL_APPLIED'), 'local promotion applied'
call AssertEqual 'COMPLETE', ledger~stateFor(localResult~workIdentity~executionKey), 'local ledger complete'
call AssertEqual 0, manager~depth('AUTH', 'admin')~value['total'], 'local package acknowledged'
call AssertEqual 1, localResult~attemptEvidence~deliveryCount, 'delivery count retained'
call AssertEqual 'admin', localResult~attemptEvidence~claimedBy, 'claim principal retained'
call AssertTrue \localResult~attemptEvidence~hasMethod('PACKAGEOBJECT'), 'claimed package object not retained in attempt evidence'
call AssertTrue \localResult~hasMethod('ACKRESULT'), 'raw Queue Fabric ack result not retained'
call AssertEqual 'OK', localResult~ackCode, 'safe ACK code retained'

/* A stable transport key cannot be silently rebound to different authority work. */
changedSet = BuildPromotionSet('LOCAL-P2', 'QUEUE_LOCAL_DIFFERENT', .true)
changedFingerprint = .QueueAuthorityPromotionExecutor~workFingerprint(localResult~workIdentity, changedSet)
conflictDecision = ledger~begin(localResult~workIdentity~executionKey, changedFingerprint, localResult~attemptEvidence)
call AssertTrue \conflictDecision~ok, 'same stable work id cannot change promotion content'
call AssertEqual 'WORK_IDENTITY_CONFLICT', conflictDecision~code, 'work identity conflict code'

/* START without COMPLETE is deliberately uncertain after restart and never replayed. */
uncertainSet = BuildPromotionSet('UNCERTAIN-P1', 'QUEUE_UNCERTAIN_MUST_NOT_APPLY', .true)
call AssertOk manager~put('AUTH', 'uncertain-work', .nil, 'admin'), 'put uncertain work'
claimUncertain = manager~claim('AUTH', 'admin')
call AssertOk claimUncertain, 'claim uncertain work'
uncertainPackage = claimUncertain~value
uncertainToken = uncertainPackage~claimToken
uncertainIdentity = .QueueAuthorityWorkIdentity~new('NODE-A/AUTHORITY', 'AUTH', uncertainPackage~packageId, 'LOCAL', '', '', uncertainPackage~parentPackageId, uncertainPackage~requestedQueue, uncertainPackage~createdAt, uncertainPackage~priority, uncertainPackage~persistent, uncertainPackage~securityDomain, uncertainPackage~routingKey, uncertainPackage~correlationId, uncertainPackage~replyTo, '')
uncertainAttempt = .QueueAuthorityAttemptEvidence~new(uncertainIdentity, uncertainPackage)
uncertainFingerprint = .QueueAuthorityPromotionExecutor~workFingerprint(uncertainIdentity, uncertainSet)
call AssertEqual 'STARTED', ledger~begin(uncertainIdentity~executionKey, uncertainFingerprint, uncertainAttempt)~code, 'manual START recorded'
restartedLedger = .QueueAuthorityExecutionLedger~new(ledgerPath)
uncertainWorld = .RYTAWorldState~new('QUEUE-UNCERTAIN-WORLD')
uncertainResult = .QueueAuthorityPromotionExecutor~execute(manager, 'AUTH', uncertainPackage, uncertainToken, 'admin', uncertainSet, uncertainWorld, 'NODE-A/AUTHORITY', restartedLedger)
call AssertTrue \uncertainResult~ok, 'uncertain replay refused'
call AssertEqual 'PREVIOUS_EXECUTION_UNCERTAIN', uncertainResult~code, 'uncertain replay code'
call AssertEqual 'UNKNOWN', uncertainWorld~knowledgeOf('QUEUE_UNCERTAIN_MUST_NOT_APPLY'), 'uncertain work not applied'
call AssertEqual 'INFLIGHT', uncertainPackage~state, 'uncertain work not acknowledged'
call AssertOk manager~ack('AUTH', uncertainPackage~packageId, uncertainToken, 'admin'), 'operator cleanup acknowledges uncertain package'

/* COMPLETE before ACK is safe to replay: suppress promotion and ACK the package. */
replaySet = BuildPromotionSet('REPLAY-P1', 'QUEUE_REPLAY_MUST_NOT_APPLY', .true)
call AssertOk manager~put('AUTH', 'completed-before-ack', .nil, 'admin'), 'put replay package'
claimReplay = manager~claim('AUTH', 'admin')
call AssertOk claimReplay, 'claim replay package'
replayPackage = claimReplay~value
replayToken = replayPackage~claimToken
replayIdentity = .QueueAuthorityWorkIdentity~new('NODE-A/AUTHORITY', 'AUTH', replayPackage~packageId, 'LOCAL', '', '', replayPackage~parentPackageId, replayPackage~requestedQueue, replayPackage~createdAt, replayPackage~priority, replayPackage~persistent, replayPackage~securityDomain, replayPackage~routingKey, replayPackage~correlationId, replayPackage~replyTo, '')
replayAttempt = .QueueAuthorityAttemptEvidence~new(replayIdentity, replayPackage)
replayFingerprint = .QueueAuthorityPromotionExecutor~workFingerprint(replayIdentity, replaySet)
call AssertEqual 'STARTED', restartedLedger~begin(replayIdentity~executionKey, replayFingerprint, replayAttempt)~code, 'replay START recorded'
call AssertEqual 'COMPLETED', restartedLedger~complete(replayIdentity~executionKey, replayFingerprint, replayAttempt)~code, 'replay COMPLETE recorded before ACK'
replayWorld = .RYTAWorldState~new('QUEUE-REPLAY-WORLD')
replayResult = .QueueAuthorityPromotionExecutor~execute(manager, 'AUTH', replayPackage, replayToken, 'admin', replaySet, replayWorld, 'NODE-A/AUTHORITY', restartedLedger)
call AssertTrue replayResult~ok, 'completed replay succeeds'
call AssertEqual 'ALREADY_COMPLETE_ACKED', replayResult~code, 'completed replay code'
call AssertTrue replayResult~replaySuppressed, 'completed replay reports suppression'
call AssertEqual 'UNKNOWN', replayWorld~knowledgeOf('QUEUE_REPLAY_MUST_NOT_APPLY'), 'completed replay does not apply promotion again'
call AssertEqual 0, manager~depth('AUTH', 'admin')~value['inflight'], 'completed replay acknowledged'

/* Queue Fabric transfer receipt becomes the stable transport identity. */
transferOptions = .table~new
transferOptions['sourceManager'] = 'MANAGER-A'
transferOptions['sourceQueue'] = 'OUTBOUND'
transferOptions['sourcePackageId'] = 'SRC-PKG-001'
accepted = manager~acceptTransfer('TRANSFER-001', 'TRANSFERQ', 'transferred-work', transferOptions, 'admin')
call AssertOk accepted, 'accept transfer'
receipt = accepted~value
claimTransfer = manager~claim('TRANSFERQ', 'admin')
call AssertOk claimTransfer, 'claim transferred package'
transferPackage = claimTransfer~value
transferToken = transferPackage~claimToken
transferSet = BuildPromotionSet('TRANSFER-P1', 'QUEUE_TRANSFER_APPLIED', .true)
transferWorld = .RYTAWorldState~new('QUEUE-TRANSFER-WORLD')
transferResult = .QueueAuthorityPromotionExecutor~execute(manager, 'TRANSFERQ', transferPackage, transferToken, 'admin', transferSet, transferWorld, 'NODE-B/AUTHORITY', restartedLedger, receipt)
call AssertTrue transferResult~ok, 'transfer execution succeeds'
call AssertEqual 'TRANSFER', transferResult~workIdentity~transportKind, 'transfer identity kind'
call AssertEqual 'TRANSFER-001', transferResult~workIdentity~transferId, 'native transfer id retained'
call AssertEqual 'MANAGER-A', transferResult~workIdentity~sourceManager, 'source manager retained'
call AssertEqual 'SRC-PKG-001', transferResult~workIdentity~parentPackageId, 'source package retained through parent package id'
call AssertEqual 'OUTBOUND', transferResult~workIdentity~requestedQueue, 'Queue Fabric requestedQueue snapshot retains source queue supplied to acceptTransfer'
call AssertTrue transferResult~workIdentity~packageCreatedAt \= '', 'package creation time snapshotted'
call AssertTrue transferResult~workIdentity~transferAcceptedAt \= '', 'transfer acceptance time snapshotted'
call AssertEqual 'AUTHORITY', transferResult~workIdentity~securityDomain, 'security domain snapshotted'
call AssertTrue transferWorld~isKnownTrue('QUEUE_TRANSFER_APPLIED'), 'transfer promotion applied'
duplicateTransfer = manager~acceptTransfer('TRANSFER-001', 'TRANSFERQ', 'transferred-work', transferOptions, 'admin')
call AssertOk duplicateTransfer, 'duplicate transfer accepted idempotently'
call AssertTrue duplicateTransfer~value~duplicate, 'duplicate receipt marked duplicate'
call AssertEqual receipt~packageId, duplicateTransfer~value~packageId, 'duplicate transfer returns original destination package identity'
call AssertEqual 0, manager~depth('TRANSFERQ', 'admin')~value['total'], 'duplicate transfer does not reinsert acknowledged package'

/* A receipt cannot be attached to a different claimed package. */
accepted2 = manager~acceptTransfer('TRANSFER-002', 'TRANSFERQ', 'mismatch-work', transferOptions, 'admin')
call AssertOk accepted2, 'accept second transfer'
claimMismatch = manager~claim('TRANSFERQ', 'admin')
call AssertOk claimMismatch, 'claim second transfer'
mismatchPackage = claimMismatch~value
mismatchToken = mismatchPackage~claimToken
fakeReceipt = .QueueTransferReceipt~new('TRANSFER-002', 'WRONG-PACKAGE', 'TRANSFERQ', accepted2~value~acceptedAt, 'MANAGER-A', .false)
mismatchSet = BuildPromotionSet('MISMATCH-P1', 'QUEUE_MISMATCH_MUST_NOT_APPLY', .true)
mismatchWorld = .RYTAWorldState~new('QUEUE-MISMATCH-WORLD')
mismatchResult = .QueueAuthorityPromotionExecutor~execute(manager, 'TRANSFERQ', mismatchPackage, mismatchToken, 'admin', mismatchSet, mismatchWorld, 'NODE-B/AUTHORITY', restartedLedger, fakeReceipt)
call AssertTrue \mismatchResult~ok, 'mismatched receipt refused'
call AssertEqual 'TRANSFER_RECEIPT_REGISTRY_MISMATCH', mismatchResult~code, 'mismatched receipt code'
call AssertEqual 'UNKNOWN', mismatchWorld~knowledgeOf('QUEUE_MISMATCH_MUST_NOT_APPLY'), 'mismatched receipt cannot apply authority'

/* The receipt-shaped object itself is not trusted unless Queue Fabric registered it. */
unregisteredReceipt = .QueueTransferReceipt~new('TRANSFER-NOT-REGISTERED', mismatchPackage~packageId, 'TRANSFERQ', accepted2~value~acceptedAt, 'MANAGER-A', .false)
unregisteredResult = .QueueAuthorityPromotionExecutor~execute(manager, 'TRANSFERQ', mismatchPackage, mismatchToken, 'admin', mismatchSet, mismatchWorld, 'NODE-B/AUTHORITY', restartedLedger, unregisteredReceipt)
call AssertTrue \unregisteredResult~ok, 'unregistered receipt refused'
call AssertEqual 'TRANSFER_RECEIPT_NOT_REGISTERED', unregisteredResult~code, 'unregistered receipt code'
call AssertOk manager~ack('TRANSFERQ', mismatchPackage~packageId, mismatchToken, 'admin'), 'operator cleanup acknowledges mismatched package'

/* Durable Queue Fabric receipt survives manager restart and still suppresses transport reinsertion. */
durableRoot = '/tmp/ryta_queue_fabric_durable_' || .DateTime~new~microseconds
durableManager = .ObjectQueueManager~new(durableRoot, .nil, 'admin')
call AssertOk durableManager~createQueue('DURABLE', 'PERMANENT', 'AUTHORITY', 20, 'admin'), 'create durable queue'
durableOptions = .table~new
durableOptions['persistent'] = .true
durableOptions['sourceManager'] = 'MANAGER-DURABLE-SOURCE'
durableOptions['sourceQueue'] = 'SOURCEQ'
durableOptions['sourcePackageId'] = 'SOURCE-DURABLE-001'
durableAccept = durableManager~acceptTransfer('TRANSFER-DURABLE-001', 'DURABLE', 'durable-work', durableOptions, 'admin')
call AssertOk durableAccept, 'accept durable transfer'
durableClaim = durableManager~claim('DURABLE', 'admin')
call AssertOk durableClaim, 'claim durable transfer'
durablePackage = durableClaim~value
durableToken = durablePackage~claimToken
durableSet = BuildPromotionSet('DURABLE-P1', 'QUEUE_DURABLE_TRANSFER_APPLIED', .true)
durableWorld = .RYTAWorldState~new('QUEUE-DURABLE-WORLD')
durableResult = .QueueAuthorityPromotionExecutor~execute(durableManager, 'DURABLE', durablePackage, durableToken, 'admin', durableSet, durableWorld, 'NODE-DURABLE/AUTHORITY', restartedLedger, durableAccept~value)
call AssertTrue durableResult~ok, 'durable transfer authority execution succeeds'
call AssertTrue durableWorld~isKnownTrue('QUEUE_DURABLE_TRANSFER_APPLIED'), 'durable transfer promotion applied'
durableManager2 = .ObjectQueueManager~new(durableRoot, .nil, 'admin')
recoveredReceipt = durableManager2~transferReceipt('TRANSFER-DURABLE-001')
call AssertTrue recoveredReceipt \== .nil, 'durable transfer receipt recovered after restart'
call AssertEqual durableAccept~value~packageId, recoveredReceipt~packageId, 'recovered receipt retains destination package id'
durableDuplicate = durableManager2~acceptTransfer('TRANSFER-DURABLE-001', 'DURABLE', 'durable-work', durableOptions, 'admin')
call AssertOk durableDuplicate, 'durable duplicate transfer accepted after restart'
call AssertTrue durableDuplicate~value~duplicate, 'durable duplicate marked duplicate after restart'
call AssertEqual 0, durableManager2~depth('DURABLE', 'admin')~value['total'], 'durable duplicate does not reinsert consumed work'

/* Namespace is mandatory because a transfer receipt does not carry destination manager identity. */
call AssertOk manager~put('AUTH', 'namespace-work', .nil, 'admin'), 'put namespace work'
claimNamespace = manager~claim('AUTH', 'admin')
call AssertOk claimNamespace, 'claim namespace work'
namespacePackage = claimNamespace~value
namespaceToken = namespacePackage~claimToken
namespaceSet = BuildPromotionSet('NAMESPACE-P1', 'QUEUE_NAMESPACE_MUST_NOT_APPLY', .true)
namespaceWorld = .RYTAWorldState~new('QUEUE-NAMESPACE-WORLD')
namespaceResult = .QueueAuthorityPromotionExecutor~execute(manager, 'AUTH', namespacePackage, namespaceToken, 'admin', namespaceSet, namespaceWorld, '', restartedLedger)
call AssertTrue \namespaceResult~ok, 'missing execution namespace refused'
call AssertEqual 'QUEUE_EXECUTION_NAMESPACE_REQUIRED', namespaceResult~code, 'namespace refusal code'
call AssertEqual 'UNKNOWN', namespaceWorld~knowledgeOf('QUEUE_NAMESPACE_MUST_NOT_APPLY'), 'namespace refusal happens before apply'
call AssertOk manager~ack('AUTH', namespacePackage~packageId, namespaceToken, 'admin'), 'operator cleanup acknowledges namespace package'

/* The bearer-like claim token must not leak into raw or hex-encoded ledger material. */
ledgerText = ReadFile(ledgerPath)
call AssertEqual 0, pos(localToken, ledgerText), 'raw claim token absent from ledger'
call AssertEqual 0, pos(c2x(localToken), ledgerText), 'hex claim token absent from ledger'
call AssertEqual 0, pos(transferToken, ledgerText), 'raw transfer claim token absent from ledger'
call AssertEqual 0, pos(c2x(transferToken), ledgerText), 'hex transfer claim token absent from ledger'

ignore = SysFileDelete(ledgerPath)
say 'QUEUE AUTHORITY EXECUTION V0.21: OK'
exit 0

::routine BuildPromotionSet
  use arg promotionId, targetFact, value
  promotion = .EvidencePromotion~new(promotionId, 'QUEUE_TEST', 'SRC-' || promotionId, targetFact, 'KNOWN', value, 'TEST_AUTHORITY', 'TEST_POLICY', 'TEST_RULE', 'REQUIRED', 'AUTHORIZED')
  promotionSet = .EvidencePromotionSet~new
  if \promotionSet~add(promotion) then raise syntax 88.900 array('could not add promotion ' || promotionId)
  ignored = promotionSet~seal
  return promotionSet

::routine ReadFile
  use arg path
  stream = .Stream~new(path)
  openStatus = stream~open('read')
  if openStatus \= 'READY:' then return ''
  count = stream~chars
  if count = 0 then do
    closeStatus = stream~close
    return ''
  end
  text = stream~charIn(1, count)
  closeStatus = stream~close
  return text

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

::requires 'ObjectQueueFabric.cls'
::requires '../integration/QueueFabricAuthorityExecution.cls'
::requires '../HardWorld.cls'
