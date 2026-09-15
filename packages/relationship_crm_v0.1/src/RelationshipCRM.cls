/*
 * Relationship CRM v0.1
 *
 * General, policy-driven relationship-management domain.  This is not Core
 * Banking, a sanctions engine, a case engine, or a user interface.  It owns
 * relationship servicing facts and references to authoritative facts held
 * elsewhere.
 */

::class RelationshipCRMBuild public
::constant VERSION "0.1"
::constant API_VERSION "relationship.crm/0.1"
::constant PRODUCT "ooRexx Relationship CRM"
::constant DEFAULT_POLICY_ID "RELATIONSHIP-CRM-CORE"

::class RelationshipCRMResult public
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

::class RelationshipCRMCanonical public
::method token class
  use arg value
  if value == .nil then return ""
  return value~string~strip~upper
::method copyArray class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source; out~append(item); end
  return out
::method contains class
  use arg source, wanted
  wanted = self~token(wanted)
  if source == .nil then return .false
  do item over source
    if self~token(item) = wanted then return .true
  end
  return .false
::method visibilityRank class
  use arg visibility
  select
    when self~token(visibility) = "PUBLIC" then return 10
    when self~token(visibility) = "CUSTOMER" then return 20
    when self~token(visibility) = "INTERNAL" then return 30
    when self~token(visibility) = "RESTRICTED" then return 40
    when self~token(visibility) = "SECRET" then return 50
    otherwise return 999
  end
::method field class
  use arg tag, value = ""
  if value == .nil then rendered = "<NIL>"
  else rendered = value~string
  return tag~string || ":" || rendered~length || ":" || rendered

::class RelationshipCRMAlchemyContext public
::attribute sealer get
::attribute authority get
::method init
  expose sealer authority
  use arg sealerArg = .nil, authorityArg = .nil
  sealer = sealerArg; authority = authorityArg

::class RelationshipCRMAlchemyObject subclass AlchemyObject public
::attribute domainObjectKind get
::method initDomainAlchemy protected
  expose domainObjectKind
  use arg kindArg, contextArg = .nil
  kind = .RelationshipCRMCanonical~token(kindArg)
  sealer = .nil; authority = .nil
  if contextArg <> .nil then do
    if \contextArg~isA(.RelationshipCRMAlchemyContext) then raise syntax 88.951 array("Relationship CRM Alchemy context invalid")
    sealer = contextArg~sealer; authority = contextArg~authority
  end
  meta = .directory~new
  meta["PURPOSE"] = "policy-driven relationship servicing domain object: " || kind
  meta["PACKAGE"] = "relationship_crm"
  meta["PACKAGE_VERSION"] = .RelationshipCRMBuild~VERSION
  meta["COMPONENT"] = "relationship_crm"
  meta["DOMAIN_OBJECT_KIND"] = kind
  meta["DESIGN_LIMITATIONS"] = "CRM relationship facts never grant banking, legal, security, sanctions or ledger authority."
  self~init:super(meta, sealer, authority)
  domainObjectKind = kind
  self~registerExternalRequirement("library", "alchemy_objects", "0.8", .true)
  return self

/* Policy payload -------------------------------------------------------- */
::class RelationshipCRMActionRule public
::attribute ruleId get
::attribute objectKind get
::attribute currentState get
::attribute action get
::attribute actorRole get
::attribute targetState get
::attribute allow get
::method init
  expose ruleId objectKind currentState action actorRole targetState allow
  use arg ruleIdArg, objectKindArg, currentStateArg, actionArg, actorRoleArg, targetStateArg = "", allowArg = .true
  ruleId = ruleIdArg~string
  objectKind = .RelationshipCRMCanonical~token(objectKindArg)
  currentState = .RelationshipCRMCanonical~token(currentStateArg)
  action = .RelationshipCRMCanonical~token(actionArg)
  actorRole = .RelationshipCRMCanonical~token(actorRoleArg)
  targetState = .RelationshipCRMCanonical~token(targetStateArg)
  allow = allowArg
::method matches
  expose objectKind currentState action actorRole
  use arg kindArg, stateArg, actionArg, roleArg
  kind = .RelationshipCRMCanonical~token(kindArg); state = .RelationshipCRMCanonical~token(stateArg)
  actionWanted = .RelationshipCRMCanonical~token(actionArg); role = .RelationshipCRMCanonical~token(roleArg)
  return (objectKind = "*" | objectKind = kind) & (currentState = "*" | currentState = state) & (action = "*" | action = actionWanted) & (actorRole = "*" | actorRole = role)
::method specificity
  expose objectKind currentState action actorRole
  score = 0
  if objectKind \= "*" then score += 8
  if currentState \= "*" then score += 4
  if action \= "*" then score += 2
  if actorRole \= "*" then score += 1
  return score

::class RelationshipCRMProjectionRule public
::attribute ruleId get
::attribute actorRole get
::attribute maxVisibility get
::attribute includeOperationalDetail get
::method init
  expose ruleId actorRole maxVisibility includeOperationalDetail
  use arg ruleIdArg, actorRoleArg, maxVisibilityArg = "INTERNAL", includeDetailArg = .true
  ruleId = ruleIdArg~string
  actorRole = .RelationshipCRMCanonical~token(actorRoleArg)
  maxVisibility = .RelationshipCRMCanonical~token(maxVisibilityArg)
  includeOperationalDetail = includeDetailArg
::method matches
  expose actorRole
  use arg roleArg
  role = .RelationshipCRMCanonical~token(roleArg)
  return actorRole = "*" | actorRole = role
::method specificity
  expose actorRole
  if actorRole = "*" then return 0
  return 1

::class RelationshipCRMPolicy public
::attribute sealed get
::method init
  expose actionRules projectionRules sealed
  actionRules = .array~new; projectionRules = .array~new; sealed = .false
::method addActionRule
  expose actionRules sealed
  use arg rule
  if sealed then raise syntax 88.952 array("RelationshipCRMPolicy is sealed")
  actionRules~append(rule); return self
