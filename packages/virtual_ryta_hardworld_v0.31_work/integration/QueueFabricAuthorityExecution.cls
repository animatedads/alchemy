/*
 * QueueFabricAuthorityExecution.cls
 *
 * HardWorld-owned execution boundary for authority-bearing EvidencePromotion
 * sets carried by Queue Fabric work packages.
 *
 * Queue Fabric v0.5 supplies transport, claim and transfer identities.  It does
 * not provide an atomic transaction spanning a HardWorld mutation and queue ACK.
 * This layer therefore records START before promotion application and COMPLETE
 * afterwards.  A recovered START without COMPLETE is refused as
 * PREVIOUS_EXECUTION_UNCERTAIN rather than replayed automatically.
 *
 * The Queue Fabric claimToken is used only as a live acknowledgement capability.
 * It is never copied into canonical evidence, ledger records, hashes or results.
 *
 * v0.25 also closes the retained-authority time-bomb boundary.  A package
 * carrying Queue Fabric's native oqf.topic.retained=1 replay marker cannot
 * directly apply the publisher-supplied promotion set.  A host consumer-time
 * revalidator must produce a distinct sealed promotion set bound to the
 * retained publication id.  Queue durability and publisher-time authority
 * remain evidence; they are not permanent consumer authority.
 */

::class QueueAuthorityWorkIdentity subclass RYTAObject public
::attribute executionNamespace get
::attribute transportKind get
::attribute transferId get
::attribute packageId get
::attribute queueName get
::attribute sourceManager get
::attribute parentPackageId get
::attribute requestedQueue get
::attribute packageCreatedAt get
::attribute priority get
::attribute persistent get
::attribute securityDomain get
::attribute routingKey get
::attribute correlationId get
::attribute replyTo get
::attribute transferAcceptedAt get

::method init
  expose executionNamespace transportKind transferId packageId queueName sourceManager parentPackageId requestedQueue packageCreatedAt priority persistent securityDomain routingKey correlationId replyTo transferAcceptedAt
  use arg namespaceArg, queueNameArg, packageIdArg, transportKindArg = 'LOCAL', transferIdArg = '', sourceManagerArg = '', parentPackageIdArg = '', requestedQueueArg = '', packageCreatedAtArg = '', priorityArg = 0, persistentArg = .false, securityDomainArg = '', routingKeyArg = '', correlationIdArg = '', replyToArg = '', transferAcceptedAtArg = ''
  self~init:super('QueueAuthorityWorkIdentity', 'QUEUE_WORK_IDENTITY')
  executionNamespace = namespaceArg~string~strip
  queueName = queueNameArg~string~strip
  packageId = packageIdArg~string~strip
  transportKind = transportKindArg~string~strip~upper
  transferId = transferIdArg~string~strip
  sourceManager = sourceManagerArg~string~strip
  parentPackageId = parentPackageIdArg~string~strip
  requestedQueue = requestedQueueArg~string
  packageCreatedAt = packageCreatedAtArg~string
  priority = priorityArg
  persistent = persistentArg
  securityDomain = securityDomainArg~string
  routingKey = routingKeyArg~string
  correlationId = correlationIdArg~string
  replyTo = replyToArg~string
  transferAcceptedAt = transferAcceptedAtArg~string
  if executionNamespace = '' then raise syntax 93.900 additional('QUEUE_EXECUTION_NAMESPACE_REQUIRED')
  if queueName = '' then raise syntax 93.900 additional('QUEUE_NAME_REQUIRED')
  if packageId = '' then raise syntax 93.900 additional('QUEUE_PACKAGE_ID_REQUIRED')
  if transportKind = 'TRANSFER' then do
    if transferId = '' then raise syntax 93.900 additional('QUEUE_TRANSFER_ID_REQUIRED')
  end
  else if transportKind \= 'LOCAL' then raise syntax 93.900 additional('QUEUE_TRANSPORT_KIND_INVALID:' transportKind)

::method stableKeyText
  expose executionNamespace transportKind transferId packageId queueName
  text = 'RYTA_QUEUE_AUTHORITY_STABLE_KEY_V1' || '0a'x
  text = text || self~field('NAMESPACE', executionNamespace)
  text = text || self~field('TRANSPORT_KIND', transportKind)
  if transportKind = 'TRANSFER' then text = text || self~field('TRANSFER_ID', transferId)
  else do
    text = text || self~field('QUEUE', queueName)
    text = text || self~field('PACKAGE_ID', packageId)
  end
  return text

::method executionKey
  return .AlgorithmDigest~sha256Text(self~stableKeyText)

::method algorithmCanonicalText
  expose executionNamespace transportKind transferId packageId queueName sourceManager parentPackageId requestedQueue packageCreatedAt priority persistent securityDomain routingKey correlationId replyTo transferAcceptedAt
  text = 'RYTA_QUEUE_AUTHORITY_WORK_IDENTITY_V1' || '0a'x
  text = text || self~field('NAMESPACE', executionNamespace)
  text = text || self~field('TRANSPORT_KIND', transportKind)
  text = text || self~field('TRANSFER_ID', transferId)
  text = text || self~field('PACKAGE_ID', packageId)
  text = text || self~field('QUEUE', queueName)
  text = text || self~field('SOURCE_MANAGER', sourceManager)
  text = text || self~field('PARENT_PACKAGE_ID', parentPackageId)
  text = text || self~field('REQUESTED_QUEUE', requestedQueue)
  text = text || self~field('PACKAGE_CREATED_AT', packageCreatedAt)
  text = text || self~field('PRIORITY', priority)
  text = text || self~field('PERSISTENT', persistent)
  text = text || self~field('SECURITY_DOMAIN', securityDomain)
  text = text || self~field('ROUTING_KEY', routingKey)
  text = text || self~field('CORRELATION_ID', correlationId)
  text = text || self~field('REPLY_TO', replyTo)
  text = text || self~field('TRANSFER_ACCEPTED_AT', transferAcceptedAt)
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x


::class QueueAuthorityAttemptEvidence subclass RYTAObject public
::attribute workIdentity get
::attribute deliveryCount get
::attribute backoutCount get
::attribute claimedBy get
::attribute claimedAt get
::attribute transferReceipt get

::method init
  expose workIdentity deliveryCount backoutCount claimedBy claimedAt transferReceipt
  use arg workIdentityArg, packageArg, receiptArg = .nil
  self~init:super('QueueAuthorityAttemptEvidence', 'QUEUE_ATTEMPT_EVIDENCE')
  if workIdentityArg == .nil then raise syntax 93.900 additional('QUEUE_WORK_IDENTITY_REQUIRED')
  if packageArg == .nil then raise syntax 93.900 additional('QUEUE_PACKAGE_REQUIRED')
  workIdentity = workIdentityArg
  transferReceipt = receiptArg
  deliveryCount = packageArg~deliveryCount
  backoutCount = packageArg~backoutCount
  claimedBy = packageArg~claimedBy~string
  claimedAt = packageArg~claimedAt~string

::method algorithmCanonicalText
  expose workIdentity deliveryCount backoutCount claimedBy claimedAt
  text = 'RYTA_QUEUE_AUTHORITY_ATTEMPT_V1' || '0a'x
  workText = workIdentity~algorithmCanonicalText
  text = text || 'WORK=' || workText~length || ':' || workText || '0a'x
  text = text || self~field('DELIVERY_COUNT', deliveryCount)
  text = text || self~field('BACKOUT_COUNT', backoutCount)
  text = text || self~field('CLAIMED_BY', claimedBy)
  text = text || self~field('CLAIMED_AT', claimedAt)
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x


::class QueueAuthorityLedgerDecision public
::attribute ok get
::attribute code get
::attribute detail get

::method init
  expose ok code detail
  use arg okArg, codeArg, detailArg = ''
  ok = okArg
  code = codeArg~string
  detail = detailArg~string

::method success class
  use arg codeArg, detailArg = ''
  return self~new(.true, codeArg, detailArg)

::method failure class
  use arg codeArg, detailArg = ''
  return self~new(.false, codeArg, detailArg)


::class QueueAuthorityLedgerMacProof public
::attribute algorithm get
::attribute keyId get
::attribute tag get

::method init
  expose algorithm keyId tag
  use strict arg algorithmArg, keyIdArg, tagArg
  algorithm = algorithmArg~string~strip~upper
  keyId = keyIdArg~string~strip
  tag = tagArg~string~strip~lower


