/*
 * Relationship Case Service v0.1
 *
 * Durable, policy-governed service boundary around Relationship Case.
 * This package coordinates case work. It does not become CRM, Core Banking,
 * Legal, Compliance, Reputation, Interaction, or Ledger authority.
 */
::class RelationshipCaseServiceBuild public
::constant VERSION "0.1"
::constant API_VERSION "relationship.case.service/0.1"
::constant STATE_FORMAT "relationship.case.service.state/1"
::constant SERVICE_ID "RELATIONSHIP_CASE_SERVICE"

::class RelationshipCaseServiceCanonical public
::method token class
  use arg value
  if value == .nil then return ""
  return value~string~strip~upper
::method field class
  use arg tag, value = ""
  if value == .nil then text = "<NIL>"
  else text = value~string
  return tag~string || ":" || text~length || ":" || text
::method copyArray class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source; out~append(item); end
  return out
::method value class
  use arg value
  if value == .nil then return "N"
  if value~class == .String then return "S" || self~field("V", value)
  if value~class == .Array then do
    text = "A"
    do i = 1 to value~items
      text ||= self~field("I", self~value(value[i]))
    end
    return text
  end
  classId = value~class~id
  if classId = "Table" | classId = "Directory" | classId = "IdentityTable" then do
    rows = .array~new
    supplier = value~supplier
    do while supplier~available
      rows~append(self~field("K", supplier~index~string) || self~field("V", self~value(supplier~item)))
      supplier~next
    end
    rows~sort
    text = "M"
    do row over rows; text ||= self~field("R", row); end
    return text
  end
  if value~hasMethod("SEMANTICIDENTITY") then return "O" || self~field("ID", value~semanticIdentity)
  if value~hasMethod("QUEUEPERSISTENTTYPE") then return "P" || self~field("T", value~queuePersistentType) || self~field("S", self~value(value~queuePersistentState))
  return "X" || self~field("C", classId) || self~field("V", value~string)

::class RelationshipCaseServiceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = okArg; code = codeArg~string; detail = detailArg~string; value = valueArg
::method success class
  use arg value = .nil, detail = ""
  return self~new(.true, "OK", detail, value)
::method failure class
  use arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)

::class RelationshipCaseServiceEnvelope public
::attribute commandId get
::attribute commandType get
::attribute correlationId get
::attribute causationId get
::attribute actorId get
::attribute actorRole get
::attribute requestedAt get
::attribute replyTo get
::method init
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  use arg commandIdArg, commandTypeArg, actorIdArg, actorRoleArg, payloadArg = .nil, correlationIdArg = "", causationIdArg = "", requestedAtArg = .nil, replyToArg = ""
  commandId = commandIdArg~string
  commandType = .RelationshipCaseServiceCanonical~token(commandTypeArg)
  actorId = actorIdArg~string
  actorRole = .RelationshipCaseServiceCanonical~token(actorRoleArg)
  if requestedAtArg == .nil then requestedAt = .DateTime~new
  else requestedAt = requestedAtArg
  if correlationIdArg = "" then correlationId = commandId
  else correlationId = correlationIdArg~string
  causationId = causationIdArg~string
  replyTo = replyToArg~string
  if payloadArg == .nil then payload = .directory~new
  else payload = payloadArg
::method payload
  expose payload
  return payload
::method fingerprint
  expose commandType actorId actorRole payload
  text = "RELATIONSHIP-CASE-SERVICE-COMMAND/1"
  text ||= .RelationshipCaseServiceCanonical~field("TYPE", commandType)
  text ||= .RelationshipCaseServiceCanonical~field("ACTOR", actorId)
  text ||= .RelationshipCaseServiceCanonical~field("ROLE", actorRole)
  text ||= .RelationshipCaseServiceCanonical~field("PAYLOAD", .RelationshipCaseServiceCanonical~value(payload))
  return text
::method queuePersistentType
  return "relationship.case.service.command/1"
::method queuePersistentState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  s = .table~new
  s["commandId"] = commandId; s["commandType"] = commandType; s["correlationId"] = correlationId; s["causationId"] = causationId
  s["actorId"] = actorId; s["actorRole"] = actorRole; s["requestedAt"] = requestedAt~string; s["replyTo"] = replyTo; s["payload"] = payload
  return s
