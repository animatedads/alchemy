/*
 * RIDIntermediaryService.cls - regulated intermediary work/service projection v0.4
 *
 * Queue Fabric is used as a durable state-transition substrate rather than as
 * a message-notification facade.  Provider status drives case attention and
 * broker work directly.  The work audit queue is the durable projection
 * authority; retained topics are reconstructable delivery surfaces.
 */

::class RIDIntermediaryServiceBuild public
::constant VERSION "0.4"
::constant API_VERSION "regulated.intermediary.service/0.4"

::class RIDWorkRule public
::attribute ruleId get
::attribute productFamily get
::attribute providerStatus get
::attribute workType get
::attribute audience get
::attribute priority get
::attribute slaSeconds get
::attribute completionMode get
::attribute supersedeGroup get
::method init
  expose ruleId productFamily providerStatus workType audience priority slaSeconds completionMode supersedeGroup
  use arg ruleIdArg, productFamilyArg, providerStatusArg, workTypeArg, audienceArg = "INTERMEDIARY", priorityArg = 50, slaSecondsArg = 0, completionModeArg = "ACK", supersedeGroupArg = "PROVIDER_STATUS"
  ruleId = .RIDCanonical~required("ruleId", ruleIdArg)~upper
  productFamily = .RIDCanonical~required("productFamily", productFamilyArg)~upper
  providerStatus = .RIDCanonical~required("providerStatus", providerStatusArg)~upper
  workType = workTypeArg~string~upper
  audience = .RIDCanonical~required("audience", audienceArg)~upper
  priority = priorityArg + 0
  slaSeconds = slaSecondsArg + 0
  if slaSeconds < 0 then raise syntax 88.990 array("slaSeconds must be >= 0")
  completionMode = .RIDCanonical~required("completionMode", completionModeArg)~upper
  supersedeGroup = supersedeGroupArg~string~upper
::method matches
  expose productFamily providerStatus
  use arg familyArg, statusArg
  return .RIDCanonical~match(productFamily, familyArg) & .RIDCanonical~match(providerStatus, statusArg)
::method specificity
  expose productFamily providerStatus
  return .RIDCanonical~specificity(.array~of(productFamily, providerStatus))

::class RIDWorkPolicy public
::method init
  expose rules sealed
  rules = .array~new
  sealed = .false
::method addRule
  expose rules sealed
  use arg rule
  if sealed then return .RIDResult~failure("WORK_POLICY_SEALED")
  if rule == .nil then return .RIDResult~failure("INVALID_WORK_RULE")
  if \rule~isA(.RIDWorkRule) then return .RIDResult~failure("INVALID_WORK_RULE")
  do existing over rules
    if existing~ruleId = rule~ruleId then return .RIDResult~failure("WORK_RULE_EXISTS")
  end
  rules~append(rule)
  return .RIDResult~success(rule)
::method seal
  expose sealed
  sealed = .true
  return .RIDResult~success(self)
::method resolve
  expose rules
  use arg familyArg, statusArg
  best = .nil
  bestScore = -1
  do rule over rules
    if rule~matches(familyArg, statusArg) then do
      score = rule~specificity
      if score > bestScore then do
        best = rule
        bestScore = score
      end
    end
  end
  return best
::method standard class
  p = self~new
  /* Provider document requests are deliberately product-neutral. */
  ignore = p~addRule(.RIDWorkRule~new("GEN-DOCS", "*", "DOCUMENTS_REQUIRED", "SUPPLY_REQUESTED_DOCUMENTS", "INTERMEDIARY", 95, 86400, "ACK"))

  ignore = p~addRule(.RIDWorkRule~new("MTG-APPROVED", "MORTGAGE", "APPROVED", "REVIEW_MORTGAGE_APPROVAL", "INTERMEDIARY", 85, 43200, "ACK"))
  ignore = p~addRule(.RIDWorkRule~new("MTG-OFFERED", "MORTGAGE", "OFFERED", "PRESENT_MORTGAGE_OFFER_AND_SIGN", "INTERMEDIARY", 100, 172800, "SIGNATURE"))
  ignore = p~addRule(.RIDWorkRule~new("MTG-DECLINED", "MORTGAGE", "DECLINED", "REVIEW_MORTGAGE_DECLINE", "INTERMEDIARY", 100, 14400, "ACK"))
  ignore = p~addRule(.RIDWorkRule~new("MTG-REJECTED", "MORTGAGE", "REJECTED", "REVIEW_MORTGAGE_REJECTION", "INTERMEDIARY", 100, 14400, "ACK"))

  ignore = p~addRule(.RIDWorkRule~new("INV-APPROVED", "INVESTMENT", "APPROVED", "REVIEW_INVESTMENT_ACCEPTANCE", "INTERMEDIARY", 85, 43200, "ACK"))
  ignore = p~addRule(.RIDWorkRule~new("INV-OFFERED", "INVESTMENT", "OFFERED", "PRESENT_INVESTMENT_TERMS_AND_SIGN", "INTERMEDIARY", 100, 172800, "SIGNATURE"))
  ignore = p~addRule(.RIDWorkRule~new("INV-DECLINED", "INVESTMENT", "DECLINED", "REVIEW_INVESTMENT_DECLINE", "INTERMEDIARY", 100, 14400, "ACK"))
  ignore = p~addRule(.RIDWorkRule~new("INV-REJECTED", "INVESTMENT", "REJECTED", "REVIEW_INVESTMENT_REJECTION", "INTERMEDIARY", 100, 14400, "ACK"))

  ignore = p~addRule(.RIDWorkRule~new("INS-APPROVED", "INSURANCE", "APPROVED", "REVIEW_INSURANCE_APPROVAL", "INTERMEDIARY", 85, 43200, "ACK"))
  ignore = p~addRule(.RIDWorkRule~new("INS-QUOTED", "INSURANCE", "QUOTED", "PRESENT_INSURANCE_QUOTE_AND_SIGN", "INTERMEDIARY", 100, 86400, "SIGNATURE"))
  ignore = p~addRule(.RIDWorkRule~new("INS-DECLINED", "INSURANCE", "DECLINED", "REVIEW_INSURANCE_DECLINE", "INTERMEDIARY", 100, 14400, "ACK"))
  ignore = p~addRule(.RIDWorkRule~new("INS-REJECTED", "INSURANCE", "REJECTED", "REVIEW_INSURANCE_REJECTION", "INTERMEDIARY", 100, 14400, "ACK"))
  ignore = p~seal
  return p

