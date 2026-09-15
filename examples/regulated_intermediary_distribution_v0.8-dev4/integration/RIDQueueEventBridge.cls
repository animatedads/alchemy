/*
 * Queue Fabric service boundary for provider status events.
 *
 * Important semantic split:
 *   ingress -> signature-verified canonical event -> idempotent case projection
 *           -> retained live status topic
 *
 * Notifications consume the projection event; they never determine case state.
 */

::class RIDQueueEventBridge public
::attribute queueManager get
::attribute topicFabric get
::attribute ingressQueue get
::attribute canonicalQueue get
::attribute auditQueue get
::attribute deadLetterQueue get
::attribute wireStatusQueue get
::attribute statusTopic get
::attribute expiryTombstoneQueue get

::method init
  expose queueManager topicFabric engine signatureService adminPrincipal ingressQueue canonicalQueue auditQueue deadLetterQueue wireStatusQueue statusTopic expiryTombstoneQueue
  use arg queueManagerArg, engineArg, signatureServiceArg, adminPrincipalArg = "RID_ADMIN"
  queueManager = queueManagerArg
  engine = engineArg
  signatureService = signatureServiceArg
  adminPrincipal = adminPrincipalArg~string
  topicFabric = .QueueTopicFabric~new(queueManager, adminPrincipal)
  ingressQueue = "RID.PROVIDER.INGRESS"
  canonicalQueue = "RID.CASE.CANONICAL"
  auditQueue = "RID.CASE.AUDIT"
  deadLetterQueue = "RID.PROVIDER.DLQ"
  wireStatusQueue = "RID.WIRE.STATUS"
  statusTopic = "RID.CASE.STATUS"
  expiryTombstoneQueue = "RID.EXPIRY.TOMBSTONE"

::method configure
  expose queueManager topicFabric adminPrincipal ingressQueue canonicalQueue auditQueue deadLetterQueue wireStatusQueue statusTopic expiryTombstoneQueue
  domain = "FEDERATION_INTERMEDIARY"
  do qname over .array~of(ingressQueue, canonicalQueue, auditQueue, deadLetterQueue, expiryTombstoneQueue, wireStatusQueue)
    if queueManager~queue(qname) == .nil then do
      r = queueManager~createQueue(qname, "PERMANENT", domain, 0, adminPrincipal, adminPrincipal)
      if \r~ok then return .RIDResult~failure("QUEUE_CONFIG_FAILED", qname || ":" || r~code || ":" || r~detail)
    end
  end
  r = queueManager~setDeadLetterQueue(expiryTombstoneQueue, adminPrincipal)
  if \r~ok then return .RIDResult~failure("QUEUE_CONFIG_FAILED", r~code || ":" || r~detail)
  r = queueManager~configureBackout(ingressQueue, 3, deadLetterQueue, adminPrincipal)
  if \r~ok then return .RIDResult~failure("QUEUE_CONFIG_FAILED", r~code || ":" || r~detail)
  r = queueManager~configureBackout(canonicalQueue, 3, deadLetterQueue, adminPrincipal)
  if \r~ok then return .RIDResult~failure("QUEUE_CONFIG_FAILED", r~code || ":" || r~detail)
  if topicFabric~topic(statusTopic) == .nil then do
    r = topicFabric~defineTopic(statusTopic, "rid/case/status", "PERMANENT", domain, adminPrincipal)
    if \r~ok then return .RIDResult~failure("TOPIC_CONFIG_FAILED", r~code || ":" || r~detail)
  end
  if topicFabric~subscription("RID.WIRE.STATUS.ALL") == .nil then do
    options = .table~new
    options["deliverRetained"] = .true
    r = topicFabric~subscribe("RID.WIRE.STATUS.ALL", statusTopic, "#", wireStatusQueue, "PERMANENT", adminPrincipal, options)
    if \r~ok then return .RIDResult~failure("TOPIC_CONFIG_FAILED", r~code || ":" || r~detail)
  end
  return .RIDResult~success(self)

::method signedEventToWire private
  use arg caseId, signedEvent
  e = signedEvent~statusEvidence
  d = .directory~new
  d["schema"] = "regulated.intermediary.provider-status/1"
  d["case_id"] = caseId~string~upper
  d["event_id"] = e~eventId
  d["provider_entity_id"] = e~providerEntityId
  d["provider_system"] = e~providerSystem
  d["provider_case_ref"] = e~providerCaseRef
  d["product_semantic_identity"] = e~productSemanticIdentity
  d["sequence"] = e~sequence~string
  d["status"] = e~status
  d["occurred_at"] = e~occurredAt~string
  d["source_ref"] = e~sourceRef
  d["signer_ref"] = signedEvent~signerRef
  d["key_id"] = signedEvent~keyId
  d["algorithm"] = signedEvent~algorithm
  d["signature_hex"] = signedEvent~signatureHex
  d["signed_at"] = signedEvent~signedAt~string
  d["authentication_ref"] = signedEvent~authenticationRef
  return d