::method queueRestoreState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  use arg s
  commandId = s["commandId"]~string; commandType = .RelationshipCaseServiceCanonical~token(s["commandType"])
  correlationId = s["correlationId"]~string; causationId = s["causationId"]~string; actorId = s["actorId"]~string; actorRole = .RelationshipCaseServiceCanonical~token(s["actorRole"])
  requestedAt = .DateTime~fromIsoDate(s["requestedAt"]~string); replyTo = s["replyTo"]~string; payload = s["payload"]
  return self

::class RelationshipCaseServiceReply public
::attribute commandId get
::attribute correlationId get
::attribute ok get
::attribute code get
::attribute detail get
::attribute caseId get
::attribute revision get
::method init
  expose commandId correlationId ok code detail caseId revision value
  use arg commandIdArg, correlationIdArg, okArg, codeArg, detailArg = "", caseIdArg = "", revisionArg = "", valueArg = .nil
  commandId = commandIdArg~string; correlationId = correlationIdArg~string; ok = okArg; code = codeArg~string; detail = detailArg~string; caseId = caseIdArg~string; revision = revisionArg~string; value = valueArg
::method value
  expose value
  return value
::method queuePersistentType
  return "relationship.case.service.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail caseId revision value
  s = .table~new
  s["commandId"] = commandId; s["correlationId"] = correlationId; s["ok"] = .RelationshipCasePersistenceValue~boolText(ok)
  s["code"] = code; s["detail"] = detail; s["caseId"] = caseId; s["revision"] = revision; s["value"] = value
  return s
::method queueRestoreState
  expose commandId correlationId ok code detail caseId revision value
  use arg s
  commandId = s["commandId"]~string; correlationId = s["correlationId"]~string; ok = .RelationshipCasePersistenceValue~truth(s["ok"])
  code = s["code"]~string; detail = s["detail"]~string; caseId = s["caseId"]~string; revision = s["revision"]~string; value = s["value"]
  return self

::class RelationshipCaseServiceEvent public
::attribute eventId get
::attribute eventType get
::attribute caseId get
::attribute correlationId get
::attribute causationId get
::attribute actorId get
::attribute actorRole get
::attribute occurredAt get
::attribute revision get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute domainEventId get
::method init
  expose eventId eventType caseId correlationId causationId actorId actorRole occurredAt revision policyId policyVersion policyIdentity domainEventId payload
  use arg eventIdArg, eventTypeArg, caseIdArg, correlationIdArg, causationIdArg, actorIdArg, actorRoleArg, occurredAtArg, revisionArg, policyIdArg = "", policyVersionArg = "", policyIdentityArg = "", domainEventIdArg = "", payloadArg = .nil
  eventId = eventIdArg~string; eventType = .RelationshipCaseServiceCanonical~token(eventTypeArg); caseId = caseIdArg~string
  correlationId = correlationIdArg~string; causationId = causationIdArg~string; actorId = actorIdArg~string; actorRole = .RelationshipCaseServiceCanonical~token(actorRoleArg)
  occurredAt = occurredAtArg; revision = revisionArg~string; policyId = policyIdArg~string; policyVersion = policyVersionArg~string; policyIdentity = policyIdentityArg~string; domainEventId = domainEventIdArg~string
  if payloadArg == .nil then payload = .directory~new
  else payload = payloadArg
::method payload
  expose payload
  return payload
::method queuePersistentType
  return "relationship.case.service.event/1"
::method queuePersistentState
  expose eventId eventType caseId correlationId causationId actorId actorRole occurredAt revision policyId policyVersion policyIdentity domainEventId payload
  s = .table~new
  s["eventId"] = eventId; s["eventType"] = eventType; s["caseId"] = caseId; s["correlationId"] = correlationId; s["causationId"] = causationId
  s["actorId"] = actorId; s["actorRole"] = actorRole; s["occurredAt"] = occurredAt~string; s["revision"] = revision
  s["policyId"] = policyId; s["policyVersion"] = policyVersion; s["policyIdentity"] = policyIdentity; s["domainEventId"] = domainEventId; s["payload"] = payload
  return s