::class RIDWorkItem public
::attribute workItemId get
::attribute caseId get
::attribute firmId get
::attribute representativeId get
::attribute productFamily get
::attribute providerStatus get
::attribute workType get
::attribute audience get
::attribute priority get
::attribute slaSeconds get
::attribute completionMode get
::attribute supersedeGroup get
::attribute sourceEventId get
::attribute sourceProviderSequence get
::attribute createdTick get
::attribute dueTick get
::attribute status get
::attribute completionEvidenceRef get
::attribute updatedAt get
::attribute overdueAt get
::method init
  expose workItemId caseId firmId representativeId productFamily providerStatus workType audience priority slaSeconds completionMode supersedeGroup sourceEventId sourceProviderSequence createdTick dueTick status completionEvidenceRef updatedAt overdueAt
  use arg workItemIdArg, caseIdArg, firmIdArg, representativeIdArg, productFamilyArg, providerStatusArg, workTypeArg, audienceArg, priorityArg, slaSecondsArg, completionModeArg, supersedeGroupArg, sourceEventIdArg, sourceProviderSequenceArg, createdTickArg, dueTickArg
  workItemId = .RIDCanonical~required("workItemId", workItemIdArg)~upper
  caseId = .RIDCanonical~required("caseId", caseIdArg)~upper
  firmId = .RIDCanonical~required("firmId", firmIdArg)~upper
  representativeId = .RIDCanonical~required("representativeId", representativeIdArg)~upper
  productFamily = .RIDCanonical~required("productFamily", productFamilyArg)~upper
  providerStatus = .RIDCanonical~required("providerStatus", providerStatusArg)~upper
  workType = .RIDCanonical~required("workType", workTypeArg)~upper
  audience = .RIDCanonical~required("audience", audienceArg)~upper
  priority = priorityArg + 0
  slaSeconds = slaSecondsArg + 0
  completionMode = .RIDCanonical~required("completionMode", completionModeArg)~upper
  supersedeGroup = supersedeGroupArg~string~upper
  sourceEventId = .RIDCanonical~required("sourceEventId", sourceEventIdArg)~upper
  sourceProviderSequence = sourceProviderSequenceArg + 0
  createdTick = createdTickArg + 0
  dueTick = dueTickArg + 0
  status = "OPEN"
  completionEvidenceRef = ""
  updatedAt = .DateTime~new
  overdueAt = ""
::method supersede package
  expose status updatedAt
  use arg atTime = .nil
  if status = "COMPLETE" | status = "SUPERSEDED" then return status
  status = "SUPERSEDED"
  if atTime == .nil then updatedAt = .DateTime~new
  else updatedAt = atTime
  return status
::method markOverdue package
  expose status updatedAt overdueAt
  use arg atTime = .nil
  if status <> "OPEN" then return status
  status = "OVERDUE"
  if atTime == .nil then updatedAt = .DateTime~new
  else updatedAt = atTime
  overdueAt = updatedAt~string
  return status
::method complete package
  expose status completionEvidenceRef updatedAt
  use arg evidenceRef, atTime = .nil
  if status = "COMPLETE" then return status
  status = "COMPLETE"
  completionEvidenceRef = evidenceRef~string
  if atTime == .nil then updatedAt = .DateTime~new
  else updatedAt = atTime
  return status
::method actionable
  expose status audience
  return (status = "OPEN" | status = "OVERDUE") & audience = "INTERMEDIARY"