::method addProjectionRule
  expose projectionRules sealed
  use arg rule
  if sealed then raise syntax 88.952 array("RelationshipCRMPolicy is sealed")
  projectionRules~append(rule); return self
::method seal
  expose sealed
  sealed = .true; return self
::method publicationEligible
  expose sealed actionRules projectionRules
  return sealed & actionRules~items > 0 & projectionRules~items > 0
::method semanticIdentity
  expose actionRules projectionRules sealed
  if \sealed then raise syntax 88.953 array("semanticIdentity requires sealed RelationshipCRMPolicy")
  text = "RELATIONSHIP-CRM-POLICY/1" || '0a'x
  do r over actionRules
    text ||= .RelationshipCRMCanonical~field("ACTION", r~ruleId || "|" || r~objectKind || "|" || r~currentState || "|" || r~action || "|" || r~actorRole || "|" || r~targetState || "|" || r~allow) || '0a'x
  end
  do r over projectionRules
    text ||= .RelationshipCRMCanonical~field("PROJECTION", r~ruleId || "|" || r~actorRole || "|" || r~maxVisibility || "|" || r~includeOperationalDetail) || '0a'x
  end
  return text
::method decideAction
  expose actionRules
  use arg kind, state, action, role
  best = .nil; bestScore = -1
  do r over actionRules
    if r~matches(kind, state, action, role) then do
      score = r~specificity
      if score > bestScore then do; best = r; bestScore = score; end
    end
  end
  if best == .nil then return .RelationshipCRMResult~failure("CRM_POLICY_NO_ACTION_RULE", kind || ":" || state || ":" || action || ":" || role)
  if \best~allow then return .RelationshipCRMResult~failure("CRM_POLICY_DENIED", best~ruleId)
  return .RelationshipCRMResult~success(best)
::method decideProjection
  expose projectionRules
  use arg role
  best = .nil; bestScore = -1
  do r over projectionRules
    if r~matches(role) then do
      score = r~specificity
      if score > bestScore then do; best = r; bestScore = score; end
    end
  end
  if best == .nil then return .RelationshipCRMResult~failure("CRM_POLICY_NO_PROJECTION_RULE", role)
  return .RelationshipCRMResult~success(best)

::class RelationshipCRMPolicyGate public
::method init
  expose catalog policyId deploymentPoint
  use arg catalogArg, policyIdArg = .nil, deploymentPointArg = .nil
  if catalogArg == .nil then raise syntax 88.954 array("RelationshipCRMPolicyGate catalog required")
  catalog = catalogArg
  if policyIdArg == .nil then policyId = .RelationshipCRMBuild~DEFAULT_POLICY_ID
  else policyId = .RelationshipCRMCanonical~token(policyIdArg)
  deploymentPoint = deploymentPointArg
::method resolve
  expose catalog policyId deploymentPoint
  use arg atTime
  if atTime == .nil then atTime = .DateTime~new
  if deploymentPoint <> .nil & catalog~hasMethod("RESOLVEFORCONTEXT") then resolved = catalog~resolveForContext(policyId, deploymentPoint, atTime)
  else resolved = catalog~resolve(policyId, atTime)
  if \resolved~ok then return .RelationshipCRMResult~failure("CRM_POLICY_RESOLUTION_FAILED", resolved~code || ":" || resolved~detail)
  release = resolved~value
  if release~payload == .nil then return .RelationshipCRMResult~failure("CRM_POLICY_PAYLOAD_REQUIRED")
  d = .directory~new; d["release"] = release; d["policy"] = release~payload
  return .RelationshipCRMResult~success(d)

/* Domain values --------------------------------------------------------- */
::class RelationshipCRMPolicyEvidence public
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute ruleId get
::method init
  expose policyId policyVersion policyIdentity ruleId
  use arg idArg, versionArg, identityArg, ruleArg
  policyId = idArg~string; policyVersion = versionArg~string; policyIdentity = identityArg~string; ruleId = ruleArg~string
::method queuePersistentType; return "relationship.crm.policy.evidence/1"
::method queuePersistentState
  expose policyId policyVersion policyIdentity ruleId
  s=.table~new; s["policyId"]=policyId; s["policyVersion"]=policyVersion; s["policyIdentity"]=policyIdentity; s["ruleId"]=ruleId; return s
::method queueRestoreState
  expose policyId policyVersion policyIdentity ruleId
  use arg s
  policyId=s["policyId"]~string; policyVersion=s["policyVersion"]~string; policyIdentity=s["policyIdentity"]~string; ruleId=s["ruleId"]~string; return self

::class RelationshipCRMEvent public
::attribute eventId get
::attribute eventType get
::attribute objectKind get
::attribute objectId get
::attribute actorId get
::attribute actorRole get
::attribute occurredAt get
::attribute fromState get
::attribute toState get
::attribute policyEvidence get
::method init
  expose eventId eventType objectKind objectId actorId actorRole occurredAt fromState toState policyEvidence
  use arg eventIdArg, eventTypeArg, kindArg, objectIdArg, actorIdArg, actorRoleArg, occurredAtArg, fromArg = "", toArg = "", evidenceArg = .nil
  eventId=eventIdArg~string; eventType=.RelationshipCRMCanonical~token(eventTypeArg); objectKind=.RelationshipCRMCanonical~token(kindArg); objectId=objectIdArg~string
  actorId=actorIdArg~string; actorRole=.RelationshipCRMCanonical~token(actorRoleArg); occurredAt=occurredAtArg; fromState=.RelationshipCRMCanonical~token(fromArg); toState=.RelationshipCRMCanonical~token(toArg); policyEvidence=evidenceArg