::method queueRestoreState
  expose eventId eventType caseId correlationId causationId actorId actorRole occurredAt revision policyId policyVersion policyIdentity domainEventId payload
  use arg s
  eventId = s["eventId"]~string; eventType = .RelationshipCaseServiceCanonical~token(s["eventType"]); caseId = s["caseId"]~string
  correlationId = s["correlationId"]~string; causationId = s["causationId"]~string; actorId = s["actorId"]~string; actorRole = .RelationshipCaseServiceCanonical~token(s["actorRole"])
  occurredAt = .DateTime~fromIsoDate(s["occurredAt"]~string); revision = s["revision"]~string; policyId = s["policyId"]~string; policyVersion = s["policyVersion"]~string; policyIdentity = s["policyIdentity"]~string; domainEventId = s["domainEventId"]~string; payload = s["payload"]
  return self

::class RelationshipCaseServiceReceipt public
::attribute commandId get
::attribute fingerprint get
::attribute commandType get
::attribute caseId get
::attribute elementId get
::attribute code get
::method init
  expose commandId fingerprint commandType caseId elementId code
  use arg commandIdArg, fingerprintArg, commandTypeArg, caseIdArg = "", elementIdArg = "", codeArg = "OK"
  commandId = commandIdArg~string; fingerprint = fingerprintArg~string; commandType = .RelationshipCaseServiceCanonical~token(commandTypeArg); caseId = caseIdArg~string; elementId = elementIdArg~string; code = codeArg~string
::method queuePersistentType
  return "relationship.case.service.receipt/1"
::method queuePersistentState
  expose commandId fingerprint commandType caseId elementId code
  s = .table~new; s["commandId"] = commandId; s["fingerprint"] = fingerprint; s["commandType"] = commandType; s["caseId"] = caseId; s["elementId"] = elementId; s["code"] = code; return s
::method queueRestoreState
  expose commandId fingerprint commandType caseId elementId code
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; commandType=.RelationshipCaseServiceCanonical~token(s["commandType"]); caseId=s["caseId"]~string; elementId=s["elementId"]~string; code=s["code"]~string; return self

::class RelationshipCaseServiceState public
::attribute formatVersion get
::attribute sequence get
::method init
  expose formatVersion sequence cases receipts auditEvents outbox
  formatVersion = .RelationshipCaseServiceBuild~STATE_FORMAT
  sequence = 0
  cases = .array~new; receipts = .table~new; auditEvents = .array~new; outbox = .array~new
::method cases
  expose cases
  return .RelationshipCaseServiceCanonical~copyArray(cases)
::method receipt
  expose receipts
  use arg commandId
  return receipts[commandId~string]
::method addReceipt
  expose receipts
  use arg receipt
  receipts[receipt~commandId] = receipt; return receipt
::method addCase
  expose cases
  use arg caseObject
  do existing over cases
    if existing~caseId = caseObject~caseId then return existing
  end
  cases~append(caseObject); return caseObject
::method nextEventId
  expose sequence
  use arg caseId
  sequence += 1
  return "RCS-EVT-" || sequence || ":" || caseId~string
::method recordEvent
  expose auditEvents outbox
  use arg event
  auditEvents~append(event); outbox~append(event); return event
::method auditEvents
  expose auditEvents
  return .RelationshipCaseServiceCanonical~copyArray(auditEvents)
::method outbox
  expose outbox
  return .RelationshipCaseServiceCanonical~copyArray(outbox)
::method markDelivered
  expose outbox
  use arg eventId
  kept = .array~new; found = .false
  do event over outbox
    if event~eventId = eventId~string then found = .true
    else kept~append(event)
  end
  outbox = kept
  return found
::method queuePersistentType
  return .RelationshipCaseServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose formatVersion sequence cases receipts auditEvents outbox
  s = .table~new; s["formatVersion"] = formatVersion; s["sequence"] = sequence~string; s["cases"] = cases; s["receipts"] = receipts; s["auditEvents"] = auditEvents; s["outbox"] = outbox; return s