::class QueueAuthorityExecutionLedger subclass RYTAObject public
::attribute path get
::attribute authenticationMode get
::attribute authenticatedTailTag get
::attribute authenticatedRecordCount get
::attribute authenticatedTailSequence get

::method init
  expose path states fingerprints attempts envelopeFingerprints authorityFingerprints recordVersions trustedRecords keyRing authenticationMode authenticatedTailTag authenticatedRecordCount authenticatedTailSequence nextSequence
  use arg pathArg, keyRingArg = .nil, expectedCheckpointArg = .nil
  self~init:super('QueueAuthorityExecutionLedger', 'QUEUE_AUTHORITY_LEDGER')
  path = pathArg~string~strip
  if path = '' then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_PATH_REQUIRED')
  states = .directory~new
  fingerprints = .directory~new
  attempts = .directory~new
  envelopeFingerprints = .directory~new
  authorityFingerprints = .directory~new
  recordVersions = .directory~new
  trustedRecords = .directory~new
  keyRing = keyRingArg
  if keyRing == .nil then authenticationMode = 'LEGACY_COMPATIBILITY'
  else do
    required = .array~of('SIGN', 'VERIFY', 'HASKEY')
    do methodName over required
      if \keyRing~hasMethod(methodName) then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_MAC_KEYRING_SURFACE_INVALID:' || methodName)
    end
    authenticationMode = 'AUTHENTICATED_V3'
  end
  authenticatedTailTag = self~zeroTag
  authenticatedRecordCount = 0
  authenticatedTailSequence = 0
  nextSequence = 1
  self~load
  if expectedCheckpointArg \== .nil then do
    if \self~matchesCheckpoint(expectedCheckpointArg) then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_CHECKPOINT_MISMATCH')
  end

::method stateFor
  expose states
  use arg executionKey
  value = states~at(executionKey~string)
  if value == .nil then return 'NONE'
  return value

::method fingerprintFor
  expose fingerprints
  use arg executionKey
  value = fingerprints~at(executionKey~string)
  if value == .nil then return ''
  return value

::method envelopeFingerprintFor
  expose envelopeFingerprints
  use arg executionKey
  value = envelopeFingerprints~at(executionKey~string)
  if value == .nil then return ''
  return value

::method authorityFingerprintFor
  expose authorityFingerprints
  use arg executionKey
  value = authorityFingerprints~at(executionKey~string)
  if value == .nil then return ''
  return value

::method recordVersionFor
  expose recordVersions
  use arg executionKey
  value = recordVersions~at(executionKey~string)
  if value == .nil then return ''
  return value

::method trustedRecordFor
  expose trustedRecords
  use arg executionKey
  value = trustedRecords~at(executionKey~string)
  if value == .nil then return .false
  return value

/* A checkpoint is intentionally only a value for a host to retain in a
   separate trusted/monotonic store.  The local MAC chain alone authenticates
   present records but cannot prove that a valid newer tail was not rolled
   back. */
::method chainCheckpointText
  expose authenticatedRecordCount authenticatedTailSequence authenticatedTailTag
  text = 'RYTA_QUEUE_AUTHORITY_LEDGER_CHECKPOINT_V1' || '0a'x
  text = text || self~field('AUTHENTICATED_RECORD_COUNT', authenticatedRecordCount)
  text = text || self~field('TAIL_SEQUENCE', authenticatedTailSequence)
  text = text || self~field('TAIL_TAG', authenticatedTailTag)
  return text

::method matchesCheckpoint
  use arg checkpointText
  return self~chainCheckpointText == checkpointText~string

/* v0.27 authority path.  Only V3 records are trusted for recovery.  Legacy
   V1/V2 records remain parseable for evidence/migration but can never mint an
   ACK-only recovery decision. */
::method preflightCurrent
  expose states envelopeFingerprints recordVersions trustedRecords
  use arg executionKeyArg, envelopeFingerprintArg
  executionKey = executionKeyArg~string
  envelopeFingerprint = envelopeFingerprintArg~string
  if executionKey = '' then return .QueueAuthorityLedgerDecision~failure('EXECUTION_KEY_REQUIRED')
  if envelopeFingerprint = '' then return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_FINGERPRINT_REQUIRED')
  guard on
  existingState = states~at(executionKey)
  if existingState == .nil then do
    guard off
    return .QueueAuthorityLedgerDecision~success('NONE', executionKey)
  end
  version = recordVersions~at(executionKey)
  if version \= 'V3' | trustedRecords~at(executionKey) \== .true then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('LEGACY_LEDGER_RECORD_UNTRUSTED', version || ':' || executionKey)
  end
  existingEnvelope = envelopeFingerprints~at(executionKey)
  if existingEnvelope == .nil | existingEnvelope \= envelopeFingerprint then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_CONFLICT', executionKey)
  end
  guard off
  if existingState = 'COMPLETE' then return .QueueAuthorityLedgerDecision~success('ALREADY_COMPLETE', executionKey)
  if existingState = 'START' then return .QueueAuthorityLedgerDecision~failure('PREVIOUS_EXECUTION_UNCERTAIN', executionKey)
  return .QueueAuthorityLedgerDecision~failure('LEDGER_STATE_INVALID', existingState)

::method beginCurrent
  expose keyRing states fingerprints attempts envelopeFingerprints authorityFingerprints recordVersions trustedRecords
  use arg executionKeyArg, envelopeFingerprintArg, authorityFingerprintArg, attemptEvidence
  executionKey = executionKeyArg~string
  envelopeFingerprint = envelopeFingerprintArg~string
  authorityFingerprint = authorityFingerprintArg~string
  if executionKey = '' then return .QueueAuthorityLedgerDecision~failure('EXECUTION_KEY_REQUIRED')
  if envelopeFingerprint = '' then return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_FINGERPRINT_REQUIRED')
  if authorityFingerprint = '' then return .QueueAuthorityLedgerDecision~failure('AUTHORITY_DECISION_FINGERPRINT_REQUIRED')
  if attemptEvidence == .nil then return .QueueAuthorityLedgerDecision~failure('ATTEMPT_EVIDENCE_REQUIRED')

  /* Compatibility mode may execute fresh work, but its V2 completion can never
     be trusted for automatic recovery on a later invocation. */
  if keyRing == .nil then return self~beginV2(executionKey, envelopeFingerprint, authorityFingerprint, attemptEvidence)

  guard on
  existingState = states~at(executionKey)
  if existingState \== .nil then do
    version = recordVersions~at(executionKey)
    if version \= 'V3' | trustedRecords~at(executionKey) \== .true then do
      guard off
      return .QueueAuthorityLedgerDecision~failure('LEGACY_LEDGER_RECORD_UNTRUSTED', version || ':' || executionKey)
    end
    if envelopeFingerprints~at(executionKey) \= envelopeFingerprint then do
      guard off
      return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_CONFLICT', executionKey)
    end
    if authorityFingerprints~at(executionKey) \= authorityFingerprint then do
      guard off
      return .QueueAuthorityLedgerDecision~failure('AUTHORITY_DECISION_CONFLICT', executionKey)
    end
    guard off
    if existingState = 'COMPLETE' then return .QueueAuthorityLedgerDecision~success('ALREADY_COMPLETE', executionKey)
    if existingState = 'START' then return .QueueAuthorityLedgerDecision~failure('PREVIOUS_EXECUTION_UNCERTAIN', executionKey)
    return .QueueAuthorityLedgerDecision~failure('LEDGER_STATE_INVALID', existingState)
  end

  attemptText = attemptEvidence~algorithmCanonicalText
  self~appendRecordV3('START', executionKey, envelopeFingerprint, authorityFingerprint, attemptText)
  envelopeFingerprints[executionKey] = envelopeFingerprint
  authorityFingerprints[executionKey] = authorityFingerprint
  fingerprints[executionKey] = authorityFingerprint
  states[executionKey] = 'START'
  attempts[executionKey] = attemptText
  recordVersions[executionKey] = 'V3'
  trustedRecords[executionKey] = .true
  guard off
  return .QueueAuthorityLedgerDecision~success('STARTED', executionKey)