::class RIDIntermediaryWorkService public
::attribute queueManager get
::attribute topicFabric get
::attribute statusInputQueue get
::attribute auditQueue get
::attribute slaQueue get
::attribute overdueQueue get
::attribute deadLetterQueue get
::attribute expiryTombstoneQueue get
::attribute wireWorkQueue get
::attribute wireAttentionQueue get
::attribute workStatusTopic get
::attribute caseAttentionTopic get
::method init
  expose queueManager topicFabric engine catalog workPolicy adminPrincipal timeSource workItems deadlinePackageToWorkId statusInputQueue auditQueue slaQueue overdueQueue deadLetterQueue expiryTombstoneQueue wireWorkQueue wireAttentionQueue caseStatusTopic workStatusTopic caseAttentionTopic
  use arg queueManagerArg, topicFabricArg, engineArg, catalogArg, workPolicyArg = .nil, adminPrincipalArg = "RID_ADMIN", timeSourceArg = .nil
  queueManager = queueManagerArg
  topicFabric = topicFabricArg
  engine = engineArg
  catalog = catalogArg
  if workPolicyArg == .nil then workPolicy = .RIDWorkPolicy~standard
  else workPolicy = workPolicyArg
  adminPrincipal = adminPrincipalArg~string
  if timeSourceArg == .nil then timeSource = .QueueTimeSource~new
  else timeSource = timeSourceArg
  workItems = .directory~new
  deadlinePackageToWorkId = .directory~new
  statusInputQueue = "RID.WORK.STATUS.INPUT"
  auditQueue = "RID.WORK.AUDIT"
  slaQueue = "RID.WORK.SLA"
  overdueQueue = "RID.WORK.OVERDUE"
  deadLetterQueue = "RID.WORK.DLQ"
  expiryTombstoneQueue = "RID.EXPIRY.TOMBSTONE"
  wireWorkQueue = "RID.WIRE.WORK"
  wireAttentionQueue = "RID.WIRE.ATTENTION"
  caseStatusTopic = "RID.CASE.STATUS"
  workStatusTopic = "RID.WORK.STATUS"
  caseAttentionTopic = "RID.CASE.ATTENTION"

::method configure
  expose queueManager topicFabric adminPrincipal statusInputQueue auditQueue slaQueue overdueQueue deadLetterQueue expiryTombstoneQueue wireWorkQueue wireAttentionQueue caseStatusTopic workStatusTopic caseAttentionTopic
  domain = "FEDERATION_INTERMEDIARY"
  do qname over .array~of(statusInputQueue, auditQueue, slaQueue, overdueQueue, deadLetterQueue, expiryTombstoneQueue, wireWorkQueue, wireAttentionQueue)
    if queueManager~queue(qname) == .nil then do
      r = queueManager~createQueue(qname, "PERMANENT", domain, 0, adminPrincipal, adminPrincipal)
      if \r~ok then return .RIDResult~failure("WORK_QUEUE_CONFIG_FAILED", qname || ":" || r~code || ":" || r~detail)
    end
  end
  /* Explicit backout remains work-domain specific; manager-level dead letter is
     reserved for TTL tombstones so expired SLA packages remain inspectable. */
  r = queueManager~setDeadLetterQueue(expiryTombstoneQueue, adminPrincipal)
  if \r~ok then return .RIDResult~failure("WORK_QUEUE_CONFIG_FAILED", r~code || ":" || r~detail)
  r = queueManager~configureBackout(statusInputQueue, 3, deadLetterQueue, adminPrincipal)
  if \r~ok then return .RIDResult~failure("WORK_QUEUE_CONFIG_FAILED", r~code || ":" || r~detail)

  if topicFabric~topic(workStatusTopic) == .nil then do
    r = topicFabric~defineTopic(workStatusTopic, "rid/work/status", "PERMANENT", domain, adminPrincipal)
    if \r~ok then return .RIDResult~failure("WORK_TOPIC_CONFIG_FAILED", r~code || ":" || r~detail)
  end
  if topicFabric~topic(caseAttentionTopic) == .nil then do
    r = topicFabric~defineTopic(caseAttentionTopic, "rid/case/attention", "PERMANENT", domain, adminPrincipal)
    if \r~ok then return .RIDResult~failure("WORK_TOPIC_CONFIG_FAILED", r~code || ":" || r~detail)
  end
  if topicFabric~topic(caseStatusTopic) == .nil then return .RIDResult~failure("CASE_STATUS_TOPIC_REQUIRED")
  if topicFabric~subscription("RID.WORK.STATUS.FEED") == .nil then do
    options = .table~new; options["deliverRetained"] = .true
    r = topicFabric~subscribe("RID.WORK.STATUS.FEED", caseStatusTopic, "#", statusInputQueue, "PERMANENT", adminPrincipal, options)
    if \r~ok then return .RIDResult~failure("WORK_TOPIC_CONFIG_FAILED", r~code || ":" || r~detail)
  end
  if topicFabric~subscription("RID.WIRE.WORK.ALL") == .nil then do
    options = .table~new; options["deliverRetained"] = .true
    r = topicFabric~subscribe("RID.WIRE.WORK.ALL", workStatusTopic, "#", wireWorkQueue, "PERMANENT", adminPrincipal, options)
    if \r~ok then return .RIDResult~failure("WORK_TOPIC_CONFIG_FAILED", r~code || ":" || r~detail)
  end
  if topicFabric~subscription("RID.WIRE.ATTENTION.ALL") == .nil then do
    options = .table~new; options["deliverRetained"] = .true
    r = topicFabric~subscribe("RID.WIRE.ATTENTION.ALL", caseAttentionTopic, "#", wireAttentionQueue, "PERMANENT", adminPrincipal, options)
    if \r~ok then return .RIDResult~failure("WORK_TOPIC_CONFIG_FAILED", r~code || ":" || r~detail)
  end

  haveExpiryTrigger = .false
  do reg over queueManager~triggers
    if reg~queueName = slaQueue & reg~kind = "EXPIRE" then haveExpiryTrigger = .true
  end
  if \haveExpiryTrigger then do
    target = .QueueDirectTriggerTarget~new(self, "onQueueTrigger")
    r = queueManager~registerTrigger(slaQueue, "EXPIRE", target, 0, adminPrincipal)
    if \r~ok then return .RIDResult~failure("WORK_TRIGGER_CONFIG_FAILED", r~code || ":" || r~detail)
  end
  return self~recover