::method queuePersistentType; return "relationship.crm.event/1"
::method queuePersistentState
  expose eventId eventType objectKind objectId actorId actorRole occurredAt fromState toState policyEvidence
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["objectKind"]=objectKind; s["objectId"]=objectId; s["actorId"]=actorId; s["actorRole"]=actorRole; s["occurredAt"]=occurredAt~string; s["fromState"]=fromState; s["toState"]=toState; s["policyEvidence"]=policyEvidence; return s
::method queueRestoreState
  expose eventId eventType objectKind objectId actorId actorRole occurredAt fromState toState policyEvidence
  use arg s
  eventId=s["eventId"]~string; eventType=s["eventType"]~string; objectKind=s["objectKind"]~string; objectId=s["objectId"]~string; actorId=s["actorId"]~string; actorRole=s["actorRole"]~string; occurredAt=.DateTime~fromIsoDate(s["occurredAt"]~string); fromState=s["fromState"]~string; toState=s["toState"]~string; policyEvidence=s["policyEvidence"]; return self

::class RelationshipRecord subclass RelationshipCRMAlchemyObject public
::attribute relationshipId get
::attribute subjectSystem get
::attribute subjectRef get
::attribute servicingOwnerId
::attribute servicingOwnerRole
::attribute status get
::attribute visibilityClass get
::attribute openedAt get
::attribute revision get
::method init
  expose relationshipId subjectSystem subjectRef servicingOwnerId servicingOwnerRole status visibilityClass openedAt revision events
  use arg idArg, subjectSystemArg, subjectRefArg, ownerIdArg = "", ownerRoleArg = "SERVICE", statusArg = "ACTIVE", visibilityArg = "INTERNAL", openedAtArg = .nil, contextArg = .nil
  self~initDomainAlchemy("RELATIONSHIPRECORD", contextArg)
  relationshipId=idArg~string; subjectSystem=.RelationshipCRMCanonical~token(subjectSystemArg); subjectRef=subjectRefArg~string; servicingOwnerId=ownerIdArg~string; servicingOwnerRole=.RelationshipCRMCanonical~token(ownerRoleArg)
  status=.RelationshipCRMCanonical~token(statusArg); visibilityClass=.RelationshipCRMCanonical~token(visibilityArg); if openedAtArg==.nil then openedAt=.DateTime~new; else openedAt=openedAtArg; revision=0; events=.array~new
  if relationshipId="" | subjectSystem="" | subjectRef="" then raise syntax 88.955 array("RelationshipRecord identity required")
::method events
  expose events
  return .RelationshipCRMCanonical~copyArray(events)
::method addEvent
  expose events revision
  use arg event
  events~append(event); revision += 1; return event
::method applyStatus
  expose status
  use arg state
  status=.RelationshipCRMCanonical~token(state); return self
::method queuePersistentType; return "relationship.crm.relationship/1"
::method queuePersistentState
  expose relationshipId subjectSystem subjectRef servicingOwnerId servicingOwnerRole status visibilityClass openedAt revision events
  s=.table~new; s["relationshipId"]=relationshipId; s["subjectSystem"]=subjectSystem; s["subjectRef"]=subjectRef; s["servicingOwnerId"]=servicingOwnerId; s["servicingOwnerRole"]=servicingOwnerRole; s["status"]=status; s["visibilityClass"]=visibilityClass; s["openedAt"]=openedAt~string; s["revision"]=revision~string; s["events"]=events; return s
::method queueRestoreState
  expose relationshipId subjectSystem subjectRef servicingOwnerId servicingOwnerRole status visibilityClass openedAt revision events
  use arg s
  relationshipId=s["relationshipId"]~string; subjectSystem=s["subjectSystem"]~string; subjectRef=s["subjectRef"]~string; servicingOwnerId=s["servicingOwnerId"]~string; servicingOwnerRole=s["servicingOwnerRole"]~string; status=s["status"]~string; visibilityClass=s["visibilityClass"]~string; openedAt=.DateTime~fromIsoDate(s["openedAt"]~string); revision=s["revision"]+0; events=s["events"]; return self

::class RelationshipInteractionRef subclass RelationshipCRMAlchemyObject public
::attribute interactionId get
::attribute relationshipId get
::attribute sourceSystem get
::attribute sourceRef get
::attribute channel get
::attribute direction get
::attribute occurredAt get
::attribute semanticKind get
::attribute visibilityClass get
::method init
  expose interactionId relationshipId sourceSystem sourceRef channel direction occurredAt semanticKind visibilityClass
  use arg idArg, relationshipArg, sourceSystemArg, sourceRefArg, channelArg, directionArg, occurredAtArg, semanticArg="CUSTOMER_CONTACT", visibilityArg="INTERNAL", contextArg=.nil
  self~initDomainAlchemy("RELATIONSHIPINTERACTIONREF", contextArg)
  interactionId=idArg~string; relationshipId=relationshipArg~string; sourceSystem=.RelationshipCRMCanonical~token(sourceSystemArg); sourceRef=sourceRefArg~string; channel=.RelationshipCRMCanonical~token(channelArg); direction=.RelationshipCRMCanonical~token(directionArg); occurredAt=occurredAtArg; semanticKind=.RelationshipCRMCanonical~token(semanticArg); visibilityClass=.RelationshipCRMCanonical~token(visibilityArg)
  if interactionId="" | relationshipId="" | sourceSystem="" | sourceRef="" then raise syntax 88.956 array("RelationshipInteractionRef identity required")
::method queuePersistentType; return "relationship.crm.interaction/1"
::method queuePersistentState
  expose interactionId relationshipId sourceSystem sourceRef channel direction occurredAt semanticKind visibilityClass
  s=.table~new; s["interactionId"]=interactionId; s["relationshipId"]=relationshipId; s["sourceSystem"]=sourceSystem; s["sourceRef"]=sourceRef; s["channel"]=channel; s["direction"]=direction; s["occurredAt"]=occurredAt~string; s["semanticKind"]=semanticKind; s["visibilityClass"]=visibilityClass; return s