::method wireToSignedEvent private
  use arg d
  if d == .nil then return .RIDResult~failure("INVALID_PROVIDER_WIRE_EVENT")
  if d["schema"] <> "regulated.intermediary.provider-status/1" then return .RIDResult~failure("INVALID_PROVIDER_WIRE_SCHEMA")
  signal on syntax name malformed
  e = .RIDProviderStatusEvidence~new(d["event_id"], d["provider_entity_id"], d["provider_system"], d["provider_case_ref"], d["product_semantic_identity"], d["sequence"] + 0, d["status"], d["occurred_at"], d["source_ref"])
  signed = .RIDSignedProviderStatusEvent~new(e, d["signer_ref"], d["key_id"], d["signature_hex"], d["signed_at"], d["authentication_ref"], d["algorithm"])
  signal off syntax
  return .RIDResult~success(signed)
malformed:
  signal off syntax
  return .RIDResult~failure("INVALID_PROVIDER_WIRE_EVENT")

::method queueOptions private
  use arg caseId, eventId, priority = 10
  options = .table~new
  options["persistent"] = .true
  options["correlationId"] = caseId~string~upper
  options["priority"] = priority
  headers = .table~new
  headers["rid_schema"] = "regulated.intermediary.provider-status/1"
  headers["rid_event_id"] = eventId~string~upper
  options["headers"] = headers
  return options

::method enqueueProviderStatus
  expose queueManager ingressQueue adminPrincipal
  use arg caseId, signedEvent
  if signedEvent == .nil then return .RIDResult~failure("INVALID_SIGNED_PROVIDER_EVENT")
  status = signedEvent~statusEvidence~status
  if status = "APPROVED" | status = "DECLINED" | status = "REJECTED" | status = "BOUND" then priority = 50
  else priority = 10
  wire = self~signedEventToWire(caseId, signedEvent)
  r = queueManager~put(ingressQueue, wire, self~queueOptions(caseId, signedEvent~statusEvidence~eventId, priority), adminPrincipal)
  if \r~ok then return .RIDResult~failure("PROVIDER_EVENT_ENQUEUE_FAILED", r~code || ":" || r~detail)
  return .RIDResult~success(r~value)

::method canonicalizeOne
  expose queueManager signatureService adminPrincipal ingressQueue canonicalQueue deadLetterQueue
  br = queueManager~beginUnitOfWork(adminPrincipal)
  if \br~ok then return .RIDResult~failure("QUEUE_UOW_BEGIN_FAILED", br~code)
  uow = br~value
  gr = queueManager~uowGet(uow, ingressQueue)
  if \gr~ok then do
    ignore = queueManager~rollbackUnitOfWork(uow)
    return .RIDResult~failure(gr~code, gr~detail)
  end
  pkg = gr~value
  caseId = pkg~correlationId
  decoded = self~wireToSignedEvent(pkg~payload)
  if decoded~ok then verified = signatureService~verifyProviderStatus(decoded~value)
  else verified = decoded
  options = self~queueOptions(caseId, pkg~headers["rid_event_id"], pkg~priority)
  if \verified~ok then do
    dlq = pkg~payload~copy
    dlq["rid_disposition"] = "SIGNATURE_REJECTED"
    dlq["rid_reject_code"] = verified~code
    pr = queueManager~uowPut(uow, deadLetterQueue, dlq, options)
    if \pr~ok then do
      ignore = queueManager~rollbackUnitOfWork(uow)
      return .RIDResult~failure("QUEUE_DLQ_STAGE_FAILED", pr~code)
    end
    cr = queueManager~commitUnitOfWork(uow)
    if \cr~ok then return .RIDResult~failure("QUEUE_UOW_COMMIT_FAILED", cr~code)
    return .RIDResult~failure(verified~code, verified~detail)
  end
  pr = queueManager~uowPut(uow, canonicalQueue, pkg~payload, options)
  if \pr~ok then do
    ignore = queueManager~rollbackUnitOfWork(uow)
    return .RIDResult~failure("QUEUE_CANONICAL_STAGE_FAILED", pr~code)
  end
  cr = queueManager~commitUnitOfWork(uow)
  if \cr~ok then return .RIDResult~failure("QUEUE_UOW_COMMIT_FAILED", cr~code)
  return .RIDResult~success(verified~value)