::method workItem
  expose workItems
  use arg workItemId
  return workItems[.RIDCanonical~token(workItemId)]
::method workItemsForCase
  expose workItems
  use arg caseId
  wanted = .RIDCanonical~token(caseId)
  out = .array~new
  do id over workItems~allIndexes
    item = workItems[id]
    if item~caseId = wanted then out~append(item)
  end
  return out
::method activeWorkForCase private
  expose workItems
  use arg caseId
  wanted = .RIDCanonical~token(caseId)
  best = .nil
  do id over workItems~allIndexes
    item = workItems[id]
    if item~caseId <> wanted then iterate
    if \item~actionable then iterate
    if best == .nil then best = item
    else if item~status = "OVERDUE" & best~status <> "OVERDUE" then best = item
    else if item~status = best~status & item~priority > best~priority then best = item
  end
  return best

::method workIdFor private
  use arg caseId, sourceEventId, ruleId
  return "RID-WORK-" || .RIDCanonical~token(caseId) || "-" || .RIDCanonical~token(sourceEventId) || "-" || .RIDCanonical~token(ruleId)

::method terminalProviderStatus private
  use arg statusArg
  status = .RIDCanonical~token(statusArg)
  return status = "BOUND" | status = "COMPLETED" | status = "EXECUTED" | status = "SETTLED"

::method unresolvedSignatureWork private
  expose workItems
  use arg caseId
  wanted = .RIDCanonical~token(caseId)
  do id over workItems~allIndexes
    item = workItems[id]
    if item~caseId <> wanted then iterate
    if item~completionMode <> "SIGNATURE" then iterate
    if item~status = "OPEN" | item~status = "OVERDUE" then return item
  end
  return .nil

::method workForSourceEvent private
  expose workItems
  use arg caseId, sourceEventId
  wantedCase = .RIDCanonical~token(caseId)
  wantedEvent = .RIDCanonical~token(sourceEventId)
  do id over workItems~allIndexes
    item = workItems[id]
    if item~caseId = wantedCase & item~sourceEventId = wantedEvent then return item
  end
  return .nil

::method queueOptions private
  use arg caseId, priority = 0, expirySeconds = 0
  options = .table~new
  options["persistent"] = .true
  options["correlationId"] = .RIDCanonical~token(caseId)
  options["priority"] = priority
  if expirySeconds > 0 then options["expirySeconds"] = expirySeconds
  return options

::method auditRowFor private
  use arg eventType, item, evidenceRef = ""
  d = .directory~new
  d["schema"] = "regulated.intermediary.work-event/1"
  d["event_type"] = eventType~string~upper
  d["work_item_id"] = item~workItemId
  d["case_id"] = item~caseId
  d["firm_id"] = item~firmId
  d["representative_id"] = item~representativeId
  d["product_family"] = item~productFamily
  d["provider_status"] = item~providerStatus
  d["work_type"] = item~workType
  d["audience"] = item~audience
  d["priority"] = item~priority~string
  d["sla_seconds"] = item~slaSeconds~string
  d["completion_mode"] = item~completionMode
  d["supersede_group"] = item~supersedeGroup
  d["source_event_id"] = item~sourceEventId
  d["source_provider_sequence"] = item~sourceProviderSequence~string
  d["created_tick"] = item~createdTick~string
  d["due_tick"] = item~dueTick~string
  d["evidence_ref"] = evidenceRef~string
  d["recorded_at"] = .DateTime~new~string
  return d