::method queueRestoreState
  expose interactionId relationshipId sourceSystem sourceRef channel direction occurredAt semanticKind visibilityClass
  use arg s
  interactionId=s["interactionId"]~string; relationshipId=s["relationshipId"]~string; sourceSystem=s["sourceSystem"]~string; sourceRef=s["sourceRef"]~string; channel=s["channel"]~string; direction=s["direction"]~string; occurredAt=.DateTime~fromIsoDate(s["occurredAt"]~string); semanticKind=s["semanticKind"]~string; visibilityClass=s["visibilityClass"]~string; return self

::class RelationshipCommunication subclass RelationshipCRMAlchemyObject public
::attribute communicationId get
::attribute relationshipId get
::attribute purpose get
::attribute channel get
::attribute destinationRef get
::attribute contentRef get
::attribute deliveryState get
::attribute createdAt get
::attribute visibilityClass get
::method init
  expose communicationId relationshipId purpose channel destinationRef contentRef deliveryState createdAt visibilityClass
  use arg idArg, relationshipArg, purposeArg, channelArg, destinationArg, contentRefArg, stateArg="RECORDED", createdAtArg=.nil, visibilityArg="INTERNAL", contextArg=.nil
  self~initDomainAlchemy("RELATIONSHIPCOMMUNICATION", contextArg)
  communicationId=idArg~string; relationshipId=relationshipArg~string; purpose=.RelationshipCRMCanonical~token(purposeArg); channel=.RelationshipCRMCanonical~token(channelArg); destinationRef=destinationArg~string; contentRef=contentRefArg~string; deliveryState=.RelationshipCRMCanonical~token(stateArg); if createdAtArg==.nil then createdAt=.DateTime~new; else createdAt=createdAtArg; visibilityClass=.RelationshipCRMCanonical~token(visibilityArg)
::method applyState
  expose deliveryState
  use arg state
  deliveryState=.RelationshipCRMCanonical~token(state); return self
::method queuePersistentType; return "relationship.crm.communication/1"
::method queuePersistentState
  expose communicationId relationshipId purpose channel destinationRef contentRef deliveryState createdAt visibilityClass
  s=.table~new; s["communicationId"]=communicationId; s["relationshipId"]=relationshipId; s["purpose"]=purpose; s["channel"]=channel; s["destinationRef"]=destinationRef; s["contentRef"]=contentRef; s["deliveryState"]=deliveryState; s["createdAt"]=createdAt~string; s["visibilityClass"]=visibilityClass; return s
::method queueRestoreState
  expose communicationId relationshipId purpose channel destinationRef contentRef deliveryState createdAt visibilityClass
  use arg s
  communicationId=s["communicationId"]~string; relationshipId=s["relationshipId"]~string; purpose=s["purpose"]~string; channel=s["channel"]~string; destinationRef=s["destinationRef"]~string; contentRef=s["contentRef"]~string; deliveryState=s["deliveryState"]~string; createdAt=.DateTime~fromIsoDate(s["createdAt"]~string); visibilityClass=s["visibilityClass"]~string; return self

::class RelationshipPromise subclass RelationshipCRMAlchemyObject public
::attribute promiseId get
::attribute relationshipId get
::attribute promiseKind get
::attribute dueAt get
::attribute ownerId get
::attribute ownerRole get
::attribute state get
::attribute sourceRef get
::attribute visibilityClass get
::method init
  expose promiseId relationshipId promiseKind dueAt ownerId ownerRole state sourceRef visibilityClass
  use arg idArg, relationshipArg, kindArg, dueAtArg, ownerIdArg, ownerRoleArg, stateArg="OPEN", sourceRefArg="", visibilityArg="INTERNAL", contextArg=.nil
  self~initDomainAlchemy("RELATIONSHIPPROMISE", contextArg)
  promiseId=idArg~string; relationshipId=relationshipArg~string; promiseKind=.RelationshipCRMCanonical~token(kindArg); dueAt=dueAtArg; ownerId=ownerIdArg~string; ownerRole=.RelationshipCRMCanonical~token(ownerRoleArg); state=.RelationshipCRMCanonical~token(stateArg); sourceRef=sourceRefArg~string; visibilityClass=.RelationshipCRMCanonical~token(visibilityArg)
::method applyState
  expose state
  use arg newState
  state=.RelationshipCRMCanonical~token(newState); return self
::method queuePersistentType; return "relationship.crm.promise/1"
::method queuePersistentState
  expose promiseId relationshipId promiseKind dueAt ownerId ownerRole state sourceRef visibilityClass
  s=.table~new; s["promiseId"]=promiseId; s["relationshipId"]=relationshipId; s["promiseKind"]=promiseKind; s["dueAt"]=dueAt~string; s["ownerId"]=ownerId; s["ownerRole"]=ownerRole; s["state"]=state; s["sourceRef"]=sourceRef; s["visibilityClass"]=visibilityClass; return s
::method queueRestoreState
  expose promiseId relationshipId promiseKind dueAt ownerId ownerRole state sourceRef visibilityClass
  use arg s
  promiseId=s["promiseId"]~string; relationshipId=s["relationshipId"]~string; promiseKind=s["promiseKind"]~string; dueAt=.DateTime~fromIsoDate(s["dueAt"]~string); ownerId=s["ownerId"]~string; ownerRole=s["ownerRole"]~string; state=s["state"]~string; sourceRef=s["sourceRef"]~string; visibilityClass=s["visibilityClass"]~string; return self