::method completeCurrent
  expose keyRing states fingerprints envelopeFingerprints authorityFingerprints recordVersions trustedRecords
  use arg executionKeyArg, envelopeFingerprintArg, authorityFingerprintArg, attemptEvidence
  executionKey = executionKeyArg~string
  envelopeFingerprint = envelopeFingerprintArg~string
  authorityFingerprint = authorityFingerprintArg~string
  if attemptEvidence == .nil then return .QueueAuthorityLedgerDecision~failure('ATTEMPT_EVIDENCE_REQUIRED')
  if keyRing == .nil then return self~completeV2(executionKey, envelopeFingerprint, authorityFingerprint, attemptEvidence)

  guard on
  existingState = states~at(executionKey)
  if existingState == .nil then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('EXECUTION_NOT_STARTED', executionKey)
  end
  version = recordVersions~at(executionKey)
  if version \= 'V3' | trustedRecords~at(executionKey) \== .true then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('LEGACY_LEDGER_RECORD_UNTRUSTED', version || ':' || executionKey)
  end
  if envelopeFingerprints~at(executionKey) \= envelopeFingerprint then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_CONFLICT', executionKey)
  end
  if authorityFingerprints~at(executionKey) \= authorityFingerprint then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('AUTHORITY_DECISION_CONFLICT', executionKey)
  end
  if existingState = 'COMPLETE' then do
    guard off
    return .QueueAuthorityLedgerDecision~success('ALREADY_COMPLETE', executionKey)
  end
  if existingState \= 'START' then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('LEDGER_STATE_INVALID', existingState)
  end
  attemptText = attemptEvidence~algorithmCanonicalText
  self~appendRecordV3('COMPLETE', executionKey, envelopeFingerprint, authorityFingerprint, attemptText)
  states[executionKey] = 'COMPLETE'
  fingerprints[executionKey] = authorityFingerprint
  guard off
  return .QueueAuthorityLedgerDecision~success('COMPLETED', executionKey)

/* v0.26 compatibility API.  It remains useful for reading old evidence and for
   inherited tests, but current authority recovery does not call it. */
::method preflightV2
  expose states envelopeFingerprints recordVersions
  use arg executionKeyArg, envelopeFingerprintArg
  executionKey = executionKeyArg~string
  envelopeFingerprint = envelopeFingerprintArg~string
  if executionKey = '' then return .QueueAuthorityLedgerDecision~failure('EXECUTION_KEY_REQUIRED')
  if envelopeFingerprint = '' then return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_FINGERPRINT_REQUIRED')
  guard on
  existingState = states~at(executionKey)
  if existingState == .nil then do
    guard off
    return .QueueAuthorityLedgerDecision~success('NONE', executionKey)
  end
  version = recordVersions~at(executionKey)
  if version = 'V1' then do
    guard off
    return .QueueAuthorityLedgerDecision~success('LEGACY_RECORD', existingState)
  end
  existingEnvelope = envelopeFingerprints~at(executionKey)
  if existingEnvelope == .nil | existingEnvelope \= envelopeFingerprint then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_CONFLICT', executionKey)
  end
  guard off
  if existingState = 'COMPLETE' then return .QueueAuthorityLedgerDecision~success('ALREADY_COMPLETE', executionKey)
  if existingState = 'START' then return .QueueAuthorityLedgerDecision~failure('PREVIOUS_EXECUTION_UNCERTAIN', executionKey)
  return .QueueAuthorityLedgerDecision~failure('LEDGER_STATE_INVALID', existingState)

::method beginV2
  expose states fingerprints attempts envelopeFingerprints authorityFingerprints recordVersions trustedRecords
  use arg executionKeyArg, envelopeFingerprintArg, authorityFingerprintArg, attemptEvidence
  executionKey = executionKeyArg~string
  envelopeFingerprint = envelopeFingerprintArg~string
  authorityFingerprint = authorityFingerprintArg~string
  if executionKey = '' then return .QueueAuthorityLedgerDecision~failure('EXECUTION_KEY_REQUIRED')
  if envelopeFingerprint = '' then return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_FINGERPRINT_REQUIRED')
  if authorityFingerprint = '' then return .QueueAuthorityLedgerDecision~failure('AUTHORITY_DECISION_FINGERPRINT_REQUIRED')
  if attemptEvidence == .nil then return .QueueAuthorityLedgerDecision~failure('ATTEMPT_EVIDENCE_REQUIRED')
  guard on
  existingState = states~at(executionKey)
  if existingState \== .nil then do
    version = recordVersions~at(executionKey)
    if version = 'V1' then do
      guard off
      return .QueueAuthorityLedgerDecision~failure('LEGACY_LEDGER_RECORD_REQUIRES_LEGACY_PATH', executionKey)
    end
    existingEnvelope = envelopeFingerprints~at(executionKey)
    if existingEnvelope \= envelopeFingerprint then do
      guard off
      return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_CONFLICT', executionKey)
    end
    existingAuthority = authorityFingerprints~at(executionKey)
    if existingAuthority \= authorityFingerprint then do
      guard off
      return .QueueAuthorityLedgerDecision~failure('AUTHORITY_DECISION_CONFLICT', executionKey)
    end
    guard off
    if existingState = 'COMPLETE' then return .QueueAuthorityLedgerDecision~success('ALREADY_COMPLETE', executionKey)
    if existingState = 'START' then return .QueueAuthorityLedgerDecision~failure('PREVIOUS_EXECUTION_UNCERTAIN', executionKey)
    return .QueueAuthorityLedgerDecision~failure('LEDGER_STATE_INVALID', existingState)
  end

  attemptText = attemptEvidence~algorithmCanonicalText
  self~appendRecordV2('START', executionKey, envelopeFingerprint, authorityFingerprint, attemptText)
  envelopeFingerprints[executionKey] = envelopeFingerprint
  authorityFingerprints[executionKey] = authorityFingerprint
  fingerprints[executionKey] = authorityFingerprint
  states[executionKey] = 'START'
  attempts[executionKey] = attemptText
  recordVersions[executionKey] = 'V2'
  trustedRecords[executionKey] = .false
  guard off
  return .QueueAuthorityLedgerDecision~success('STARTED', executionKey)

::method completeV2
  expose states fingerprints envelopeFingerprints authorityFingerprints recordVersions
  use arg executionKeyArg, envelopeFingerprintArg, authorityFingerprintArg, attemptEvidence
  executionKey = executionKeyArg~string
  envelopeFingerprint = envelopeFingerprintArg~string
  authorityFingerprint = authorityFingerprintArg~string
  if attemptEvidence == .nil then return .QueueAuthorityLedgerDecision~failure('ATTEMPT_EVIDENCE_REQUIRED')
  guard on
  existingState = states~at(executionKey)
  if existingState == .nil then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('EXECUTION_NOT_STARTED', executionKey)
  end
  if recordVersions~at(executionKey) = 'V1' then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('LEGACY_LEDGER_RECORD_REQUIRES_LEGACY_PATH', executionKey)
  end
  if envelopeFingerprints~at(executionKey) \= envelopeFingerprint then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('WORK_ENVELOPE_CONFLICT', executionKey)
  end
  if authorityFingerprints~at(executionKey) \= authorityFingerprint then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('AUTHORITY_DECISION_CONFLICT', executionKey)
  end
  if existingState = 'COMPLETE' then do
    guard off
    return .QueueAuthorityLedgerDecision~success('ALREADY_COMPLETE', executionKey)
  end
  if existingState \= 'START' then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('LEDGER_STATE_INVALID', existingState)
  end
  attemptText = attemptEvidence~algorithmCanonicalText
  self~appendRecordV2('COMPLETE', executionKey, envelopeFingerprint, authorityFingerprint, attemptText)
  states[executionKey] = 'COMPLETE'
  fingerprints[executionKey] = authorityFingerprint
  guard off
  return .QueueAuthorityLedgerDecision~success('COMPLETED', executionKey)