::method workProjection private
  use arg item
  d = .directory~new
  d["schema"] = "regulated.intermediary.work-projection/1"
  d["work_item_id"] = item~workItemId
  d["case_id"] = item~caseId
  d["firm_id"] = item~firmId
  d["representative_id"] = item~representativeId
  d["product_family"] = item~productFamily
  d["provider_status"] = item~providerStatus
  d["work_type"] = item~workType
  d["status"] = item~status
  d["audience"] = item~audience
  d["priority"] = item~priority~string
  d["completion_mode"] = item~completionMode
  d["due_tick"] = item~dueTick~string
  d["source_event_id"] = item~sourceEventId
  d["source_provider_sequence"] = item~sourceProviderSequence~string
  d["completion_evidence_ref"] = item~completionEvidenceRef
  d["overdue_at"] = item~overdueAt
  return d

::method caseAttentionProjection private
  expose engine catalog
  use arg caseId
  c = engine~case(caseId)
  if c == .nil then return .nil
  p = catalog~product(c~productRefId)
  if p == .nil then return .nil
  item = self~activeWorkForCase(c~caseId)
  d = .directory~new
  d["schema"] = "regulated.intermediary.case-attention/1"
  d["case_id"] = c~caseId
  d["firm_id"] = c~firmId
  d["representative_id"] = c~representativeId
  d["product_family"] = p~productFamily
  d["workflow_state"] = c~state
  d["provider_status"] = c~providerStatus
  d["provider_sequence"] = c~providerSequence~string
  d["provider_event_id"] = c~providerEventId
  if item == .nil then do
    d["work_item_id"] = ""
    d["next_action"] = "NONE"
    d["priority"] = "0"
    d["overdue"] = "0"
    d["due_tick"] = "0"
    if c~providerStatus = "BOUND" | c~providerStatus = "COMPLETED" then do
      d["attention_state"] = "COMPLETE"
      d["waiting_on"] = "NONE"
    end
    else do
      d["attention_state"] = "WAITING_PROVIDER"
      d["waiting_on"] = "PROVIDER"
    end
  end
  else do
    d["work_item_id"] = item~workItemId
    d["next_action"] = item~workType
    d["priority"] = item~priority~string
    d["due_tick"] = item~dueTick~string
    if item~status = "OVERDUE" then do
      d["attention_state"] = "OVERDUE"
      d["overdue"] = "1"
    end
    else do
      d["attention_state"] = "ACTION_REQUIRED"
      d["overdue"] = "0"
    end
    d["waiting_on"] = "INTERMEDIARY"
  end
  return d

::method publishWork private
  expose topicFabric workStatusTopic adminPrincipal
  use arg item
  payload = self~workProjection(item)
  options = .table~new
  options["subtopic"] = item~firmId || "/" || item~workItemId
  options["persistent"] = .true
  options["retain"] = .true
  options["correlationId"] = item~caseId
  options["priority"] = item~priority
  options["publicationId"] = "RID-WORK-STATE-" || item~workItemId || "-" || item~status
  r = topicFabric~publish(workStatusTopic, payload, options, adminPrincipal)
  if \r~ok then return .RIDResult~failure("WORK_STATUS_PUBLISH_FAILED", r~code || ":" || r~detail)
  return .RIDResult~success(item)

::method publishAttention private
  expose topicFabric caseAttentionTopic adminPrincipal
  use arg caseId
  payload = self~caseAttentionProjection(caseId)
  if payload == .nil then return .RIDResult~failure("CASE_ATTENTION_PROJECTION_FAILED", caseId)
  options = .table~new
  options["subtopic"] = payload["firm_id"] || "/" || payload["case_id"]
  options["persistent"] = .true
  options["retain"] = .true
  options["correlationId"] = payload["case_id"]
  options["priority"] = payload["priority"] + 0
  options["publicationId"] = "RID-ATTENTION-" || payload["case_id"] || "-" || payload["provider_event_id"] || "-" || payload["attention_state"]
  r = topicFabric~publish(caseAttentionTopic, payload, options, adminPrincipal)
  if \r~ok then return .RIDResult~failure("CASE_ATTENTION_PUBLISH_FAILED", r~code || ":" || r~detail)
  return .RIDResult~success(payload)

::method deadlineExists private
  expose queueManager adminPrincipal slaQueue
  use arg workId
  do package over queueManager~authorisedPackages(adminPrincipal)
    if package~currentQueue <> slaQueue then iterate
    payload = package~payload
    if payload == .nil then iterate
    if payload~hasMethod("hasIndex") then do
      if payload["work_item_id"] = workId then return package
    end
  end
  return .nil

::method mapDeadlines private
  expose queueManager adminPrincipal slaQueue expiryTombstoneQueue deadlinePackageToWorkId
  deadlinePackageToWorkId = .directory~new
  do package over queueManager~authorisedPackages(adminPrincipal)
    if package~currentQueue <> slaQueue & package~currentQueue <> expiryTombstoneQueue then iterate
    payload = package~payload
    if payload == .nil then iterate
    if \payload~hasMethod("hasIndex") then iterate
    if payload["schema"] <> "regulated.intermediary.work-deadline/1" then iterate
    deadlinePackageToWorkId[package~packageId] = payload["work_item_id"]
  end
  return deadlinePackageToWorkId~items