::class RelationshipTask subclass RelationshipCRMAlchemyObject public
::attribute taskId get
::attribute relationshipId get
::attribute taskKind get
::attribute assignedTo get
::attribute assignedRole get
::attribute dueAt get
::attribute state get
::attribute sourceRef get
::attribute visibilityClass get
::method init
  expose taskId relationshipId taskKind assignedTo assignedRole dueAt state sourceRef visibilityClass
  use arg idArg, relationshipArg, kindArg, assignedToArg, assignedRoleArg, dueAtArg, stateArg="OPEN", sourceRefArg="", visibilityArg="INTERNAL", contextArg=.nil
  self~initDomainAlchemy("RELATIONSHIPTASK", contextArg)
  taskId=idArg~string; relationshipId=relationshipArg~string; taskKind=.RelationshipCRMCanonical~token(kindArg); assignedTo=assignedToArg~string; assignedRole=.RelationshipCRMCanonical~token(assignedRoleArg); dueAt=dueAtArg; state=.RelationshipCRMCanonical~token(stateArg); sourceRef=sourceRefArg~string; visibilityClass=.RelationshipCRMCanonical~token(visibilityArg)
::method applyState
  expose state
  use arg newState
  state=.RelationshipCRMCanonical~token(newState); return self
::method queuePersistentType; return "relationship.crm.task/1"
::method queuePersistentState
  expose taskId relationshipId taskKind assignedTo assignedRole dueAt state sourceRef visibilityClass
  s=.table~new; s["taskId"]=taskId; s["relationshipId"]=relationshipId; s["taskKind"]=taskKind; s["assignedTo"]=assignedTo; s["assignedRole"]=assignedRole; s["dueAt"]=dueAt~string; s["state"]=state; s["sourceRef"]=sourceRef; s["visibilityClass"]=visibilityClass; return s
::method queueRestoreState
  expose taskId relationshipId taskKind assignedTo assignedRole dueAt state sourceRef visibilityClass
  use arg s
  taskId=s["taskId"]~string; relationshipId=s["relationshipId"]~string; taskKind=s["taskKind"]~string; assignedTo=s["assignedTo"]~string; assignedRole=s["assignedRole"]~string; dueAt=.DateTime~fromIsoDate(s["dueAt"]~string); state=s["state"]~string; sourceRef=s["sourceRef"]~string; visibilityClass=s["visibilityClass"]~string; return self

::class ComplaintRecord subclass RelationshipCRMAlchemyObject public
::attribute complaintId get
::attribute relationshipId get
::attribute originatingInteractionRef get
::attribute recognisedAt get
::attribute state get
::attribute caseRef get
::attribute visibilityClass get
::method init
  expose complaintId relationshipId originatingInteractionRef recognisedAt state caseRef visibilityClass
  use arg idArg, relationshipArg, interactionRefArg, recognisedAtArg, stateArg="OPEN", caseRefArg="", visibilityArg="INTERNAL", contextArg=.nil
  self~initDomainAlchemy("COMPLAINTRECORD", contextArg)
  complaintId=idArg~string; relationshipId=relationshipArg~string; originatingInteractionRef=interactionRefArg~string; recognisedAt=recognisedAtArg; state=.RelationshipCRMCanonical~token(stateArg); caseRef=caseRefArg~string; visibilityClass=.RelationshipCRMCanonical~token(visibilityArg)
::method linkCase
  expose caseRef
  use arg ref
  if caseRef \= "" & caseRef \= ref~string then return .false
  caseRef=ref~string; return .true
::method applyState
  expose state
  use arg newState
  state=.RelationshipCRMCanonical~token(newState); return self
::method queuePersistentType; return "relationship.crm.complaint/1"
::method queuePersistentState
  expose complaintId relationshipId originatingInteractionRef recognisedAt state caseRef visibilityClass
  s=.table~new; s["complaintId"]=complaintId; s["relationshipId"]=relationshipId; s["originatingInteractionRef"]=originatingInteractionRef; s["recognisedAt"]=recognisedAt~string; s["state"]=state; s["caseRef"]=caseRef; s["visibilityClass"]=visibilityClass; return s
::method queueRestoreState
  expose complaintId relationshipId originatingInteractionRef recognisedAt state caseRef visibilityClass
  use arg s
  complaintId=s["complaintId"]~string; relationshipId=s["relationshipId"]~string; originatingInteractionRef=s["originatingInteractionRef"]~string; recognisedAt=.DateTime~fromIsoDate(s["recognisedAt"]~string); state=s["state"]~string; caseRef=s["caseRef"]~string; visibilityClass=s["visibilityClass"]~string; return self

::class RelationshipServiceProfile subclass RelationshipCRMAlchemyObject public
::attribute profileId get
::attribute relationshipId get
::attribute profileClass get
::attribute communicationPreference get
::attribute serviceTreatment get
::attribute visibilityClass get
::attribute policyEvidence get
::method init
  expose profileId relationshipId profileClass communicationPreference serviceTreatment visibilityClass policyEvidence
  use arg idArg, relationshipArg, classArg, communicationArg, treatmentArg, visibilityArg="INTERNAL", evidenceArg=.nil, contextArg=.nil
  self~initDomainAlchemy("RELATIONSHIPSERVICEPROFILE", contextArg)
  profileId=idArg~string; relationshipId=relationshipArg~string; profileClass=.RelationshipCRMCanonical~token(classArg); communicationPreference=.RelationshipCRMCanonical~token(communicationArg); serviceTreatment=.RelationshipCRMCanonical~token(treatmentArg); visibilityClass=.RelationshipCRMCanonical~token(visibilityArg); policyEvidence=evidenceArg
::method queuePersistentType; return "relationship.crm.service.profile/1"
::method queuePersistentState
  expose profileId relationshipId profileClass communicationPreference serviceTreatment visibilityClass policyEvidence
  s=.table~new; s["profileId"]=profileId; s["relationshipId"]=relationshipId; s["profileClass"]=profileClass; s["communicationPreference"]=communicationPreference; s["serviceTreatment"]=serviceTreatment; s["visibilityClass"]=visibilityClass; s["policyEvidence"]=policyEvidence; return s
::method queueRestoreState
  expose profileId relationshipId profileClass communicationPreference serviceTreatment visibilityClass policyEvidence
  use arg s
  profileId=s["profileId"]~string; relationshipId=s["relationshipId"]~string; profileClass=s["profileClass"]~string; communicationPreference=s["communicationPreference"]~string; serviceTreatment=s["serviceTreatment"]~string; visibilityClass=s["visibilityClass"]~string; policyEvidence=s["policyEvidence"]; return self