::method projectionForCase private
  use arg c, sourceEventId
  d = .directory~new
  d["schema"] = "regulated.intermediary.case-status-projection/1"
  d["case_id"] = c~caseId
  d["workflow_state"] = c~state
  d["provider_status"] = c~providerStatus
  d["provider_sequence"] = c~providerSequence~string
  d["provider_event_id"] = c~providerEventId
  d["provider_case_ref"] = c~providerCaseRef
  d["product_ref_id"] = c~productRefId
  d["product_semantic_identity"] = c~productSemanticIdentity
  d["firm_id"] = c~firmId
  d["representative_id"] = c~representativeId
  d["source_event_id"] = sourceEventId~string~upper
  d["updated_at"] = c~updatedAt~string
  return d

::method projectOne
  expose queueManager topicFabric engine adminPrincipal canonicalQueue auditQueue deadLetterQueue statusTopic
  br = queueManager~beginUnitOfWork(adminPrincipal)
  if \br~ok then return .RIDResult~failure("QUEUE_UOW_BEGIN_FAILED", br~code)
  uow = br~value
  gr = queueManager~uowGet(uow, canonicalQueue)
  if \gr~ok then do
    ignore = queueManager~rollbackUnitOfWork(uow)
    return .RIDResult~failure(gr~code, gr~detail)
  end
  pkg = gr~value
  decoded = self~wireToSignedEvent(pkg~payload)
  if \decoded~ok then do
    options = self~queueOptions(pkg~correlationId, pkg~headers["rid_event_id"], pkg~priority)
    dlq = pkg~payload~copy; dlq["rid_disposition"] = "CANONICAL_DECODE_REJECTED"; dlq["rid_reject_code"] = decoded~code
    ignore = queueManager~uowPut(uow, deadLetterQueue, dlq, options)
    ignore = queueManager~commitUnitOfWork(uow)
    return decoded
  end
  signed = decoded~value
  r = engine~recordProviderStatus(pkg~correlationId, signed~statusEvidence, signed~signerRef, "SIGNED_PROVIDER")
  disposition = "PROJECTED"
  publish = .false
  if r~ok then do
    if r~detail = "PROVIDER_EVENT_DUPLICATE" then disposition = "DUPLICATE_IGNORED"
    else publish = .true
  end
  else if r~code = "STALE_PROVIDER_STATUS" then disposition = "STALE_IGNORED"
  else do
    options = self~queueOptions(pkg~correlationId, signed~statusEvidence~eventId, pkg~priority)
    dlq = pkg~payload~copy; dlq["rid_disposition"] = "PROJECTION_REJECTED"; dlq["rid_reject_code"] = r~code
    ignore = queueManager~uowPut(uow, deadLetterQueue, dlq, options)
    cr = queueManager~commitUnitOfWork(uow)
    if \cr~ok then return .RIDResult~failure("QUEUE_UOW_COMMIT_FAILED", cr~code)
    return r
  end
  c = engine~case(pkg~correlationId)
  audit = self~projectionForCase(c, signed~statusEvidence~eventId)
  audit["rid_disposition"] = disposition
  options = self~queueOptions(pkg~correlationId, signed~statusEvidence~eventId, pkg~priority)
  ar = queueManager~uowPut(uow, auditQueue, audit, options)
  if \ar~ok then do
    ignore = queueManager~rollbackUnitOfWork(uow)
    return .RIDResult~failure("QUEUE_AUDIT_STAGE_FAILED", ar~code)
  end
  cr = queueManager~commitUnitOfWork(uow)
  if \cr~ok then return .RIDResult~failure("QUEUE_UOW_COMMIT_FAILED", cr~code)
  if publish then do
    projection = self~projectionForCase(c, signed~statusEvidence~eventId)
    pubOptions = .table~new
    pubOptions["subtopic"] = c~caseId
    pubOptions["persistent"] = .true
    pubOptions["retain"] = .true
    pubOptions["correlationId"] = c~caseId
    pubOptions["priority"] = pkg~priority
    /* A stable publication id makes the business identity visible in traffic;
       subscribers still compare provider_sequence for idempotent UI updates. */
    pubOptions["publicationId"] = "RID-STATUS-" || signed~statusEvidence~eventId
    pr = topicFabric~publish(statusTopic, projection, pubOptions, adminPrincipal)
    if \pr~ok then return .RIDResult~failure("STATUS_TOPIC_PUBLISH_FAILED", pr~code || ":" || pr~detail)
  end
  return .RIDResult~success(c, disposition)

::requires "RegulatedIntermediaryDistribution.cls"
::requires "RIDDigitalSigning.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"