::method scheduleDeadline private
  expose queueManager slaQueue adminPrincipal timeSource deadlinePackageToWorkId
  use arg item
  if item~slaSeconds <= 0 then return .RIDResult~success(item)
  if item~status <> "OPEN" then return .RIDResult~success(item)
  existing = self~deadlineExists(item~workItemId)
  if existing <> .nil then do
    deadlinePackageToWorkId[existing~packageId] = item~workItemId
    return .RIDResult~success(existing, "DEADLINE_ALREADY_SCHEDULED")
  end
  remaining = timeSource~secondsUntil(item~dueTick)
  if remaining <= 0 then return self~markOverdue(item~workItemId, "SLA_RECOVERY_OVERDUE")
  payload = .directory~new
  payload["schema"] = "regulated.intermediary.work-deadline/1"
  payload["work_item_id"] = item~workItemId
  payload["case_id"] = item~caseId
  payload["due_tick"] = item~dueTick~string
  r = queueManager~put(slaQueue, payload, self~queueOptions(item~caseId, item~priority, remaining), adminPrincipal)
  if \r~ok then return .RIDResult~failure("WORK_DEADLINE_SCHEDULE_FAILED", r~code || ":" || r~detail)
  deadlinePackageToWorkId[r~value~packageId] = item~workItemId
  return .RIDResult~success(r~value)

::method applyAuditRow private
  expose workItems
  use arg row
  if row == .nil then return .RIDResult~failure("INVALID_WORK_AUDIT_ROW")
  if row["schema"] <> "regulated.intermediary.work-event/1" then return .RIDResult~failure("INVALID_WORK_AUDIT_SCHEMA")
  eventType = row["event_type"]~string~upper
  workId = row["work_item_id"]~string~upper
  item = workItems[workId]
  if eventType = "CREATE" then do
    if item == .nil then do
      item = .RIDWorkItem~new(workId, row["case_id"], row["firm_id"], row["representative_id"], row["product_family"], row["provider_status"], row["work_type"], row["audience"], row["priority"] + 0, row["sla_seconds"] + 0, row["completion_mode"], row["supersede_group"], row["source_event_id"], row["source_provider_sequence"] + 0, row["created_tick"] + 0, row["due_tick"] + 0)
      workItems[workId] = item
    end
    return .RIDResult~success(item)
  end
  if item == .nil then return .RIDResult~failure("WORK_AUDIT_ITEM_NOT_FOUND", workId)
  select
    when eventType = "SUPERSEDE" then ignore = item~supersede
    when eventType = "OVERDUE" then ignore = item~markOverdue
    when eventType = "COMPLETE" then ignore = item~complete(row["evidence_ref"])
    otherwise return .RIDResult~failure("UNKNOWN_WORK_AUDIT_EVENT", eventType)
  end
  return .RIDResult~success(item)

::method recover
  expose queueManager adminPrincipal auditQueue slaQueue workItems
  workItems = .directory~new
  /* All audit packages use one priority, so queue order is append order. */
  do package over queueManager~authorisedPackages(adminPrincipal)
    if package~currentQueue <> auditQueue then iterate
    r = self~applyAuditRow(package~payload)
    if \r~ok then return r
  end
  ignore = self~mapDeadlines
  do id over workItems~allIndexes
    item = workItems[id]
    if item~status = "OPEN" then do
      r = self~scheduleDeadline(item)
      if \r~ok then return r
    end
  end
  /* Expiry is deliberate and deterministic; its trigger produces OVERDUE. */
  r = queueManager~sweepExpired(slaQueue, adminPrincipal)
  if \r~ok then return .RIDResult~failure("WORK_SLA_SWEEP_FAILED", r~code || ":" || r~detail)
  return .RIDResult~success(self, "WORK_RECOVERED=" || workItems~items)