/* Legacy v1 API remains readable for historical evidence only. */
::method begin
  expose states fingerprints attempts envelopeFingerprints authorityFingerprints recordVersions trustedRecords
  use arg executionKeyArg, workFingerprintArg, attemptEvidence
  executionKey = executionKeyArg~string
  workFingerprint = workFingerprintArg~string
  if executionKey = '' then return .QueueAuthorityLedgerDecision~failure('EXECUTION_KEY_REQUIRED')
  if workFingerprint = '' then return .QueueAuthorityLedgerDecision~failure('WORK_FINGERPRINT_REQUIRED')
  if attemptEvidence == .nil then return .QueueAuthorityLedgerDecision~failure('ATTEMPT_EVIDENCE_REQUIRED')
  guard on
  existingFingerprint = fingerprints~at(executionKey)
  if existingFingerprint \== .nil then do
    if existingFingerprint \= workFingerprint then do
      guard off
      return .QueueAuthorityLedgerDecision~failure('WORK_IDENTITY_CONFLICT', executionKey)
    end
    existingState = states~at(executionKey)
    guard off
    if existingState = 'COMPLETE' then return .QueueAuthorityLedgerDecision~success('ALREADY_COMPLETE', executionKey)
    if existingState = 'START' then return .QueueAuthorityLedgerDecision~failure('PREVIOUS_EXECUTION_UNCERTAIN', executionKey)
    return .QueueAuthorityLedgerDecision~failure('LEDGER_STATE_INVALID', existingState)
  end
  attemptText = attemptEvidence~algorithmCanonicalText
  self~appendRecordV1('START', executionKey, workFingerprint, attemptText)
  fingerprints[executionKey] = workFingerprint
  authorityFingerprints[executionKey] = workFingerprint
  envelopeFingerprints[executionKey] = ''
  states[executionKey] = 'START'
  attempts[executionKey] = attemptText
  recordVersions[executionKey] = 'V1'
  trustedRecords[executionKey] = .false
  guard off
  return .QueueAuthorityLedgerDecision~success('STARTED', executionKey)

::method complete
  expose states fingerprints
  use arg executionKeyArg, workFingerprintArg, attemptEvidence
  executionKey = executionKeyArg~string
  workFingerprint = workFingerprintArg~string
  if attemptEvidence == .nil then return .QueueAuthorityLedgerDecision~failure('ATTEMPT_EVIDENCE_REQUIRED')
  guard on
  existingFingerprint = fingerprints~at(executionKey)
  existingState = states~at(executionKey)
  if existingFingerprint == .nil then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('EXECUTION_NOT_STARTED', executionKey)
  end
  if existingFingerprint \= workFingerprint then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('WORK_IDENTITY_CONFLICT', executionKey)
  end
  if existingState = 'COMPLETE' then do
    guard off
    return .QueueAuthorityLedgerDecision~success('ALREADY_COMPLETE', executionKey)
  end
  if existingState \= 'START' then do
    guard off
    return .QueueAuthorityLedgerDecision~failure('LEDGER_STATE_INVALID', existingState)
  end
  attemptText = attemptEvidence~algorithmCanonicalText
  self~appendRecordV1('COMPLETE', executionKey, workFingerprint, attemptText)
  states[executionKey] = 'COMPLETE'
  guard off
  return .QueueAuthorityLedgerDecision~success('COMPLETED', executionKey)

::method load private
  expose path states fingerprints attempts envelopeFingerprints authorityFingerprints recordVersions trustedRecords keyRing authenticatedTailTag authenticatedRecordCount authenticatedTailSequence nextSequence
  stream = .Stream~new(path)
  if stream~query('exists') = '' then return 0
  if \self~hasTerminalLineBreak then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_UNTERMINATED_TAIL')
  openStatus = stream~open('read')
  if openStatus \= 'READY:' then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_OPEN_FAILED:' openStatus)
  lineNumber = 0
  seenAuthenticated = .false
  expectedSequence = 1
  previousTag = self~zeroTag
  do while stream~lines > 0
    lineNumber += 1
    line = stream~lineIn
    parsed = self~parseRecord(line)
    if parsed == .nil then do
      closeStatus = stream~close
      raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_MALFORMED_RECORD:' lineNumber)
    end
    key = parsed['key']
    state = parsed['state']
    version = parsed['version']
    authorityFingerprint = parsed['authority']
    envelopeFingerprint = parsed['envelope']
    attemptText = parsed['attempt']

    trusted = .false
    if version = 'V3' then do
      seenAuthenticated = .true
      if keyRing == .nil then do
        closeStatus = stream~close
        raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_MAC_KEYRING_REQUIRED:' lineNumber)
      end
      sequence = parsed['sequence']
      if sequence \= expectedSequence then do
        closeStatus = stream~close
        raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_CHAIN_SEQUENCE_INVALID:' lineNumber)
      end
      if parsed['previousTag'] \= previousTag then do
        closeStatus = stream~close
        raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_CHAIN_PREVIOUS_TAG_INVALID:' lineNumber)
      end
      keyId = parsed['keyId']
      if \keyRing~hasKey(keyId) then do
        closeStatus = stream~close
        raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_MAC_KEY_UNKNOWN:' || keyId)
      end
      proof = .QueueAuthorityLedgerMacProof~new(parsed['algorithm'], keyId, parsed['tag'])
      macText = self~v3MacText(sequence, state, key, envelopeFingerprint, authorityFingerprint, attemptText, parsed['timestamp'], parsed['previousTag'], parsed['algorithm'], keyId)
      if \keyRing~verify(macText, proof) then do
        closeStatus = stream~close
        raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_MAC_INVALID:' lineNumber)
      end
      trusted = .true
      previousTag = parsed['tag']
      authenticatedTailTag = previousTag
      authenticatedRecordCount += 1
      authenticatedTailSequence = sequence
      expectedSequence += 1
      nextSequence = expectedSequence
    end
    else do
      if seenAuthenticated then do
        closeStatus = stream~close
        raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_LEGACY_AFTER_AUTHENTICATED_RECORD:' lineNumber)
      end
    end

    oldVersion = recordVersions~at(key)
    if oldVersion \== .nil then do
      if oldVersion \= version then do
        closeStatus = stream~close
        raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_VERSION_CONFLICT:' key)
      end
      if authorityFingerprints~at(key) \= authorityFingerprint then do
        closeStatus = stream~close
        raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_AUTHORITY_FINGERPRINT_CONFLICT:' key)
      end
      if version = 'V2' | version = 'V3' then do
        if envelopeFingerprints~at(key) \= envelopeFingerprint then do
          closeStatus = stream~close
          raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_ENVELOPE_FINGERPRINT_CONFLICT:' key)
        end
      end
      oldState = states~at(key)
      if oldState = 'COMPLETE' & state = 'START' then do
        closeStatus = stream~close
        raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_STATE_REGRESSION:' key)
      end
    end
    if state \= 'START' & state \= 'COMPLETE' then do
      closeStatus = stream~close
      raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_STATE_INVALID:' state)
    end
    authorityFingerprints[key] = authorityFingerprint
    fingerprints[key] = authorityFingerprint
    envelopeFingerprints[key] = envelopeFingerprint
    recordVersions[key] = version
    trustedRecords[key] = trusted
    states[key] = state
    attempts[key] = attemptText
  end
  closeStatus = stream~close
  return 0

::method appendRecordV1 private
  expose path keyRing authenticatedRecordCount
  use arg state, executionKey, workFingerprint, attemptText
  if keyRing \== .nil | authenticatedRecordCount > 0 then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_LEGACY_WRITE_DISABLED')
  if \self~hasTerminalLineBreak then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_UNTERMINATED_TAIL')
  timestamp = .DateTime~new~string
  line = 'RYTA_QUEUE_AUTHORITY_LEDGER_V1|' || state || '|' || c2x(executionKey) || '|' || c2x(workFingerprint) || '|' || c2x(attemptText) || '|' || c2x(timestamp)
  stream = .Stream~new(path)
  openStatus = stream~open('write append')
  if openStatus \= 'READY:' then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_APPEND_FAILED:' openStatus)
  writeStatus = stream~lineOut(line)
  closeStatus = stream~close
  return .true

::method appendRecordV2 private
  expose path keyRing authenticatedRecordCount
  use arg state, executionKey, envelopeFingerprint, authorityFingerprint, attemptText
  if keyRing \== .nil | authenticatedRecordCount > 0 then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_LEGACY_WRITE_DISABLED')
  if \self~hasTerminalLineBreak then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_UNTERMINATED_TAIL')
  timestamp = .DateTime~new~string
  line = 'RYTA_QUEUE_AUTHORITY_LEDGER_V2|' || state || '|' || c2x(executionKey) || '|' || c2x(envelopeFingerprint) || '|' || c2x(authorityFingerprint) || '|' || c2x(attemptText) || '|' || c2x(timestamp)
  stream = .Stream~new(path)
  openStatus = stream~open('write append')
  if openStatus \= 'READY:' then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_APPEND_FAILED:' openStatus)
  writeStatus = stream~lineOut(line)
  closeStatus = stream~close
  return .true