::class RelationshipCRMProjection public
::attribute relationship get
::attribute ruleId get
::attribute shell get
::method init
  expose relationship ruleId shell interactions communications promises tasks complaints profile
  use arg relationshipArg, ruleArg, shellArg=.false
  relationship=relationshipArg; ruleId=ruleArg~string; shell=shellArg; interactions=.array~new; communications=.array~new; promises=.array~new; tasks=.array~new; complaints=.array~new; profile=.nil
::method addInteraction; expose interactions; use arg v; interactions~append(v); return self
::method addCommunication; expose communications; use arg v; communications~append(v); return self
::method addPromise; expose promises; use arg v; promises~append(v); return self
::method addTask; expose tasks; use arg v; tasks~append(v); return self
::method addComplaint; expose complaints; use arg v; complaints~append(v); return self
::method setProfile; expose profile; use arg v; profile=v; return v
::method interactions; expose interactions; return .RelationshipCRMCanonical~copyArray(interactions)
::method communications; expose communications; return .RelationshipCRMCanonical~copyArray(communications)
::method promises; expose promises; return .RelationshipCRMCanonical~copyArray(promises)
::method tasks; expose tasks; return .RelationshipCRMCanonical~copyArray(tasks)
::method complaints; expose complaints; return .RelationshipCRMCanonical~copyArray(complaints)
::method profile; expose profile; return profile
::method queuePersistentType; return "relationship.crm.projection/1"
::method queuePersistentState
  expose relationship ruleId shell interactions communications promises tasks complaints profile
  s=.table~new; s["relationship"]=relationship; s["ruleId"]=ruleId; s["shell"]=shell~string; s["interactions"]=interactions; s["communications"]=communications; s["promises"]=promises; s["tasks"]=tasks; s["complaints"]=complaints; s["profile"]=profile; return s
::method queueRestoreState
  expose relationship ruleId shell interactions communications promises tasks complaints profile
  use arg s
  relationship=s["relationship"]; ruleId=s["ruleId"]~string; shell=(s["shell"]~string="1"); interactions=s["interactions"]; communications=s["communications"]; promises=s["promises"]; tasks=s["tasks"]; complaints=s["complaints"]; profile=s["profile"]; return self

/* Repository and engine ------------------------------------------------ */
::class RelationshipCRMRepository public
::method init
  expose relationships subjectIndex interactions communications promises tasks complaints profiles
  relationships=.table~new; subjectIndex=.table~new; interactions=.table~new; communications=.table~new; promises=.table~new; tasks=.table~new; complaints=.table~new; profiles=.table~new
::method addRelationship
  expose relationships subjectIndex
  use arg r
  if relationships~hasIndex(r~relationshipId) then return .RelationshipCRMResult~failure("CRM_RELATIONSHIP_DUPLICATE", r~relationshipId)
  relationships[r~relationshipId]=r; subjectIndex[r~subjectSystem || "|" || r~subjectRef]=r~relationshipId; return .RelationshipCRMResult~success(r)
::method relationship
  expose relationships
  use arg id
  if relationships~hasIndex(id~string) then return .RelationshipCRMResult~success(relationships[id~string])
  return .RelationshipCRMResult~failure("CRM_RELATIONSHIP_NOT_FOUND", id)
::method forSubject
  expose subjectIndex
  use arg system, ref
  key=.RelationshipCRMCanonical~token(system)||"|"||ref~string
  if \subjectIndex~hasIndex(key) then return .RelationshipCRMResult~failure("CRM_RELATIONSHIP_NOT_FOUND", key)
  return self~relationship(subjectIndex[key])
::method putInteraction; expose interactions; use arg o; interactions[o~interactionId]=o; return o
::method putCommunication; expose communications; use arg o; communications[o~communicationId]=o; return o
::method putPromise; expose promises; use arg o; promises[o~promiseId]=o; return o
::method putTask; expose tasks; use arg o; tasks[o~taskId]=o; return o
::method putComplaint; expose complaints; use arg o; complaints[o~complaintId]=o; return o
::method putProfile; expose profiles; use arg o; profiles[o~relationshipId]=o; return o
::method interaction; expose interactions; use arg id; return interactions[id~string]
::method communication; expose communications; use arg id; return communications[id~string]
::method promise; expose promises; use arg id; return promises[id~string]
::method task; expose tasks; use arg id; return tasks[id~string]
::method complaint; expose complaints; use arg id; return complaints[id~string]
::method profile; expose profiles; use arg id; return profiles[id~string]
::method valuesForRelationship private
  use arg table, relId
  out=.array~new
  do key over table~allIndexes
    o=table[key]
    if o~relationshipId = relId~string then out~append(o)
  end
  return out
::method interactionsFor; expose interactions; use arg id; return self~valuesForRelationship(interactions,id)
::method communicationsFor; expose communications; use arg id; return self~valuesForRelationship(communications,id)
::method promisesFor; expose promises; use arg id; return self~valuesForRelationship(promises,id)
::method tasksFor; expose tasks; use arg id; return self~valuesForRelationship(tasks,id)
::method complaintsFor; expose complaints; use arg id; return self~valuesForRelationship(complaints,id)
::method relationships; expose relationships; out=.array~new; do key over relationships~allIndexes; out~append(relationships[key]); end; return out
::method allInteractions; expose interactions; out=.array~new; do key over interactions~allIndexes; out~append(interactions[key]); end; return out
::method allCommunications; expose communications; out=.array~new; do key over communications~allIndexes; out~append(communications[key]); end; return out
::method allPromises; expose promises; out=.array~new; do key over promises~allIndexes; out~append(promises[key]); end; return out
::method allTasks; expose tasks; out=.array~new; do key over tasks~allIndexes; out~append(tasks[key]); end; return out
::method allComplaints; expose complaints; out=.array~new; do key over complaints~allIndexes; out~append(complaints[key]); end; return out
::method allProfiles; expose profiles; out=.array~new; do key over profiles~allIndexes; out~append(profiles[key]); end; return out