::method queueRestoreState
  expose formatVersion sequence cases receipts auditEvents outbox
  use arg s
  formatVersion = s["formatVersion"]~string; sequence = s["sequence"] + 0; cases = s["cases"]; receipts = s["receipts"]; auditEvents = s["auditEvents"]; outbox = s["outbox"]; return self

::class RelationshipCaseEventSink public
::method publish abstract

::class RelationshipCaseMemoryEventSink subclass RelationshipCaseEventSink public
::method init
  expose events failNext
  events = .array~new; failNext = .false
::method failNext
  expose failNext
  failNext = .true; return self
::method publish
  expose events failNext
  use arg event
  if failNext then do; failNext = .false; return .RelationshipCaseServiceResult~failure("SINK_UNAVAILABLE"); end
  events~append(event); return .RelationshipCaseServiceResult~success(event)
::method events
  expose events
  return .RelationshipCaseServiceCanonical~copyArray(events)

::class RelationshipCaseService subclass RelationshipCaseAlchemyObject public
::attribute accepting get
::attribute faulted get
::method init
  expose policyCatalog policyId repository engine state store sink accepting faulted
  use arg policyCatalogArg, policyIdArg = .nil, storeArg = .nil, sinkArg = .nil, contextArg = .nil
  self~initDomainAlchemy("RELATIONSHIPCASESERVICE", contextArg)
  policyCatalog = policyCatalogArg; policyId = policyIdArg; store = storeArg
  if sinkArg == .nil then sink = .RelationshipCaseMemoryEventSink~new
  else sink = sinkArg
  accepting = .true; faulted = .false
  if store == .nil then state = .RelationshipCaseServiceState~new
  else do
    loaded = store~load
    if loaded~ok then state = loaded~value
    else do
      state = .RelationshipCaseServiceState~new
      accepting = .false; faulted = .true
    end
  end
  repository = .RelationshipCaseRepository~new
  do caseObject over state~cases
    added = repository~add(caseObject)
    if \added~ok then do; accepting = .false; faulted = .true; end
  end
  engine = .RelationshipCaseEngine~new(policyCatalog, policyId, repository)
  self~registerStateVariable("accepting", "INTERNAL", "whether service accepts commands")
  self~registerStateVariable("faulted", "INTERNAL", "persistence/recovery fault latch")
::method repository
  expose repository
  return repository
::method state
  expose state
  return state
::method eventSink
  expose sink
  return sink
::method quiesce
  expose accepting
  accepting = .false
  return self~flushOutbox
::method resume
  expose accepting faulted
  if faulted then return .RelationshipCaseServiceResult~failure("SERVICE_FAULTED")
  accepting = .true; return .RelationshipCaseServiceResult~success(self)
::method isMutation private
  use arg commandType
  return commandType = "CASE.OPEN" | commandType = "CASE.ATTACH_ELEMENT" | commandType = "CASE.TRANSITION"
::method reply private
  use arg envelope, ok, code, detail = "", caseObject = .nil, value = .nil
  caseId = ""; revision = ""
  if caseObject <> .nil then do; caseId = caseObject~caseId; revision = caseObject~revision; end
  return .RelationshipCaseServiceReply~new(envelope~commandId, envelope~correlationId, ok, code, detail, caseId, revision, value)
::method handle
  expose accepting faulted state repository engine
  use arg envelope
  if envelope == .nil then return .RelationshipCaseServiceReply~new("", "", .false, "COMMAND_REQUIRED")
  if envelope~commandId = "" | envelope~commandType = "" | envelope~actorId = "" | envelope~actorRole = "" then return self~reply(envelope, .false, "COMMAND_INVALID")
  if faulted then return self~reply(envelope, .false, "SERVICE_FAULTED")
  if \accepting then return self~reply(envelope, .false, "SERVICE_QUIESCED")
  commandType = envelope~commandType
  if self~isMutation(commandType) then do
    prior = state~receipt(envelope~commandId)
    if prior <> .nil then do
      if prior~fingerprint \= envelope~fingerprint then return self~reply(envelope, .false, "COMMAND_ID_CONFLICT", "same commandId with different command semantics")
      rr = repository~get(prior~caseId)
      if rr~ok then return self~reply(envelope, .true, "IDEMPOTENT_REPLAY", "original mutation already committed", rr~value, rr~value)
      return self~reply(envelope, .false, "IDEMPOTENCY_STATE_INCONSISTENT", prior~caseId)
    end
  end
  select
    when commandType = "CASE.OPEN" then return self~handleOpen(envelope)
    when commandType = "CASE.ATTACH_ELEMENT" then return self~handleAttach(envelope)
    when commandType = "CASE.TRANSITION" then return self~handleTransition(envelope)
    when commandType = "CASE.GET" then return self~handleGet(envelope)
    when commandType = "CASE.PROJECT" then return self~handleGet(envelope)
    when commandType = "CASE.FOR_SUBJECT" then return self~handleForSubject(envelope)
    otherwise return self~reply(envelope, .false, "COMMAND_UNSUPPORTED", commandType)
  end