::method appendRecordV3 private
  expose path keyRing authenticatedTailTag authenticatedRecordCount authenticatedTailSequence nextSequence
  use arg state, executionKey, envelopeFingerprint, authorityFingerprint, attemptText
  if keyRing == .nil then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_MAC_KEYRING_REQUIRED')
  if \self~hasTerminalLineBreak then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_UNTERMINATED_TAIL')
  sequence = nextSequence
  timestamp = .DateTime~new~string
  previousTag = authenticatedTailTag

  seed = keyRing~sign('RYTA_QUEUE_AUTHORITY_LEDGER_V3_KEY_DISCOVERY|' || previousTag)
  algorithm = seed~algorithm~string~strip~upper
  keyId = seed~keyId~string~strip
  proof = .nil
  do tries = 1 to 3
    macText = self~v3MacText(sequence, state, executionKey, envelopeFingerprint, authorityFingerprint, attemptText, timestamp, previousTag, algorithm, keyId)
    proof = keyRing~sign(macText)
    if proof~algorithm~string~strip~upper = algorithm & proof~keyId~string~strip = keyId then leave
    algorithm = proof~algorithm~string~strip~upper
    keyId = proof~keyId~string~strip
  end
  if proof == .nil | proof~algorithm~string~strip~upper \= algorithm | proof~keyId~string~strip \= keyId then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_MAC_KEY_ROTATION_UNSTABLE')
  tag = proof~tag~string~strip~lower
  line = 'RYTA_QUEUE_AUTHORITY_LEDGER_V3|' || sequence || '|' || state || '|' || c2x(executionKey) || '|' || c2x(envelopeFingerprint) || '|' || c2x(authorityFingerprint) || '|' || c2x(attemptText) || '|' || c2x(timestamp) || '|' || previousTag || '|' || c2x(algorithm) || '|' || c2x(keyId) || '|' || tag
  stream = .Stream~new(path)
  openStatus = stream~open('write append')
  if openStatus \= 'READY:' then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_APPEND_FAILED:' openStatus)
  writeStatus = stream~lineOut(line)
  closeStatus = stream~close
  authenticatedTailTag = tag
  authenticatedRecordCount += 1
  authenticatedTailSequence = sequence
  nextSequence = sequence + 1
  return .true

::method v3MacText private
  use arg sequence, state, executionKey, envelopeFingerprint, authorityFingerprint, attemptText, timestamp, previousTag, algorithm, keyId
  text = 'RYTA_QUEUE_AUTHORITY_LEDGER_V3_MAC' || '0a'x
  text = text || self~field('SEQUENCE', sequence)
  text = text || self~field('STATE', state)
  text = text || self~field('EXECUTION_KEY', executionKey)
  text = text || self~field('ENVELOPE_FINGERPRINT', envelopeFingerprint)
  text = text || self~field('AUTHORITY_FINGERPRINT', authorityFingerprint)
  text = text || self~field('ATTEMPT', attemptText)
  text = text || self~field('TIMESTAMP', timestamp)
  text = text || self~field('PREVIOUS_TAG', previousTag)
  text = text || self~field('ALGORITHM', algorithm)
  text = text || self~field('KEY_ID', keyId)
  return text

::method parseRecord private
  use arg line
  parse var line magic '|' rest
  parsed = .directory~new
  if magic = 'RYTA_QUEUE_AUTHORITY_LEDGER_V1' then do
    parse var rest state '|' keyHex '|' authorityHex '|' attemptHex '|' timestampHex
    if state = '' | keyHex = '' | authorityHex = '' | attemptHex = '' | timestampHex = '' then return .nil
    envelopeHex = ''
    version = 'V1'
  end
  else if magic = 'RYTA_QUEUE_AUTHORITY_LEDGER_V2' then do
    parse var rest state '|' keyHex '|' envelopeHex '|' authorityHex '|' attemptHex '|' timestampHex
    if state = '' | keyHex = '' | envelopeHex = '' | authorityHex = '' | attemptHex = '' | timestampHex = '' then return .nil
    version = 'V2'
  end
  else if magic = 'RYTA_QUEUE_AUTHORITY_LEDGER_V3' then do
    parse var rest sequenceText '|' state '|' keyHex '|' envelopeHex '|' authorityHex '|' attemptHex '|' timestampHex '|' previousTag '|' algorithmHex '|' keyIdHex '|' tag
    if sequenceText = '' | state = '' | keyHex = '' | envelopeHex = '' | authorityHex = '' | attemptHex = '' | timestampHex = '' | previousTag = '' | algorithmHex = '' | keyIdHex = '' | tag = '' then return .nil
    if \datatype(sequenceText, 'W') then return .nil
    sequence = sequenceText + 0
    if sequence < 1 then return .nil
    if previousTag~length \= 32 | verify(previousTag, '0123456789abcdef') \= 0 then return .nil
    if tag~length \= 32 | verify(tag, '0123456789abcdef') \= 0 then return .nil
    version = 'V3'
  end
  else return .nil
  signal on syntax name malformed
  key = x2c(keyHex)
  authorityFingerprint = x2c(authorityHex)
  if version = 'V2' | version = 'V3' then envelopeFingerprint = x2c(envelopeHex)
  else envelopeFingerprint = ''
  attemptText = x2c(attemptHex)
  timestamp = x2c(timestampHex)
  if version = 'V3' then do
    algorithm = x2c(algorithmHex)
    keyId = x2c(keyIdHex)
  end
  signal off syntax
  parsed['version'] = version
  parsed['state'] = state
  parsed['key'] = key
  parsed['authority'] = authorityFingerprint
  parsed['envelope'] = envelopeFingerprint
  parsed['attempt'] = attemptText
  parsed['timestamp'] = timestamp
  if version = 'V3' then do
    parsed['sequence'] = sequence
    parsed['previousTag'] = previousTag~lower
    parsed['algorithm'] = algorithm
    parsed['keyId'] = keyId
    parsed['tag'] = tag~lower
  end
  return parsed
malformed:
  signal off syntax
  return .nil

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method zeroTag private
  return '00000000000000000000000000000000'

::method hasTerminalLineBreak private
  expose path
  stream = .Stream~new(path)
  if stream~query('exists') = '' then return .true
  openStatus = stream~open('read')
  if openStatus \= 'READY:' then raise syntax 93.900 additional('QUEUE_AUTHORITY_LEDGER_INSPECT_FAILED:' openStatus)
  count = stream~chars
  if count = 0 then do
    closeStatus = stream~close
    return .true
  end
  lastByte = stream~charIn(count, 1)
  closeStatus = stream~close
  if lastByte = '0a'x then return .true
  if lastByte = '0d'x then return .true
  return .false


::class QueueAuthorityRevalidationResult subclass RYTAObject public
::attribute ok get
::attribute code get
::attribute detail get
::attribute promotionSet get
::attribute consumerEvidence get
::attribute publicationId get
::attribute consumerContextIdentity get
::attribute revalidatorIdentity get
::attribute evaluatedAt get
::attribute workExecutionKey get
::attribute attemptIdentity get

::method init
  expose ok code detail promotionSet consumerEvidence publicationId consumerContextIdentity revalidatorIdentity evaluatedAt workExecutionKey attemptIdentity
  use arg okArg, codeArg, detailArg = '', promotionSetArg = .nil, consumerEvidenceArg = .nil, publicationIdArg = '', consumerContextIdentityArg = '', revalidatorIdentityArg = '', evaluatedAtArg = '', workExecutionKeyArg = '', attemptIdentityArg = ''
  self~init:super('QueueAuthorityRevalidationResult', 'CONSUMER_REVALIDATION_EVIDENCE')
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  promotionSet = promotionSetArg
  consumerEvidence = consumerEvidenceArg
  publicationId = publicationIdArg~string
  consumerContextIdentity = consumerContextIdentityArg~string
  revalidatorIdentity = revalidatorIdentityArg~string
  if evaluatedAtArg == '' then evaluatedAt = .DateTime~new~string
  else evaluatedAt = evaluatedAtArg~string
  workExecutionKey = workExecutionKeyArg~string
  attemptIdentity = attemptIdentityArg~string

::method success class
  use arg promotionSetArg, publicationIdArg, consumerContextIdentityArg, revalidatorIdentityArg, consumerEvidenceArg = .nil, detailArg = '', evaluatedAtArg = '', workExecutionKeyArg = '', attemptIdentityArg = ''
  return self~new(.true, 'REVALIDATED', detailArg, promotionSetArg, consumerEvidenceArg, publicationIdArg, consumerContextIdentityArg, revalidatorIdentityArg, evaluatedAtArg, workExecutionKeyArg, attemptIdentityArg)