::class RelationshipCRMEngine subclass RelationshipCRMAlchemyObject public
::method init
  expose gate repository sequence
  use arg policyCatalog, policyId=.nil, repositoryArg=.nil, deploymentPoint=.nil, contextArg=.nil
  self~initDomainAlchemy("RELATIONSHIPCRMENGINE", contextArg)
  gate=.RelationshipCRMPolicyGate~new(policyCatalog, policyId, deploymentPoint)
  if repositoryArg==.nil then repository=.RelationshipCRMRepository~new; else repository=repositoryArg
  sequence=0
::method repository; expose repository; return repository
::method nextEvent private
  expose sequence
  use arg kind,id,type,actorId,actorRole,atTime,fromState,toState,evidence
  sequence += 1
  return .RelationshipCRMEvent~new("CRM-EVT-"||sequence||":"||id, type, kind, id, actorId, actorRole, atTime, fromState, toState, evidence)
::method evidence private
  use arg resolved, rule
  release=resolved["release"]
  return .RelationshipCRMPolicyEvidence~new(release~policyId, release~version, release~semanticIdentity, rule~ruleId)
::method decide private
  expose gate
  use arg kind,state,action,actorRole,atTime
  rr=gate~resolve(atTime); if \rr~ok then return rr
  resolved=rr~value; pd=resolved["policy"]~decideAction(kind,state,action,actorRole); if \pd~ok then return pd
  d=.directory~new; d["resolved"]=resolved; d["rule"]=pd~value; return .RelationshipCRMResult~success(d)
::method openRelationship
  expose repository
  use arg relationship, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  if relationship==.nil then return .RelationshipCRMResult~failure("CRM_RELATIONSHIP_REQUIRED")
  pd=self~decide("RELATIONSHIP", "", "OPEN", actorRole, atTime); if \pd~ok then return pd
  rule=pd~value["rule"]; if rule~targetState \= "" then relationship~applyStatus(rule~targetState)
  add=repository~addRelationship(relationship); if \add~ok then return add
  evidence=self~evidence(pd~value["resolved"],rule); relationship~addEvent(self~nextEvent("RELATIONSHIP",relationship~relationshipId,"RELATIONSHIP_OPENED",actorId,actorRole,atTime,"",relationship~status,evidence))
  return .RelationshipCRMResult~success(relationship)
::method recordInteraction
  expose repository
  use arg interaction, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  rr=repository~relationship(interaction~relationshipId); if \rr~ok then return rr
  pd=self~decide("INTERACTION","","RECORD",actorRole,atTime); if \pd~ok then return pd
  repository~putInteraction(interaction); evidence=self~evidence(pd~value["resolved"],pd~value["rule"]); rr~value~addEvent(self~nextEvent("INTERACTION",interaction~interactionId,"INTERACTION_RECORDED",actorId,actorRole,atTime,"","",evidence)); return .RelationshipCRMResult~success(interaction)
::method recordCommunication
  expose repository
  use arg o, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  rr=repository~relationship(o~relationshipId); if \rr~ok then return rr
  pd=self~decide("COMMUNICATION","","RECORD",actorRole,atTime); if \pd~ok then return pd
  repository~putCommunication(o); evidence=self~evidence(pd~value["resolved"],pd~value["rule"]); rr~value~addEvent(self~nextEvent("COMMUNICATION",o~communicationId,"COMMUNICATION_RECORDED",actorId,actorRole,atTime,"",o~deliveryState,evidence)); return .RelationshipCRMResult~success(o)
::method transitionCommunication
  expose repository
  use arg id, action, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  o=repository~communication(id); if o==.nil then return .RelationshipCRMResult~failure("CRM_COMMUNICATION_NOT_FOUND",id)
  pd=self~decide("COMMUNICATION",o~deliveryState,action,actorRole,atTime); if \pd~ok then return pd
  from=o~deliveryState; rule=pd~value["rule"]; o~applyState(rule~targetState); evidence=self~evidence(pd~value["resolved"],rule); r=repository~relationship(o~relationshipId)~value; r~addEvent(self~nextEvent("COMMUNICATION",o~communicationId,"COMMUNICATION_STATE_CHANGED",actorId,actorRole,atTime,from,o~deliveryState,evidence)); return .RelationshipCRMResult~success(o)
::method recordPromise
  expose repository
  use arg o, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  rr=repository~relationship(o~relationshipId); if \rr~ok then return rr
  pd=self~decide("PROMISE","","RECORD",actorRole,atTime); if \pd~ok then return pd
  repository~putPromise(o); evidence=self~evidence(pd~value["resolved"],pd~value["rule"]); rr~value~addEvent(self~nextEvent("PROMISE",o~promiseId,"PROMISE_RECORDED",actorId,actorRole,atTime,"",o~state,evidence)); return .RelationshipCRMResult~success(o)
::method transitionPromise
  expose repository
  use arg id, action, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  o=repository~promise(id); if o==.nil then return .RelationshipCRMResult~failure("CRM_PROMISE_NOT_FOUND",id)
  pd=self~decide("PROMISE",o~state,action,actorRole,atTime); if \pd~ok then return pd
  from=o~state; rule=pd~value["rule"]; o~applyState(rule~targetState); evidence=self~evidence(pd~value["resolved"],rule); repository~relationship(o~relationshipId)~value~addEvent(self~nextEvent("PROMISE",o~promiseId,"PROMISE_STATE_CHANGED",actorId,actorRole,atTime,from,o~state,evidence)); return .RelationshipCRMResult~success(o)