::method processStatusOne
  expose queueManager engine catalog workPolicy adminPrincipal timeSource statusInputQueue auditQueue slaQueue deadLetterQueue workItems deadlinePackageToWorkId
  br = queueManager~beginUnitOfWork(adminPrincipal)
  if \br~ok then return .RIDResult~failure("WORK_UOW_BEGIN_FAILED", br~code)
  uow = br~value
  gr = queueManager~uowGet(uow, statusInputQueue)
  if \gr~ok then do
    ignore = queueManager~rollbackUnitOfWork(uow)
    return .RIDResult~failure(gr~code, gr~detail)
  end
  pkg = gr~value
  row = pkg~payload
  if row == .nil | row["schema"] <> "regulated.intermediary.case-status-projection/1" then do
    reject = .directory~new
    reject["schema"] = "regulated.intermediary.work-reject/1"; reject["reason"] = "INVALID_CASE_STATUS_PROJECTION"
    reject["case_id"] = pkg~correlationId; reject["source_package_id"] = pkg~packageId
    ignore = queueManager~uowPut(uow, deadLetterQueue, reject, self~queueOptions(pkg~correlationId, 100, 0))
    ignore = queueManager~commitUnitOfWork(uow)
    return .RIDResult~failure("INVALID_CASE_STATUS_PROJECTION")
  end
  caseId = row["case_id"]~string~upper
  c = engine~case(caseId)
  if c == .nil then do
    ignore = queueManager~rollbackUnitOfWork(uow)
    return .RIDResult~failure("UNKNOWN_CASE", caseId)
  end
  p = catalog~product(c~productRefId)
  if p == .nil then do
    ignore = queueManager~rollbackUnitOfWork(uow)
    return .RIDResult~failure("UNKNOWN_PRODUCT", c~productRefId)
  end

  sourceExisting = self~workForSourceEvent(caseId, row["source_event_id"])
  if sourceExisting <> .nil then do
    cr = queueManager~commitUnitOfWork(uow)
    if \cr~ok then return .RIDResult~failure("WORK_UOW_COMMIT_FAILED", cr~code || ":" || cr~detail)
    return .RIDResult~success(sourceExisting, "WORK_SOURCE_EVENT_DUPLICATE")
  end

  changed = .array~new
  unresolvedSignature = self~unresolvedSignatureWork(caseId)
  signatureConflict = unresolvedSignature <> .nil & self~terminalProviderStatus(row["provider_status"])
  /* Any new material provider state supersedes prior provider-status work for
     this case. The source status projection is already sequence/idempotency safe.
     If a provider has reached a terminal state while signature work is still
     unresolved, the old task is superseded but replaced by a critical exception. */
  do id over workItems~allIndexes
    item = workItems[id]
    if item~caseId <> caseId then iterate
    if item~supersedeGroup <> "PROVIDER_STATUS" then iterate
    if item~status <> "OPEN" & item~status <> "OVERDUE" then iterate
    audit = self~auditRowFor("SUPERSEDE", item, row["source_event_id"])
    ar = queueManager~uowPut(uow, auditQueue, audit, self~queueOptions(caseId, 0, 0))
    if \ar~ok then do; ignore = queueManager~rollbackUnitOfWork(uow); return .RIDResult~failure("WORK_AUDIT_STAGE_FAILED", ar~code); end
    changed~append(.array~of("SUPERSEDE", item))
  end

  if signatureConflict then rule = .RIDWorkRule~new("SIGNATURE-CONFLICT", p~productFamily, row["provider_status"], "REVIEW_UNSIGNED_PROVIDER_COMPLETION", "INTERMEDIARY", 100, 3600, "EXCEPTION_REVIEW")
  else rule = workPolicy~resolve(p~productFamily, row["provider_status"])
  newItem = .nil
  if rule <> .nil & rule~workType <> "" then do
    workId = self~workIdFor(caseId, row["source_event_id"], rule~ruleId)
    existing = workItems[workId]
    if existing == .nil then do
      createdTick = timeSource~nowTick
      if rule~slaSeconds > 0 then dueTick = timeSource~addSeconds(createdTick, rule~slaSeconds)
      else dueTick = 0
      newItem = .RIDWorkItem~new(workId, caseId, c~firmId, c~representativeId, p~productFamily, row["provider_status"], rule~workType, rule~audience, rule~priority, rule~slaSeconds, rule~completionMode, rule~supersedeGroup, row["source_event_id"], row["provider_sequence"] + 0, createdTick, dueTick)
      audit = self~auditRowFor("CREATE", newItem, "")
      ar = queueManager~uowPut(uow, auditQueue, audit, self~queueOptions(caseId, 0, 0))
      if \ar~ok then do; ignore = queueManager~rollbackUnitOfWork(uow); return .RIDResult~failure("WORK_AUDIT_STAGE_FAILED", ar~code); end
      if rule~slaSeconds > 0 then do
        deadline = .directory~new
        deadline["schema"] = "regulated.intermediary.work-deadline/1"
        deadline["work_item_id"] = newItem~workItemId
        deadline["case_id"] = newItem~caseId
        deadline["due_tick"] = newItem~dueTick~string
        dr = queueManager~uowPut(uow, slaQueue, deadline, self~queueOptions(caseId, newItem~priority, rule~slaSeconds))
        if \dr~ok then do; ignore = queueManager~rollbackUnitOfWork(uow); return .RIDResult~failure("WORK_DEADLINE_STAGE_FAILED", dr~code); end
      end
      changed~append(.array~of("CREATE", newItem))
    end
  end
  cr = queueManager~commitUnitOfWork(uow)
  if \cr~ok then return .RIDResult~failure("WORK_UOW_COMMIT_FAILED", cr~code || ":" || cr~detail)

  do change over changed
    kind = change[1]; item = change[2]
    if kind = "SUPERSEDE" then ignore = item~supersede
    else if kind = "CREATE" then workItems[item~workItemId] = item
    r = self~publishWork(item)
    if \r~ok then return r
  end
  ignore = self~mapDeadlines
  r = self~publishAttention(caseId)
  if \r~ok then return r
  if newItem == .nil then return .RIDResult~success(c, "CASE_STATUS_PROJECTED_NO_ACTION")
  return .RIDResult~success(newItem, "WORK_CREATED")