::method failure class
  use arg codeArg, detailArg = '', publicationIdArg = '', consumerContextIdentityArg = '', revalidatorIdentityArg = '', consumerEvidenceArg = .nil, evaluatedAtArg = '', workExecutionKeyArg = '', attemptIdentityArg = ''
  return self~new(.false, codeArg, detailArg, .nil, consumerEvidenceArg, publicationIdArg, consumerContextIdentityArg, revalidatorIdentityArg, evaluatedAtArg, workExecutionKeyArg, attemptIdentityArg)

/* Stable authority-decision canonical form.  Per-delivery freshness binding is
   deliberately separate so ACK-only recovery can compare the immutable work
   envelope without turning a new claim into different work. */
::method algorithmCanonicalText
  expose ok code promotionSet publicationId consumerContextIdentity revalidatorIdentity
  text = 'RYTA_QUEUE_AUTHORITY_REVALIDATION_V1' || '0a'x
  text = text || self~field('OK', ok)
  text = text || self~field('CODE', code)
  text = text || self~field('PUBLICATION_ID', publicationId)
  text = text || self~field('CONSUMER_CONTEXT', consumerContextIdentity)
  text = text || self~field('REVALIDATOR', revalidatorIdentity)
  if promotionSet == .nil then promotionText = ''
  else promotionText = promotionSet~algorithmCanonicalText
  text = text || 'PROMOTIONS=' || promotionText~length || ':' || promotionText || '0a'x
  return text

::method executionBindingCanonicalText
  expose workExecutionKey attemptIdentity
  text = 'RYTA_QUEUE_AUTHORITY_REVALIDATION_BINDING_V1' || '0a'x
  text = text || self~field('WORK_EXECUTION_KEY', workExecutionKey)
  text = text || self~field('ATTEMPT_IDENTITY', attemptIdentity)
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x


::class QueueAuthorityExecutionResult subclass RYTAObject public
::attribute ok get
::attribute code get
::attribute detail get
::attribute workIdentity get
::attribute attemptEvidence get
::attribute applyResult get
::attribute ackCode get
::attribute ackDetail get
::attribute replaySuppressed get
::attribute revalidationEvidence get

::method init
  expose ok code detail workIdentity attemptEvidence applyResult ackCode ackDetail replaySuppressed revalidationEvidence
  use arg okArg, codeArg, detailArg = '', workIdentityArg = .nil, attemptEvidenceArg = .nil, applyResultArg = .nil, ackCodeArg = '', ackDetailArg = '', replaySuppressedArg = .false, revalidationEvidenceArg = .nil
  self~init:super('QueueAuthorityExecutionResult', 'QUEUE_EXECUTION_RESULT')
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  workIdentity = workIdentityArg
  attemptEvidence = attemptEvidenceArg
  applyResult = applyResultArg
  ackCode = ackCodeArg~string
  ackDetail = ackDetailArg~string
  replaySuppressed = replaySuppressedArg
  revalidationEvidence = revalidationEvidenceArg

::method success class
  use arg codeArg, detailArg = '', workIdentityArg = .nil, attemptEvidenceArg = .nil, applyResultArg = .nil, ackCodeArg = '', ackDetailArg = '', replaySuppressedArg = .false, revalidationEvidenceArg = .nil
  return self~new(.true, codeArg, detailArg, workIdentityArg, attemptEvidenceArg, applyResultArg, ackCodeArg, ackDetailArg, replaySuppressedArg, revalidationEvidenceArg)

::method failure class
  use arg codeArg, detailArg = '', workIdentityArg = .nil, attemptEvidenceArg = .nil, applyResultArg = .nil, ackCodeArg = '', ackDetailArg = '', revalidationEvidenceArg = .nil
  return self~new(.false, codeArg, detailArg, workIdentityArg, attemptEvidenceArg, applyResultArg, ackCodeArg, ackDetailArg, .false, revalidationEvidenceArg)


::class QueueAuthorityPromotionExecutor public


::method execute class
  use arg queueManager, queueName, package, claimToken, principal, promotionSet, world, executionNamespace, ledger, transferReceipt = .nil, consumerRevalidator = .nil

  surfaceCheck = self~validateSurface(queueManager, package, promotionSet, world, ledger)
  if surfaceCheck \== '' then return .QueueAuthorityExecutionResult~failure(surfaceCheck)
  if executionNamespace~string~strip = '' then return .QueueAuthorityExecutionResult~failure('QUEUE_EXECUTION_NAMESPACE_REQUIRED')
  if package~state~string~upper \= 'INFLIGHT' then return .QueueAuthorityExecutionResult~failure('PACKAGE_NOT_CLAIMED')
  if package~currentQueue~string \= queueName~string then return .QueueAuthorityExecutionResult~failure('PACKAGE_QUEUE_MISMATCH')
  if package~claimedBy~string \= principal~string then return .QueueAuthorityExecutionResult~failure('CLAIM_PRINCIPAL_MISMATCH')
  /* claimToken is deliberately compared only here and never retained below. */
  if package~claimToken~string \= claimToken~string then return .QueueAuthorityExecutionResult~failure('CLAIM_TOKEN_MISMATCH')
  if \promotionSet~sealed then return .QueueAuthorityExecutionResult~failure('PROMOTION_SET_NOT_SEALED')

  identityResult = self~buildIdentity(queueManager, executionNamespace, queueName, package, transferReceipt)
  if \identityResult['ok'] then return .QueueAuthorityExecutionResult~failure(identityResult['code'], identityResult['detail'])
  workIdentity = identityResult['identity']
  attemptEvidence = .QueueAuthorityAttemptEvidence~new(workIdentity, package, identityResult['receipt'])

  executionKey = workIdentity~executionKey
  envelopeFingerprint = self~envelopeFingerprint(workIdentity, promotionSet, package)
  if left(executionKey, 10) = 'HASH_ERROR' then return .QueueAuthorityExecutionResult~failure('EXECUTION_KEY_HASH_FAILED', executionKey, workIdentity, attemptEvidence)
  if left(envelopeFingerprint, 10) = 'HASH_ERROR' then return .QueueAuthorityExecutionResult~failure('WORK_ENVELOPE_HASH_FAILED', envelopeFingerprint, workIdentity, attemptEvidence)

  /* v0.27 checks authenticated durable execution state before minting any new
     authority.  Only a MAC-verified V3 COMPLETE can authorize ACK-only cleanup.
     Legacy V1/V2 state is readable evidence but is never trusted for recovery. */
  signal on syntax name ledgerPreflightFailure
  preflight = ledger~preflightCurrent(executionKey, envelopeFingerprint)
  signal off syntax
  if \preflight~ok then return .QueueAuthorityExecutionResult~failure(preflight~code, preflight~detail, workIdentity, attemptEvidence)
  if preflight~code = 'ALREADY_COMPLETE' then do
    ackResult = queueManager~ack(queueName, package~packageId, claimToken, principal)
    if \ackResult~ok then return .QueueAuthorityExecutionResult~failure('ACK_FAILED_AFTER_PRIOR_COMPLETE', ackResult~detail, workIdentity, attemptEvidence, .nil, ackResult~code, ackResult~detail)
    return .QueueAuthorityExecutionResult~success('ALREADY_COMPLETE_ACKED', 'ACK-only recovery after durable COMPLETE; no authority re-evaluation or mutation', workIdentity, attemptEvidence, .nil, ackResult~code, ackResult~detail, .true, .nil)
  end

  effectivePromotionSet = promotionSet
  revalidationEvidence = .nil
  if self~isRetainedReplay(package) then do
    revalidationResult = self~revalidateRetained(package, promotionSet, world, workIdentity, attemptEvidence, consumerRevalidator)
    if \revalidationResult['ok'] then return .QueueAuthorityExecutionResult~failure(revalidationResult['code'], revalidationResult['detail'], workIdentity, attemptEvidence, .nil, '', '', revalidationResult['evidence'])
    effectivePromotionSet = revalidationResult['promotionSet']
    revalidationEvidence = revalidationResult['evidence']
  end

  authorityFingerprint = self~workFingerprint(workIdentity, effectivePromotionSet, revalidationEvidence)
  if left(authorityFingerprint, 10) = 'HASH_ERROR' then return .QueueAuthorityExecutionResult~failure('AUTHORITY_DECISION_HASH_FAILED', authorityFingerprint, workIdentity, attemptEvidence, .nil, '', '', revalidationEvidence)

  signal on syntax name ledgerBeginFailure
  beginDecision = ledger~beginCurrent(executionKey, envelopeFingerprint, authorityFingerprint, attemptEvidence)
  signal off syntax
  if beginDecision~code = 'ALREADY_COMPLETE' then do
    /* A concurrently completed current record may arrive here.  Current
       preflight semantics ensure only authenticated V3 completion is recoverable. */
    ackResult = queueManager~ack(queueName, package~packageId, claimToken, principal)
    if \ackResult~ok then return .QueueAuthorityExecutionResult~failure('ACK_FAILED_AFTER_PRIOR_COMPLETE', ackResult~detail, workIdentity, attemptEvidence, .nil, ackResult~code, ackResult~detail, revalidationEvidence)
    return .QueueAuthorityExecutionResult~success('ALREADY_COMPLETE_ACKED', executionKey, workIdentity, attemptEvidence, .nil, ackResult~code, ackResult~detail, .true, revalidationEvidence)
  end
  if \beginDecision~ok then return .QueueAuthorityExecutionResult~failure(beginDecision~code, beginDecision~detail, workIdentity, attemptEvidence, .nil, '', '', revalidationEvidence)

  signal on syntax name applyFailure
  applyResult = .EvidencePromotionApplier~apply(effectivePromotionSet, world)
  signal off syntax

  signal on syntax name ledgerCompleteFailure
  completeDecision = ledger~completeCurrent(executionKey, envelopeFingerprint, authorityFingerprint, attemptEvidence)
  signal off syntax
  if \completeDecision~ok then return .QueueAuthorityExecutionResult~failure(completeDecision~code, completeDecision~detail, workIdentity, attemptEvidence, applyResult, '', '', revalidationEvidence)

  ackResult = queueManager~ack(queueName, package~packageId, claimToken, principal)
  if \ackResult~ok then return .QueueAuthorityExecutionResult~failure('ACK_FAILED_AFTER_COMPLETE', ackResult~detail, workIdentity, attemptEvidence, applyResult, ackResult~code, ackResult~detail, revalidationEvidence)
  return .QueueAuthorityExecutionResult~success('APPLIED_AND_ACKED', executionKey, workIdentity, attemptEvidence, applyResult, ackResult~code, ackResult~detail, .false, revalidationEvidence)