::method payloadValue private
  use arg payload, key, defaultValue = ""
  if payload == .nil then return defaultValue
  if payload~hasIndex(key) then return payload[key]
  return defaultValue
::method handleOpen private
  expose engine state
  use arg envelope
  p = envelope~payload
  caseId = self~payloadValue(p, "caseId")~string; caseType = self~payloadValue(p, "caseType")~string
  ownerId = self~payloadValue(p, "ownerId")~string; ownerRole = self~payloadValue(p, "ownerRole")~string
  result = engine~openCase(.RelationshipCaseOpenRequest~new(caseId, caseType, envelope~actorId, envelope~actorRole, envelope~requestedAt, ownerId, ownerRole))
  if \result~ok then return self~reply(envelope, .false, result~code, result~detail)
  caseObject = result~value; state~addCase(caseObject)
  domainEvent = caseObject~events[caseObject~events~items]
  committed = self~commitMutation(envelope, caseObject, domainEvent, "CASE.OPENED", "")
  if \committed~ok then return self~reply(envelope, .false, committed~code, committed~detail, caseObject)
  return self~reply(envelope, .true, "OK", committed~detail, caseObject, caseObject)
::method handleAttach private
  expose engine repository
  use arg envelope
  p = envelope~payload; caseId = self~payloadValue(p, "caseId")~string
  rr = repository~get(caseId); if \rr~ok then return self~reply(envelope, .false, rr~code, rr~detail)
  element = self~payloadValue(p, "element", .nil)
  if element == .nil | \element~isA(.RelationshipCaseElement) then return self~reply(envelope, .false, "CASE_ELEMENT_REQUIRED")
  result = engine~attachElement(rr~value, element, envelope~actorId, envelope~actorRole, envelope~requestedAt)
  if \result~ok then return self~reply(envelope, .false, result~code, result~detail, rr~value)
  caseObject = rr~value; domainEvent = caseObject~events[caseObject~events~items]
  committed = self~commitMutation(envelope, caseObject, domainEvent, "CASE.ELEMENT_ATTACHED", element~elementId)
  if \committed~ok then return self~reply(envelope, .false, committed~code, committed~detail, caseObject)
  return self~reply(envelope, .true, "OK", committed~detail, caseObject, element)
::method handleTransition private
  expose engine repository
  use arg envelope
  p = envelope~payload; caseId = self~payloadValue(p, "caseId")~string; action = self~payloadValue(p, "action")~string
  rr = repository~get(caseId); if \rr~ok then return self~reply(envelope, .false, rr~code, rr~detail)
  cmd = .RelationshipCaseCommand~new(envelope~commandId, action, envelope~actorId, envelope~actorRole, envelope~requestedAt)
  result = engine~transition(rr~value, cmd)
  if \result~ok then return self~reply(envelope, .false, result~code, result~detail, rr~value)
  caseObject = rr~value; domainEvent = caseObject~events[caseObject~events~items]
  committed = self~commitMutation(envelope, caseObject, domainEvent, "CASE.STATE_CHANGED", "")
  if \committed~ok then return self~reply(envelope, .false, committed~code, committed~detail, caseObject)
  return self~reply(envelope, .true, "OK", committed~detail, caseObject, caseObject)