::method createTask
  expose repository
  use arg o, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  rr=repository~relationship(o~relationshipId); if \rr~ok then return rr
  pd=self~decide("TASK","","CREATE",actorRole,atTime); if \pd~ok then return pd
  repository~putTask(o); evidence=self~evidence(pd~value["resolved"],pd~value["rule"]); rr~value~addEvent(self~nextEvent("TASK",o~taskId,"TASK_CREATED",actorId,actorRole,atTime,"",o~state,evidence)); return .RelationshipCRMResult~success(o)
::method transitionTask
  expose repository
  use arg id, action, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  o=repository~task(id); if o==.nil then return .RelationshipCRMResult~failure("CRM_TASK_NOT_FOUND",id)
  pd=self~decide("TASK",o~state,action,actorRole,atTime); if \pd~ok then return pd
  from=o~state; rule=pd~value["rule"]; o~applyState(rule~targetState); evidence=self~evidence(pd~value["resolved"],rule); repository~relationship(o~relationshipId)~value~addEvent(self~nextEvent("TASK",o~taskId,"TASK_STATE_CHANGED",actorId,actorRole,atTime,from,o~state,evidence)); return .RelationshipCRMResult~success(o)
::method recogniseComplaint
  expose repository
  use arg o, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  rr=repository~relationship(o~relationshipId); if \rr~ok then return rr
  pd=self~decide("COMPLAINT","","RECOGNISE",actorRole,atTime); if \pd~ok then return pd
  repository~putComplaint(o); evidence=self~evidence(pd~value["resolved"],pd~value["rule"]); rr~value~addEvent(self~nextEvent("COMPLAINT",o~complaintId,"COMPLAINT_RECOGNISED",actorId,actorRole,atTime,"",o~state,evidence)); return .RelationshipCRMResult~success(o)
::method linkComplaintCase
  expose repository
  use arg id, caseRef, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  o=repository~complaint(id); if o==.nil then return .RelationshipCRMResult~failure("CRM_COMPLAINT_NOT_FOUND",id)
  pd=self~decide("COMPLAINT",o~state,"LINK_CASE",actorRole,atTime); if \pd~ok then return pd
  if \o~linkCase(caseRef) then return .RelationshipCRMResult~failure("CRM_COMPLAINT_CASE_CONFLICT",id)
  evidence=self~evidence(pd~value["resolved"],pd~value["rule"]); repository~relationship(o~relationshipId)~value~addEvent(self~nextEvent("COMPLAINT",o~complaintId,"COMPLAINT_CASE_LINKED",actorId,actorRole,atTime,o~state,o~state,evidence)); return .RelationshipCRMResult~success(o)
::method transitionComplaint
  expose repository
  use arg id, action, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  o=repository~complaint(id); if o==.nil then return .RelationshipCRMResult~failure("CRM_COMPLAINT_NOT_FOUND",id)
  pd=self~decide("COMPLAINT",o~state,action,actorRole,atTime); if \pd~ok then return pd
  from=o~state; rule=pd~value["rule"]; o~applyState(rule~targetState); evidence=self~evidence(pd~value["resolved"],rule); repository~relationship(o~relationshipId)~value~addEvent(self~nextEvent("COMPLAINT",o~complaintId,"COMPLAINT_STATE_CHANGED",actorId,actorRole,atTime,from,o~state,evidence)); return .RelationshipCRMResult~success(o)
::method setServiceProfile
  expose repository
  use arg o, actorId, actorRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  rr=repository~relationship(o~relationshipId); if \rr~ok then return rr
  pd=self~decide("SERVICE_PROFILE","","SET",actorRole,atTime); if \pd~ok then return pd
  evidence=self~evidence(pd~value["resolved"],pd~value["rule"])
  replacement=.RelationshipServiceProfile~new(o~profileId,o~relationshipId,o~profileClass,o~communicationPreference,o~serviceTreatment,o~visibilityClass,evidence)
  repository~putProfile(replacement); rr~value~addEvent(self~nextEvent("SERVICE_PROFILE",replacement~profileId,"SERVICE_PROFILE_SET",actorId,actorRole,atTime,"",replacement~profileClass,evidence)); return .RelationshipCRMResult~success(replacement)
::method project
  expose gate repository
  use arg relationshipId, viewerRole, atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  rr=repository~relationship(relationshipId); if \rr~ok then return rr
  resolved=gate~resolve(atTime); if \resolved~ok then return resolved
  pd=resolved~value["policy"]~decideProjection(viewerRole); if \pd~ok then return pd
  rule=pd~value; maxRank=.RelationshipCRMCanonical~visibilityRank(rule~maxVisibility); rel=rr~value
  shell=.RelationshipCRMCanonical~visibilityRank(rel~visibilityClass) > maxRank
  projection=.RelationshipCRMProjection~new(rel,rule~ruleId,shell)
  if shell then return .RelationshipCRMResult~success(projection)
  do o over repository~interactionsFor(rel~relationshipId); if .RelationshipCRMCanonical~visibilityRank(o~visibilityClass)<=maxRank then projection~addInteraction(o); end
  do o over repository~communicationsFor(rel~relationshipId); if .RelationshipCRMCanonical~visibilityRank(o~visibilityClass)<=maxRank then projection~addCommunication(o); end
  do o over repository~promisesFor(rel~relationshipId); if .RelationshipCRMCanonical~visibilityRank(o~visibilityClass)<=maxRank then projection~addPromise(o); end
  do o over repository~tasksFor(rel~relationshipId); if .RelationshipCRMCanonical~visibilityRank(o~visibilityClass)<=maxRank then projection~addTask(o); end
  do o over repository~complaintsFor(rel~relationshipId); if .RelationshipCRMCanonical~visibilityRank(o~visibilityClass)<=maxRank then projection~addComplaint(o); end
  p=repository~profile(rel~relationshipId); if p<>.nil then if .RelationshipCRMCanonical~visibilityRank(p~visibilityClass)<=maxRank then projection~setProfile(p)
  return .RelationshipCRMResult~success(projection)

::requires "AlchemyObject.cls"
::requires "InstitutionalPolicy.cls"