ledgerPreflightFailure:
  signal off syntax
  return .QueueAuthorityExecutionResult~failure('LEDGER_PREFLIGHT_FAILED', condition('D'), workIdentity, attemptEvidence)

ledgerBeginFailure:
  signal off syntax
  return .QueueAuthorityExecutionResult~failure('LEDGER_BEGIN_FAILED', condition('D'), workIdentity, attemptEvidence, .nil, '', '', revalidationEvidence)

applyFailure:
  signal off syntax
  return .QueueAuthorityExecutionResult~failure('PROMOTION_APPLY_FAILED', condition('D'), workIdentity, attemptEvidence, .nil, '', '', revalidationEvidence)

ledgerCompleteFailure:
  signal off syntax
  return .QueueAuthorityExecutionResult~failure('COMPLETION_RECORD_FAILED_AFTER_APPLY', condition('D'), workIdentity, attemptEvidence, applyResult, '', '', revalidationEvidence)

::method envelopeFingerprint class
  use arg workIdentity, publisherPromotionSet, package = .nil
  if workIdentity == .nil | publisherPromotionSet == .nil then return 'HASH_ERROR_INPUT'
  if \publisherPromotionSet~sealed then return 'HASH_ERROR_UNSEALED_PROMOTION_SET'
  identityText = workIdentity~algorithmCanonicalText
  promotionText = publisherPromotionSet~algorithmCanonicalText
  retained = .false
  publicationId = ''
  if package \== .nil then do
    retained = self~isRetainedReplay(package)
    if retained then do
      headers = package~headers
      value = headers~at('oqf.topic.publication_id')
      if value \== .nil then publicationId = value~string
    end
  end
  canonical = 'RYTA_QUEUE_AUTHORITY_WORK_ENVELOPE_V1' || '0a'x
  canonical = canonical || 'IDENTITY=' || identityText~length || ':' || identityText || '0a'x
  canonical = canonical || 'PUBLISHER_PROMOTIONS=' || promotionText~length || ':' || promotionText || '0a'x
  canonical = canonical || 'RETAINED=' || retained || '0a'x
  canonical = canonical || 'PUBLICATION_ID=' || publicationId~length || ':' || publicationId || '0a'x
  return .AlgorithmDigest~sha256Text(canonical)

::method attemptIdentity class
  use arg attemptEvidence
  if attemptEvidence == .nil then return 'HASH_ERROR_ATTEMPT_REQUIRED'
  if \attemptEvidence~hasMethod('ALGORITHMCANONICALTEXT') then return 'HASH_ERROR_ATTEMPT_SURFACE'
  return .AlgorithmDigest~sha256Text(attemptEvidence~algorithmCanonicalText)

::method workFingerprint class
  use arg workIdentity, promotionSet, revalidationEvidence = .nil
  if workIdentity == .nil | promotionSet == .nil then return 'HASH_ERROR_INPUT'
  if \promotionSet~sealed then return 'HASH_ERROR_UNSEALED_PROMOTION_SET'
  identityText = workIdentity~algorithmCanonicalText
  promotionText = promotionSet~algorithmCanonicalText
  canonical = 'RYTA_QUEUE_AUTHORITY_WORK_FINGERPRINT_V2' || '0a'x || 'IDENTITY=' || identityText~length || ':' || identityText || '0a'x || 'PROMOTIONS=' || promotionText~length || ':' || promotionText || '0a'x
  if revalidationEvidence \== .nil then do
    if \revalidationEvidence~hasMethod('ALGORITHMCANONICALTEXT') then return 'HASH_ERROR_REVALIDATION_SURFACE'
    revalidationText = revalidationEvidence~algorithmCanonicalText
    canonical = canonical || 'REVALIDATION=' || revalidationText~length || ':' || revalidationText || '0a'x
  end
  return .AlgorithmDigest~sha256Text(canonical)

::method isRetainedReplay private class
  use arg package
  if package == .nil then return .false
  if \package~hasMethod('HEADERS') then return .false
  headers = package~headers
  if headers == .nil then return .false
  value = headers~at('oqf.topic.retained')
  if value == .nil then return .false
  return self~truth(value)