::method viewerRole private
  use arg envelope
  role = self~payloadValue(envelope~payload, "viewerRole", "")~string
  if role = "" then role = envelope~actorRole
  return role
::method handleGet private
  expose engine repository
  use arg envelope
  caseId = self~payloadValue(envelope~payload, "caseId")~string
  rr = repository~get(caseId); if \rr~ok then return self~reply(envelope, .false, rr~code, rr~detail)
  projected = engine~project(rr~value, self~viewerRole(envelope), envelope~requestedAt)
  if \projected~ok then return self~reply(envelope, .false, projected~code, projected~detail)
  return self~reply(envelope, .true, "OK", "policy-projected case", rr~value, projected~value)
::method handleForSubject private
  expose engine repository
  use arg envelope
  sourceSystem = self~payloadValue(envelope~payload, "sourceSystem")~string; sourceRef = self~payloadValue(envelope~payload, "sourceRef")~string
  cases = repository~casesForSubject(sourceSystem, sourceRef); projectedCases = .array~new; role = self~viewerRole(envelope)
  do caseObject over cases
    projection = engine~project(caseObject, role, envelope~requestedAt)
    if projection~ok then projectedCases~append(projection~value)
    else if projection~code \= "CASE_NOT_VISIBLE" then return self~reply(envelope, .false, projection~code, projection~detail)
  end
  return self~reply(envelope, .true, "OK", "subject case projections", .nil, projectedCases)
::method commitMutation private
  expose state store
  use arg envelope, caseObject, domainEvent, eventType, elementId = ""
  payload = .directory~new
  payload["caseType"] = caseObject~caseType; payload["state"] = caseObject~state; payload["priority"] = caseObject~priority
  if elementId \= "" then payload["elementId"] = elementId
  serviceEvent = .RelationshipCaseServiceEvent~new(state~nextEventId(caseObject~caseId), eventType, caseObject~caseId, envelope~correlationId, envelope~commandId, envelope~actorId, envelope~actorRole, envelope~requestedAt, caseObject~revision, domainEvent~policyId, domainEvent~policyVersion, domainEvent~policyIdentity, domainEvent~eventId, payload)
  state~recordEvent(serviceEvent)
  state~addReceipt(.RelationshipCaseServiceReceipt~new(envelope~commandId, envelope~fingerprint, envelope~commandType, caseObject~caseId, elementId, "OK"))
  persisted = self~persist
  if \persisted~ok then return persisted
  flushed = self~flushOutbox
  if \flushed~ok then return .RelationshipCaseServiceResult~success(caseObject, "EVENT_PENDING_DELIVERY:" || flushed~code)
  return .RelationshipCaseServiceResult~success(caseObject)
::method persist private
  expose store state faulted accepting
  if store == .nil then return .RelationshipCaseServiceResult~success(state)
  result = store~save(state)
  if \result~ok then do
    faulted = .true; accepting = .false
    return .RelationshipCaseServiceResult~failure("SERVICE_PERSISTENCE_FAILED", result~code || ":" || result~detail)
  end
  return result
::method flushOutbox
  expose state sink store faulted accepting
  pending = state~outbox
  if pending~items = 0 then return .RelationshipCaseServiceResult~success(0)
  delivered = 0
  do event over pending
    published = sink~publish(event)
    if published == .nil then return .RelationshipCaseServiceResult~failure("EVENT_SINK_INVALID")
    if published~hasMethod("OK") then do
      if \published~ok then return .RelationshipCaseServiceResult~failure(published~code, published~detail)
    end
    else if published == .false then return .RelationshipCaseServiceResult~failure("EVENT_SINK_REJECTED")
    ignore = state~markDelivered(event~eventId); delivered += 1
  end
  if store <> .nil then do
    saved = store~save(state)
    if \saved~ok then do
      /* At-least-once boundary: delivery may duplicate after restart if the
         outbox acknowledgement cannot be persisted. Event IDs are stable. */
      faulted = .true; accepting = .false
      return .RelationshipCaseServiceResult~failure("OUTBOX_ACK_PERSISTENCE_FAILED", saved~detail)
    end
  end
  return .RelationshipCaseServiceResult~success(delivered)

::requires "RelationshipCase.cls"