::method markOverdue private
  expose queueManager adminPrincipal auditQueue overdueQueue
  use arg workId, evidenceRef = "SLA_EXPIRED"
  item = self~workItem(workId)
  if item == .nil then return .RIDResult~failure("WORK_ITEM_NOT_FOUND", workId)
  if item~status = "OVERDUE" then return .RIDResult~success(item, "WORK_ALREADY_OVERDUE")
  if item~status <> "OPEN" then return .RIDResult~success(item, "WORK_NOT_ACTIVE")
  audit = self~auditRowFor("OVERDUE", item, evidenceRef)
  br = queueManager~beginUnitOfWork(adminPrincipal)
  if \br~ok then return .RIDResult~failure("WORK_UOW_BEGIN_FAILED", br~code)
  uow = br~value
  ar = queueManager~uowPut(uow, auditQueue, audit, self~queueOptions(item~caseId, 0, 0))
  if \ar~ok then do; ignore = queueManager~rollbackUnitOfWork(uow); return .RIDResult~failure("WORK_AUDIT_STAGE_FAILED", ar~code); end
  overdue = self~workProjection(item)
  overdue["status"] = "OVERDUE"
  overdue["reason"] = evidenceRef~string
  or = queueManager~uowPut(uow, overdueQueue, overdue, self~queueOptions(item~caseId, 100, 0))
  if \or~ok then do; ignore = queueManager~rollbackUnitOfWork(uow); return .RIDResult~failure("WORK_OVERDUE_STAGE_FAILED", or~code); end
  cr = queueManager~commitUnitOfWork(uow)
  if \cr~ok then return .RIDResult~failure("WORK_UOW_COMMIT_FAILED", cr~code)
  ignore = item~markOverdue
  r = self~publishWork(item); if \r~ok then return r
  r = self~publishAttention(item~caseId); if \r~ok then return r
  return .RIDResult~success(item, "WORK_OVERDUE")

::method onQueueTrigger
  expose slaQueue deadlinePackageToWorkId
  use arg event
  if event~queueName <> slaQueue | event~eventType <> "EXPIRE" then return .true
  workId = deadlinePackageToWorkId[event~packageId]
  if workId == .nil then do
    ignore = self~mapDeadlines
    workId = deadlinePackageToWorkId[event~packageId]
  end
  if workId == .nil then return .false
  r = self~markOverdue(workId, "QUEUE_TTL_EXPIRED:" || event~packageId)
  return r~ok

::method completeWork
  expose queueManager adminPrincipal auditQueue
  use arg workId, evidenceRef = "", signatureEnvelope = .nil
  item = self~workItem(workId)
  if item == .nil then return .RIDResult~failure("WORK_ITEM_NOT_FOUND", workId)
  if item~status = "COMPLETE" then return .RIDResult~success(item, "WORK_ALREADY_COMPLETE")
  if item~status = "SUPERSEDED" then return .RIDResult~failure("WORK_ITEM_SUPERSEDED")
  if item~completionMode = "SIGNATURE" then do
    if signatureEnvelope == .nil then return .RIDResult~failure("COMPLETE_SIGNATURE_REQUIRED")
    if \signatureEnvelope~isA(.RIDSignatureEnvelope) then return .RIDResult~failure("COMPLETE_SIGNATURE_REQUIRED")
    if signatureEnvelope~caseId <> item~caseId then return .RIDResult~failure("SIGNATURE_CASE_MISMATCH")
    if signatureEnvelope~state <> "COMPLETE" then return .RIDResult~failure("SIGNATURE_NOT_COMPLETE")
    evidenceRef = "SIGNATURE_ENVELOPE:" || signatureEnvelope~envelopeId
  end
  else if evidenceRef~string~strip = "" then return .RIDResult~failure("COMPLETION_EVIDENCE_REQUIRED")
  audit = self~auditRowFor("COMPLETE", item, evidenceRef)
  r = queueManager~put(auditQueue, audit, self~queueOptions(item~caseId, 0, 0), adminPrincipal)
  if \r~ok then return .RIDResult~failure("WORK_COMPLETE_AUDIT_FAILED", r~code || ":" || r~detail)
  ignore = item~complete(evidenceRef)
  r = self~publishWork(item); if \r~ok then return r
  r = self~publishAttention(item~caseId); if \r~ok then return r
  return .RIDResult~success(item, "WORK_COMPLETE")

::requires "RegulatedIntermediaryDistribution.cls"
::requires "RIDDigitalSigning.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"