::method revalidateRetained private class
  use arg package, publisherPromotionSet, world, workIdentity, attemptEvidence, consumerRevalidator
  out = .directory~new
  out['ok'] = .false
  out['code'] = ''
  out['detail'] = ''
  out['promotionSet'] = .nil
  out['evidence'] = .nil
  headers = package~headers
  publicationId = headers~at('oqf.topic.publication_id')
  if publicationId == .nil | publicationId~string~strip = '' then do
    out['code'] = 'RETAINED_PUBLICATION_ID_REQUIRED'
    return out
  end
  publicationId = publicationId~string
  if consumerRevalidator == .nil then do
    out['code'] = 'RETAINED_AUTHORITY_REVALIDATION_REQUIRED'
    out['detail'] = publicationId
    return out
  end
  if \consumerRevalidator~hasMethod('REVALIDATE') then do
    out['code'] = 'RETAINED_AUTHORITY_REVALIDATOR_SURFACE_INVALID'
    return out
  end
  signal on syntax name revalidationFailed
  evidence = consumerRevalidator~revalidate(package, publisherPromotionSet, world, workIdentity, attemptEvidence)
  signal off syntax
  if evidence == .nil then do
    out['code'] = 'RETAINED_AUTHORITY_REVALIDATION_RESULT_REQUIRED'
    return out
  end
  required = .array~of('OK', 'CODE', 'DETAIL', 'PROMOTIONSET', 'PUBLICATIONID', 'CONSUMERCONTEXTIDENTITY', 'REVALIDATORIDENTITY', 'WORKEXECUTIONKEY', 'ATTEMPTIDENTITY', 'ALGORITHMCANONICALTEXT', 'EXECUTIONBINDINGCANONICALTEXT')
  do methodName over required
    if \evidence~hasMethod(methodName) then do
      out['code'] = 'RETAINED_AUTHORITY_REVALIDATION_RESULT_SURFACE_INVALID'
      out['detail'] = methodName
      out['evidence'] = evidence
      return out
    end
  end
  out['evidence'] = evidence
  if evidence~publicationId~string \= publicationId then do
    out['code'] = 'RETAINED_AUTHORITY_PUBLICATION_MISMATCH'
    out['detail'] = publicationId || '<>' || evidence~publicationId~string
    return out
  end
  /* Preserve the revalidator's real refusal/error code. Successful authority
     projections must additionally carry auditable context/revalidator identity. */
  if \evidence~ok then do
    out['code'] = evidence~code~string
    if out['code'] = '' then out['code'] = 'RETAINED_AUTHORITY_REVALIDATION_REFUSED'
    out['detail'] = evidence~detail~string
    return out
  end
  if evidence~consumerContextIdentity~string~strip = '' then do
    out['code'] = 'RETAINED_AUTHORITY_CONSUMER_CONTEXT_REQUIRED'
    return out
  end
  if evidence~revalidatorIdentity~string~strip = '' then do
    out['code'] = 'RETAINED_AUTHORITY_REVALIDATOR_IDENTITY_REQUIRED'
    return out
  end
  if evidence~workExecutionKey~string \= workIdentity~executionKey~string then do
    out['code'] = 'RETAINED_AUTHORITY_WORK_BINDING_MISMATCH'
    out['detail'] = workIdentity~executionKey~string || '<>' || evidence~workExecutionKey~string
    return out
  end
  expectedAttemptIdentity = self~attemptIdentity(attemptEvidence)
  if left(expectedAttemptIdentity, 10) = 'HASH_ERROR' then do
    out['code'] = 'RETAINED_AUTHORITY_ATTEMPT_IDENTITY_FAILED'
    out['detail'] = expectedAttemptIdentity
    return out
  end
  if evidence~attemptIdentity~string \= expectedAttemptIdentity then do
    out['code'] = 'RETAINED_AUTHORITY_ATTEMPT_BINDING_MISMATCH'
    out['detail'] = expectedAttemptIdentity || '<>' || evidence~attemptIdentity~string
    return out
  end
  effectiveSet = evidence~promotionSet
  if effectiveSet == .nil then do
    out['code'] = 'RETAINED_AUTHORITY_CONSUMER_PROMOTION_SET_REQUIRED'
    return out
  end
  if effectiveSet == publisherPromotionSet then do
    out['code'] = 'RETAINED_AUTHORITY_REUSED_PUBLISHER_PROMOTION_SET'
    return out
  end
  if \effectiveSet~hasMethod('SEALED') | \effectiveSet~hasMethod('ALGORITHMCANONICALTEXT') then do
    out['code'] = 'RETAINED_AUTHORITY_CONSUMER_PROMOTION_SURFACE_INVALID'
    return out
  end
  if \effectiveSet~sealed then do
    out['code'] = 'RETAINED_AUTHORITY_CONSUMER_PROMOTION_SET_NOT_SEALED'
    return out
  end
  /* Object inequality is not enough: a copied publisher set is still stale authority. */
  if effectiveSet~algorithmCanonicalText == publisherPromotionSet~algorithmCanonicalText then do
    out['code'] = 'RETAINED_AUTHORITY_REUSED_PUBLISHER_PROMOTION_SEMANTICS'
    return out
  end
  out['ok'] = .true
  out['code'] = 'RETAINED_AUTHORITY_REVALIDATED'
  out['promotionSet'] = effectiveSet
  return out
revalidationFailed:
  signal off syntax
  out['code'] = 'RETAINED_AUTHORITY_REVALIDATION_FAILED'
  out['detail'] = condition('D')
  return out

::method truth private class
  use arg value
  text = value~string~strip~translate
  return text = '1' | text = 'TRUE' | text = 'YES' | text = 'ON'

::method buildIdentity private class
  use arg queueManager, executionNamespace, queueName, package, transferReceipt
  identityMap = .directory~new
  identityMap['ok'] = .false
  identityMap['code'] = ''
  identityMap['detail'] = ''
  identityMap['identity'] = .nil
  identityMap['receipt'] = .nil

  if transferReceipt == .nil then do
    identity = .QueueAuthorityWorkIdentity~new(executionNamespace, queueName, package~packageId, 'LOCAL', '', '', package~parentPackageId, package~requestedQueue, package~createdAt, package~priority, package~persistent, package~securityDomain, package~routingKey, package~correlationId, package~replyTo, '')
    identityMap['ok'] = .true
    identityMap['identity'] = identity
    identityMap['receipt'] = .nil
    return identityMap
  end

  required = .array~of('TRANSFERID', 'PACKAGEID', 'QUEUENAME', 'SOURCEMANAGER')
  do methodName over required
    if \transferReceipt~hasMethod(methodName) then do
      identityMap['code'] = 'TRANSFER_RECEIPT_SURFACE_INVALID'
      identityMap['detail'] = methodName
      return identityMap
    end
  end
  if transferReceipt~transferId~string~strip = '' then do
    identityMap['code'] = 'TRANSFER_ID_REQUIRED'
    return identityMap
  end
  if \queueManager~hasMethod('TRANSFERRECEIPT') then do
    identityMap['code'] = 'QUEUE_MANAGER_TRANSFER_RECEIPT_REQUIRED'
    return identityMap
  end
  registeredReceipt = queueManager~transferReceipt(transferReceipt~transferId)
  if registeredReceipt == .nil then do
    identityMap['code'] = 'TRANSFER_RECEIPT_NOT_REGISTERED'
    return identityMap
  end
  if transferReceipt~packageId~string \= registeredReceipt~packageId~string | transferReceipt~queueName~string \= registeredReceipt~queueName~string | transferReceipt~sourceManager~string \= registeredReceipt~sourceManager~string then do
    identityMap['code'] = 'TRANSFER_RECEIPT_REGISTRY_MISMATCH'
    return identityMap
  end
  if registeredReceipt~packageId~string \= package~packageId~string then do
    identityMap['code'] = 'TRANSFER_RECEIPT_PACKAGE_MISMATCH'
    return identityMap
  end
  if registeredReceipt~queueName~string \= queueName~string then do
    identityMap['code'] = 'TRANSFER_RECEIPT_QUEUE_MISMATCH'
    return identityMap
  end
  identity = .QueueAuthorityWorkIdentity~new(executionNamespace, queueName, package~packageId, 'TRANSFER', registeredReceipt~transferId, registeredReceipt~sourceManager, package~parentPackageId, package~requestedQueue, package~createdAt, package~priority, package~persistent, package~securityDomain, package~routingKey, package~correlationId, package~replyTo, registeredReceipt~acceptedAt)
  identityMap['ok'] = .true
  identityMap['identity'] = identity
  identityMap['receipt'] = registeredReceipt
  return identityMap

::method validateSurface private class
  use arg queueManager, package, promotionSet, world, ledger
  if queueManager == .nil then return 'QUEUE_MANAGER_REQUIRED'
  if package == .nil then return 'QUEUE_PACKAGE_REQUIRED'
  if promotionSet == .nil then return 'PROMOTION_SET_REQUIRED'
  if world == .nil then return 'HARDWORLD_REQUIRED'
  if ledger == .nil then return 'QUEUE_AUTHORITY_LEDGER_REQUIRED'
  if \queueManager~hasMethod('ACK') then return 'QUEUE_MANAGER_ACK_REQUIRED'
  requiredPackageMethods = .array~of('PACKAGEID', 'HEADERS', 'CURRENTQUEUE', 'PARENTPACKAGEID', 'REQUESTEDQUEUE', 'CREATEDAT', 'PRIORITY', 'PERSISTENT', 'SECURITYDOMAIN', 'ROUTINGKEY', 'CORRELATIONID', 'REPLYTO', 'STATE', 'CLAIMEDBY', 'CLAIMTOKEN', 'CLAIMEDAT', 'DELIVERYCOUNT', 'BACKOUTCOUNT')
  do methodName over requiredPackageMethods
    if \package~hasMethod(methodName) then return 'QUEUE_PACKAGE_SURFACE_INVALID:' || methodName
  end
  if \promotionSet~hasMethod('SEALED') | \promotionSet~hasMethod('ALGORITHMCANONICALTEXT') then return 'PROMOTION_SET_SURFACE_INVALID'
  requiredLedgerMethods = .array~of('PREFLIGHTCURRENT', 'BEGINCURRENT', 'COMPLETECURRENT')
  do methodName over requiredLedgerMethods
    if \ledger~hasMethod(methodName) then return 'QUEUE_AUTHORITY_LEDGER_SURFACE_INVALID:' || methodName
  end
  return ''

::requires '../algorithm/AlgorithmIntegrity.cls'
::requires '../algorithm/EvidencePromotion.cls'

::requires "RYTAObject.cls"
