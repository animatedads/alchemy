/*
 * Relationship Case v0.1
 *
 * General policy-driven relationship/case domain model.  It is intentionally
 * not a CRM database, banking engine, complaint ruleset, sanctions engine or
 * UI.  It gives those systems a shared durable case/correlation vocabulary.
 */

::class RelationshipCaseBuild public
::constant VERSION "0.2"
::constant API_VERSION "relationship.case/0.2"
::constant PRODUCT "ooRexx Relationship Case"
::constant DEFAULT_POLICY_ID "RELATIONSHIP-CASE-CORE"

::class RelationshipCaseResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  value = valueArg
::method success class
  use arg value = .nil, detail = ""
  return self~new(.true, "OK", detail, value)
::method failure class
  use arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)

::class RelationshipCaseCanonical public
::method token class
  use arg value
  if value == .nil then return ""
  return value~string~strip~upper
::method field class
  use arg tag, value = ""
  if value == .nil then rendered = "<NIL>"
  else rendered = value~string
  return tag~string || ":" || rendered~length || ":" || rendered
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

::class RelationshipCasePersistenceValue public
::method truth class
  use arg value
  if value == .true then return .true
  if value == .false | value == .nil then return .false
  text = value~string~upper
  return text = "1" | text = "TRUE" | text = "YES" | text = "ON"
::method boolText class
  use arg value
  if self~truth(value) then return "1"
  return "0"
::method dateText class
  use arg value
  if value == .nil then return ""
  return value~string
::method dateValue class
  use arg value
  text = value~string~strip
  if text = "" then return .nil
  return .DateTime~fromIsoDate(text)

::class RelationshipCaseAlchemyContext public
::attribute sealer get
::attribute authority get
::method init
  expose sealer authority
  use arg sealerArg = .nil, authorityArg = .nil
  sealer = sealerArg
  authority = authorityArg

::class RelationshipCaseAlchemyObject subclass AlchemyObject public
::attribute domainObjectKind get
::method initDomainAlchemy protected
  expose domainObjectKind
  use arg kindArg, contextArg = .nil
  kind = .RelationshipCaseCanonical~token(kindArg)
  sealer = .nil
  authority = .nil
  if contextArg <> .nil then do
    if \contextArg~isA(.RelationshipCaseAlchemyContext) then raise syntax 88.900 array("Relationship Case Alchemy context invalid")
    sealer = contextArg~sealer
    authority = contextArg~authority
  end
  meta = .directory~new
  meta["PURPOSE"] = "policy-driven relationship/case domain object: " || kind
  meta["PACKAGE"] = "relationship_case"
  meta["PACKAGE_VERSION"] = .RelationshipCaseBuild~VERSION
  meta["COMPONENT"] = "relationship_case"
  meta["DOMAIN_OBJECT_KIND"] = kind
  meta["DESIGN_LIMITATIONS"] = "Case state coordinates work; it never replaces authoritative banking, legal, security, reputation or interaction evidence."
  self~init:super(meta, sealer, authority)
  domainObjectKind = kind
  self~registerExternalRequirement("library", "alchemy_objects", "0.8", .true)
  return self

/* A case element is normally a reference to evidence or state owned elsewhere.
 * sourceRef is deliberately opaque.  The case does not flatten/copy the source
 * object's private content and does not promote an observation into a fact. */
::class RelationshipCaseElement subclass RelationshipCaseAlchemyObject public
::attribute elementId get
::attribute elementType get
::attribute semanticKind get
::attribute relationship get
::attribute sourceSystem get
::attribute sourceRef get
::attribute authorityClass get
::attribute recordedAt get
::attribute visibilityClass get
::attribute sealed get
::method init
  expose elementId elementType semanticKind relationship sourceSystem sourceRef authorityClass recordedAt visibilityClass tags sealed
  use arg elementIdArg, elementTypeArg, semanticKindArg, relationshipArg, sourceSystemArg, sourceRefArg, authorityClassArg = "REFERENCE", recordedAtArg = .nil, visibilityArg = "INTERNAL", contextArg = .nil
  self~initDomainAlchemy("RELATIONSHIPCASEELEMENT", contextArg)
  elementId = elementIdArg~string
  elementType = .RelationshipCaseCanonical~token(elementTypeArg)
  semanticKind = .RelationshipCaseCanonical~token(semanticKindArg)
  relationship = .RelationshipCaseCanonical~token(relationshipArg)
  sourceSystem = .RelationshipCaseCanonical~token(sourceSystemArg)
  sourceRef = sourceRefArg~string
  authorityClass = .RelationshipCaseCanonical~token(authorityClassArg)
  if recordedAtArg == .nil then recordedAt = .DateTime~new
  else recordedAt = recordedAtArg
  visibilityClass = .RelationshipCaseCanonical~token(visibilityArg)
  tags = .array~new
  sealed = .false
  if elementId = "" | elementType = "" | semanticKind = "" | relationship = "" | sourceSystem = "" | sourceRef = "" then raise syntax 88.901 array("RelationshipCaseElement identity fields required")
  if .RelationshipCaseCanonical~visibilityRank(visibilityClass) = 999 then raise syntax 88.902 array("RelationshipCaseElement visibility invalid: " || visibilityClass)
  self~registerStateVariable("elementId", "INTERNAL", "stable case element identifier")
  self~registerStateVariable("elementType", "INTERNAL", "semantic element type")
  self~registerStateVariable("semanticKind", "INTERNAL", "domain semantic kind")
  self~registerStateVariable("relationship", "INTERNAL", "relationship to the case")
  self~registerStateVariable("sourceSystem", "INTERNAL", "authoritative source system")
  self~registerStateVariable("sourceRef", "SECRET", "opaque source-system reference")
  self~registerStateVariable("authorityClass", "INTERNAL", "what kind of authority the element represents")
  self~registerStateVariable("recordedAt", "INTERNAL", "time reference was attached")
  self~registerStateVariable("visibilityClass", "INTERNAL", "minimum disclosure class")
  self~registerStateVariable("sealed", "INTERNAL", "element immutability")
::method addTag
  expose tags sealed
  use arg tagArg
  if sealed then return .false
  tag = .RelationshipCaseCanonical~token(tagArg)
  if tag = "" then return .false
  if \.RelationshipCaseCanonical~contains(tags, tag) then tags~append(tag)
  return .true
::method tags
  expose tags
  return .RelationshipCaseCanonical~copyArray(tags)
::method hasTag
  expose tags
  use arg tag
  return .RelationshipCaseCanonical~contains(tags, tag)
::method seal
  expose sealed
  sealed = .true
  return self
::method queuePersistentType
  return "relationship.case.element/1"
::method queuePersistentState
  expose elementId elementType semanticKind relationship sourceSystem sourceRef authorityClass recordedAt visibilityClass tags sealed
  if \sealed then raise syntax 88.930 array("Unsealed RelationshipCaseElement cannot cross durable boundary")
  state = .table~new
  state["elementId"] = elementId
  state["elementType"] = elementType
  state["semanticKind"] = semanticKind
  state["relationship"] = relationship
  state["sourceSystem"] = sourceSystem
  state["sourceRef"] = sourceRef
  state["authorityClass"] = authorityClass
  state["recordedAt"] = .RelationshipCasePersistenceValue~dateText(recordedAt)
  state["visibilityClass"] = visibilityClass
  state["tags"] = .RelationshipCaseCanonical~copyArray(tags)
  return state
::method queueRestoreState
  expose elementId elementType semanticKind relationship sourceSystem sourceRef authorityClass recordedAt visibilityClass tags sealed
  use arg state
  elementId = state["elementId"]~string
  elementType = .RelationshipCaseCanonical~token(state["elementType"])
  semanticKind = .RelationshipCaseCanonical~token(state["semanticKind"])
  relationship = .RelationshipCaseCanonical~token(state["relationship"])
  sourceSystem = .RelationshipCaseCanonical~token(state["sourceSystem"])
  sourceRef = state["sourceRef"]~string
  authorityClass = .RelationshipCaseCanonical~token(state["authorityClass"])
  recordedAt = .RelationshipCasePersistenceValue~dateValue(state["recordedAt"])
  visibilityClass = .RelationshipCaseCanonical~token(state["visibilityClass"])
  tags = .RelationshipCaseCanonical~copyArray(state["tags"])
  sealed = .true
  return self
::method pointId
  expose elementId
  return "RELATIONSHIP_CASE_ELEMENT:" || elementId
::method canonicalText
  expose elementId elementType semanticKind relationship sourceSystem sourceRef authorityClass recordedAt visibilityClass tags sealed
  if \sealed then raise syntax 88.903 array("RelationshipCaseElement must be sealed")
  text = "RELATIONSHIP-CASE-ELEMENT/1"
  text ||= .RelationshipCaseCanonical~field("ELEMENT_ID", elementId)
  text ||= .RelationshipCaseCanonical~field("ELEMENT_TYPE", elementType)
  text ||= .RelationshipCaseCanonical~field("SEMANTIC_KIND", semanticKind)
  text ||= .RelationshipCaseCanonical~field("RELATIONSHIP", relationship)
  text ||= .RelationshipCaseCanonical~field("SOURCE_SYSTEM", sourceSystem)
  text ||= .RelationshipCaseCanonical~field("SOURCE_REF", sourceRef)
  text ||= .RelationshipCaseCanonical~field("AUTHORITY_CLASS", authorityClass)
  text ||= .RelationshipCaseCanonical~field("RECORDED_AT", recordedAt)
  text ||= .RelationshipCaseCanonical~field("VISIBILITY", visibilityClass)
  sorted = self~tags; sorted~sort
  do tag over sorted; text ||= .RelationshipCaseCanonical~field("TAG", tag); end
  return text
::method semanticIdentity
  return self~canonicalText

::class RelationshipCaseEvent subclass RelationshipCaseAlchemyObject public
::attribute eventId get
::attribute eventType get
::attribute caseId get
::attribute actorId get
::attribute actorRole get
::attribute occurredAt get
::attribute fromState get
::attribute toState get
::attribute elementId get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute decisionCode get
::attribute detail get
::attribute sealed get
::method init
  expose eventId eventType caseId actorId actorRole occurredAt fromState toState elementId policyId policyVersion policyIdentity decisionCode detail sealed
  use arg eventIdArg, eventTypeArg, caseIdArg, actorIdArg, actorRoleArg, occurredAtArg, fromStateArg = "", toStateArg = "", elementIdArg = "", policyIdArg = "", policyVersionArg = "", policyIdentityArg = "", decisionCodeArg = "", detailArg = "", contextArg = .nil
  self~initDomainAlchemy("RELATIONSHIPCASEEVENT", contextArg)
  eventId = eventIdArg~string
  eventType = .RelationshipCaseCanonical~token(eventTypeArg)
  caseId = caseIdArg~string
  actorId = actorIdArg~string
  actorRole = .RelationshipCaseCanonical~token(actorRoleArg)
  occurredAt = occurredAtArg
  fromState = .RelationshipCaseCanonical~token(fromStateArg)
  toState = .RelationshipCaseCanonical~token(toStateArg)
  elementId = elementIdArg~string
  policyId = .RelationshipCaseCanonical~token(policyIdArg)
  policyVersion = policyVersionArg~string
  policyIdentity = policyIdentityArg~string
  decisionCode = .RelationshipCaseCanonical~token(decisionCodeArg)
  detail = detailArg~string
  sealed = .false
  if eventId = "" | eventType = "" | caseId = "" | actorId = "" | actorRole = "" | occurredAt == .nil then raise syntax 88.904 array("RelationshipCaseEvent identity fields required")
  self~registerStateVariable("eventId", "INTERNAL", "event identity")
  self~registerStateVariable("eventType", "INTERNAL", "event type")
  self~registerStateVariable("caseId", "CUSTOMER", "case identity")
  self~registerStateVariable("actorId", "SECRET", "actor reference")
  self~registerStateVariable("actorRole", "INTERNAL", "actor role")
  self~registerStateVariable("occurredAt", "INTERNAL", "event time")
  self~registerStateVariable("policyIdentity", "INTERNAL", "exact policy release evidence")
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose eventId eventType caseId actorId actorRole occurredAt fromState toState elementId policyId policyVersion policyIdentity decisionCode detail sealed
  if \sealed then raise syntax 88.905 array("RelationshipCaseEvent must be sealed")
  text = "RELATIONSHIP-CASE-EVENT/1"
  text ||= .RelationshipCaseCanonical~field("EVENT_ID", eventId)
  text ||= .RelationshipCaseCanonical~field("EVENT_TYPE", eventType)
  text ||= .RelationshipCaseCanonical~field("CASE_ID", caseId)
  text ||= .RelationshipCaseCanonical~field("ACTOR_ID", actorId)
  text ||= .RelationshipCaseCanonical~field("ACTOR_ROLE", actorRole)
  text ||= .RelationshipCaseCanonical~field("OCCURRED_AT", occurredAt)
  text ||= .RelationshipCaseCanonical~field("FROM_STATE", fromState)
  text ||= .RelationshipCaseCanonical~field("TO_STATE", toState)
  text ||= .RelationshipCaseCanonical~field("ELEMENT_ID", elementId)
  text ||= .RelationshipCaseCanonical~field("POLICY_ID", policyId)
  text ||= .RelationshipCaseCanonical~field("POLICY_VERSION", policyVersion)
  text ||= .RelationshipCaseCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .RelationshipCaseCanonical~field("DECISION_CODE", decisionCode)
  text ||= .RelationshipCaseCanonical~field("DETAIL", detail)
  return text

::method queuePersistentType
  return "relationship.case.event/1"
::method queuePersistentState
  expose eventId eventType caseId actorId actorRole occurredAt fromState toState elementId policyId policyVersion policyIdentity decisionCode detail sealed
  if \sealed then raise syntax 88.931 array("Unsealed RelationshipCaseEvent cannot cross durable boundary")
  state = .table~new
  state["eventId"] = eventId; state["eventType"] = eventType; state["caseId"] = caseId
  state["actorId"] = actorId; state["actorRole"] = actorRole
  state["occurredAt"] = .RelationshipCasePersistenceValue~dateText(occurredAt)
  state["fromState"] = fromState; state["toState"] = toState; state["elementId"] = elementId
  state["policyId"] = policyId; state["policyVersion"] = policyVersion; state["policyIdentity"] = policyIdentity
  state["decisionCode"] = decisionCode; state["detail"] = detail
  return state
::method queueRestoreState
  expose eventId eventType caseId actorId actorRole occurredAt fromState toState elementId policyId policyVersion policyIdentity decisionCode detail sealed
  use arg state
  eventId = state["eventId"]~string; eventType = .RelationshipCaseCanonical~token(state["eventType"]); caseId = state["caseId"]~string
  actorId = state["actorId"]~string; actorRole = .RelationshipCaseCanonical~token(state["actorRole"])
  occurredAt = .RelationshipCasePersistenceValue~dateValue(state["occurredAt"])
  fromState = .RelationshipCaseCanonical~token(state["fromState"]); toState = .RelationshipCaseCanonical~token(state["toState"]); elementId = state["elementId"]~string
  policyId = .RelationshipCaseCanonical~token(state["policyId"]); policyVersion = state["policyVersion"]~string; policyIdentity = state["policyIdentity"]~string
  decisionCode = .RelationshipCaseCanonical~token(state["decisionCode"]); detail = state["detail"]~string
  sealed = .true
  return self

::class RelationshipCaseOpenRequest public
::attribute caseId get
::attribute caseType get
::attribute actorId get
::attribute actorRole get
::attribute requestedAt get
::attribute ownerId get
::attribute ownerRole get
::method init
  expose caseId caseType actorId actorRole requestedAt ownerId ownerRole
  use arg caseIdArg, caseTypeArg, actorIdArg, actorRoleArg, requestedAtArg = .nil, ownerIdArg = "", ownerRoleArg = ""
  caseId = caseIdArg~string
  caseType = .RelationshipCaseCanonical~token(caseTypeArg)
  actorId = actorIdArg~string
  actorRole = .RelationshipCaseCanonical~token(actorRoleArg)
  if requestedAtArg == .nil then requestedAt = .DateTime~new
  else requestedAt = requestedAtArg
  ownerId = ownerIdArg~string
  ownerRole = .RelationshipCaseCanonical~token(ownerRoleArg)

::class RelationshipCaseCommand public
::attribute commandId get
::attribute action get
::attribute actorId get
::attribute actorRole get
::attribute requestedAt get
::method init
  expose commandId action actorId actorRole requestedAt
  use arg commandIdArg, actionArg, actorIdArg, actorRoleArg, requestedAtArg = .nil
  commandId = commandIdArg~string
  action = .RelationshipCaseCanonical~token(actionArg)
  actorId = actorIdArg~string
  actorRole = .RelationshipCaseCanonical~token(actorRoleArg)
  if requestedAtArg == .nil then requestedAt = .DateTime~new
  else requestedAt = requestedAtArg

::class RelationshipCaseOpenRule public
::attribute ruleId get
::attribute caseType get
::attribute actorRole get
::attribute initialState get
::attribute priority get
::attribute visibilityClass get
::attribute ownerRole get
::method init
  expose ruleId caseType actorRole initialState priority visibilityClass ownerRole
  use arg ruleIdArg, caseTypeArg = "*", actorRoleArg = "*", initialStateArg = "NEW", priorityArg = "NORMAL", visibilityArg = "INTERNAL", ownerRoleArg = ""
  ruleId = .RelationshipCaseCanonical~token(ruleIdArg)
  caseType = .RelationshipCaseCanonical~token(caseTypeArg)
  actorRole = .RelationshipCaseCanonical~token(actorRoleArg)
  initialState = .RelationshipCaseCanonical~token(initialStateArg)
  priority = .RelationshipCaseCanonical~token(priorityArg)
  visibilityClass = .RelationshipCaseCanonical~token(visibilityArg)
  ownerRole = .RelationshipCaseCanonical~token(ownerRoleArg)
::method matches
  use arg request
  if self~caseType <> "*" & self~caseType <> request~caseType then return .false
  if self~actorRole <> "*" & self~actorRole <> request~actorRole then return .false
  return .true
::method specificity
  score = 0
  if self~caseType <> "*" then score += 10
  if self~actorRole <> "*" then score += 5
  return score
::method canonicalText
  return self~ruleId || "|" || self~caseType || "|" || self~actorRole || "|" || self~initialState || "|" || self~priority || "|" || self~visibilityClass || "|" || self~ownerRole

::class RelationshipCaseElementRule public
::attribute ruleId get
::attribute caseType get
::attribute caseState get
::attribute elementType get
::attribute semanticKind get
::attribute actorRole get
::attribute allow get
::method init
  expose ruleId caseType caseState elementType semanticKind actorRole allow
  use arg ruleIdArg, caseTypeArg = "*", caseStateArg = "*", elementTypeArg = "*", semanticKindArg = "*", actorRoleArg = "*", allowArg = .true
  ruleId = .RelationshipCaseCanonical~token(ruleIdArg)
  caseType = .RelationshipCaseCanonical~token(caseTypeArg)
  caseState = .RelationshipCaseCanonical~token(caseStateArg)
  elementType = .RelationshipCaseCanonical~token(elementTypeArg)
  semanticKind = .RelationshipCaseCanonical~token(semanticKindArg)
  actorRole = .RelationshipCaseCanonical~token(actorRoleArg)
  allow = allowArg
::method matches
  use arg caseObject, element, role
  role = .RelationshipCaseCanonical~token(role)
  if self~caseType <> "*" & self~caseType <> caseObject~caseType then return .false
  if self~caseState <> "*" & self~caseState <> caseObject~state then return .false
  if self~elementType <> "*" & self~elementType <> element~elementType then return .false
  if self~semanticKind <> "*" & self~semanticKind <> element~semanticKind then return .false
  if self~actorRole <> "*" & self~actorRole <> role then return .false
  return .true
::method specificity
  score = 0
  if self~caseType <> "*" then score += 16
  if self~caseState <> "*" then score += 8
  if self~elementType <> "*" then score += 4
  if self~semanticKind <> "*" then score += 2
  if self~actorRole <> "*" then score += 1
  return score
::method canonicalText
  return self~ruleId || "|" || self~caseType || "|" || self~caseState || "|" || self~elementType || "|" || self~semanticKind || "|" || self~actorRole || "|" || self~allow

::class RelationshipCaseTransitionRule public
::attribute ruleId get
::attribute caseType get
::attribute fromState get
::attribute action get
::attribute toState get
::attribute actorRole get
::method init
  expose ruleId caseType fromState action toState actorRole requiredPairs
  use arg ruleIdArg, caseTypeArg = "*", fromStateArg = "*", actionArg, toStateArg, actorRoleArg = "*"
  ruleId = .RelationshipCaseCanonical~token(ruleIdArg)
  caseType = .RelationshipCaseCanonical~token(caseTypeArg)
  fromState = .RelationshipCaseCanonical~token(fromStateArg)
  action = .RelationshipCaseCanonical~token(actionArg)
  toState = .RelationshipCaseCanonical~token(toStateArg)
  actorRole = .RelationshipCaseCanonical~token(actorRoleArg)
  requiredPairs = .array~new
::method requireElement
  expose requiredPairs
  use arg elementTypeArg, semanticKindArg = "*"
  d = .directory~new
  d["elementType"] = .RelationshipCaseCanonical~token(elementTypeArg)
  d["semanticKind"] = .RelationshipCaseCanonical~token(semanticKindArg)
  requiredPairs~append(d)
  return self
::method requirements
  expose requiredPairs
  return .RelationshipCaseCanonical~copyArray(requiredPairs)
::method matches
  use arg caseObject, command
  if self~caseType <> "*" & self~caseType <> caseObject~caseType then return .false
  if self~fromState <> "*" & self~fromState <> caseObject~state then return .false
  if self~action <> command~action then return .false
  if self~actorRole <> "*" & self~actorRole <> command~actorRole then return .false
  return .true
::method specificity
  score = 0
  if self~caseType <> "*" then score += 8
  if self~fromState <> "*" then score += 4
  if self~actorRole <> "*" then score += 2
  return score
::method canonicalText
  expose requiredPairs
  text = self~ruleId || "|" || self~caseType || "|" || self~fromState || "|" || self~action || "|" || self~toState || "|" || self~actorRole
  reqs = .array~new
  do d over requiredPairs; reqs~append(d["elementType"] || ":" || d["semanticKind"]); end
  reqs~sort
  do req over reqs; text ||= "|REQ=" || req; end
  return text

::class RelationshipCaseProjectionRule public
::attribute ruleId get
::attribute caseType get
::attribute viewerRole get
::attribute maxVisibility get
::attribute hiddenCaseMode get
::method init
  expose ruleId caseType viewerRole maxVisibility hiddenCaseMode
  use arg ruleIdArg, caseTypeArg = "*", viewerRoleArg = "*", maxVisibilityArg = "INTERNAL", hiddenCaseModeArg = "SHELL"
  ruleId = .RelationshipCaseCanonical~token(ruleIdArg)
  caseType = .RelationshipCaseCanonical~token(caseTypeArg)
  viewerRole = .RelationshipCaseCanonical~token(viewerRoleArg)
  maxVisibility = .RelationshipCaseCanonical~token(maxVisibilityArg)
  hiddenCaseMode = .RelationshipCaseCanonical~token(hiddenCaseModeArg)
::method matches
  use arg caseObject, roleArg
  role = .RelationshipCaseCanonical~token(roleArg)
  if self~caseType <> "*" & self~caseType <> caseObject~caseType then return .false
  if self~viewerRole <> "*" & self~viewerRole <> role then return .false
  return .true
::method specificity
  score = 0
  if self~caseType <> "*" then score += 2
  if self~viewerRole <> "*" then score += 1
  return score
::method canonicalText
  return self~ruleId || "|" || self~caseType || "|" || self~viewerRole || "|" || self~maxVisibility || "|" || self~hiddenCaseMode

::class RelationshipCasePolicyDecision public
::attribute allowed get
::attribute code get
::attribute ruleId get
::attribute targetState get
::attribute priority get
::attribute visibilityClass get
::attribute ownerRole get
::attribute detail get
::method init
  expose allowed code ruleId targetState priority visibilityClass ownerRole detail
  use arg allowedArg, codeArg, ruleIdArg = "", targetStateArg = "", priorityArg = "", visibilityArg = "", ownerRoleArg = "", detailArg = ""
  allowed = allowedArg
  code = .RelationshipCaseCanonical~token(codeArg)
  ruleId = .RelationshipCaseCanonical~token(ruleIdArg)
  targetState = .RelationshipCaseCanonical~token(targetStateArg)
  priority = .RelationshipCaseCanonical~token(priorityArg)
  visibilityClass = .RelationshipCaseCanonical~token(visibilityArg)
  ownerRole = .RelationshipCaseCanonical~token(ownerRoleArg)
  detail = detailArg~string

::class RelationshipCasePolicy public
::attribute sealed get
::method init
  expose openRules elementRules transitionRules projectionRules sealed
  openRules = .array~new
  elementRules = .array~new
  transitionRules = .array~new
  projectionRules = .array~new
  sealed = .false
::method addOpenRule
  expose openRules sealed
  use arg rule
  if sealed | rule == .nil then return .false
  openRules~append(rule); return .true
::method addElementRule
  expose elementRules sealed
  use arg rule
  if sealed | rule == .nil then return .false
  elementRules~append(rule); return .true
::method addTransitionRule
  expose transitionRules sealed
  use arg rule
  if sealed | rule == .nil then return .false
  transitionRules~append(rule); return .true
::method addProjectionRule
  expose projectionRules sealed
  use arg rule
  if sealed | rule == .nil then return .false
  projectionRules~append(rule); return .true
::method seal
  expose sealed
  sealed = .true
  return self
::method publicationEligible
  expose sealed openRules transitionRules projectionRules
  return sealed & openRules~items > 0 & transitionRules~items > 0 & projectionRules~items > 0
::method selectRule private
  use arg rules, mode, a, b = .nil
  best = .nil; bestScore = -1
  do rule over rules
    select
      when mode = "OPEN" then matched = rule~matches(a)
      when mode = "ELEMENT" then matched = rule~matches(a, b["element"], b["role"])
      when mode = "TRANSITION" then matched = rule~matches(a, b)
      when mode = "PROJECTION" then matched = rule~matches(a, b)
      otherwise matched = .false
    end
    if matched then do
      score = rule~specificity
      if score > bestScore then do; best = rule; bestScore = score; end
      else if score = bestScore then if best <> .nil then if rule~ruleId < best~ruleId then best = rule
    end
  end
  return best
::method decideOpen
  expose openRules sealed
  use arg request
  if \sealed then return .RelationshipCaseResult~failure("CASE_POLICY_NOT_SEALED")
  rule = self~selectRule(openRules, "OPEN", request)
  if rule == .nil then return .RelationshipCaseResult~failure("CASE_OPEN_NO_RULE", request~caseType || "/" || request~actorRole)
  d = .RelationshipCasePolicyDecision~new(.true, "OPEN_ALLOWED", rule~ruleId, rule~initialState, rule~priority, rule~visibilityClass, rule~ownerRole)
  return .RelationshipCaseResult~success(d)
::method decideElement
  expose elementRules sealed
  use arg caseObject, element, actorRole
  if \sealed then return .RelationshipCaseResult~failure("CASE_POLICY_NOT_SEALED")
  args = .directory~new; args["element"] = element; args["role"] = actorRole
  rule = self~selectRule(elementRules, "ELEMENT", caseObject, args)
  if rule == .nil then return .RelationshipCaseResult~failure("CASE_ELEMENT_NO_RULE", element~elementType || "/" || element~semanticKind)
  if \rule~allow then return .RelationshipCaseResult~failure("CASE_ELEMENT_DENIED", rule~ruleId)
  return .RelationshipCaseResult~success(.RelationshipCasePolicyDecision~new(.true, "ELEMENT_ALLOWED", rule~ruleId))
::method decideTransition
  expose transitionRules sealed
  use arg caseObject, command
  if \sealed then return .RelationshipCaseResult~failure("CASE_POLICY_NOT_SEALED")
  rule = self~selectRule(transitionRules, "TRANSITION", caseObject, command)
  if rule == .nil then return .RelationshipCaseResult~failure("CASE_TRANSITION_NO_RULE", caseObject~caseType || "/" || caseObject~state || "/" || command~action || "/" || command~actorRole)
  do req over rule~requirements
    if \caseObject~hasElement(req["elementType"], req["semanticKind"]) then return .RelationshipCaseResult~failure("CASE_TRANSITION_REQUIREMENT_MISSING", rule~ruleId || ":" || req["elementType"] || ":" || req["semanticKind"])
  end
  return .RelationshipCaseResult~success(.RelationshipCasePolicyDecision~new(.true, "TRANSITION_ALLOWED", rule~ruleId, rule~toState))
::method decideProjection
  expose projectionRules sealed
  use arg caseObject, viewerRole
  if \sealed then return .RelationshipCaseResult~failure("CASE_POLICY_NOT_SEALED")
  rule = self~selectRule(projectionRules, "PROJECTION", caseObject, viewerRole)
  if rule == .nil then return .RelationshipCaseResult~failure("CASE_PROJECTION_NO_RULE", caseObject~caseType || "/" || viewerRole~string)
  d = .directory~new
  d["ruleId"] = rule~ruleId
  d["maxVisibility"] = rule~maxVisibility
  d["hiddenCaseMode"] = rule~hiddenCaseMode
  return .RelationshipCaseResult~success(d)
::method canonicalText
  expose openRules elementRules transitionRules projectionRules sealed
  if \sealed then raise syntax 88.906 array("RelationshipCasePolicy must be sealed")
  text = "RELATIONSHIP-CASE-POLICY/1|SEALED=1"
  collections = .array~of(openRules, elementRules, transitionRules, projectionRules)
  labels = .array~of("OPEN", "ELEMENT", "TRANSITION", "PROJECTION")
  do i = 1 to collections~items
    rows = .array~new
    do rule over collections[i]; rows~append(rule~canonicalText); end
    rows~sort
    do row over rows; text ||= "|" || labels[i] || "=" || row; end
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class RelationshipCase subclass RelationshipCaseAlchemyObject public
::attribute caseId get
::attribute caseType get
::attribute state get
::attribute openedAt get
::attribute updatedAt get
::attribute priority get
::attribute visibilityClass get
::attribute ownerId get
::attribute ownerRole get
::attribute revision get
::method init
  expose caseId caseType state openedAt updatedAt priority visibilityClass ownerId ownerRole revision elements events
  use arg caseIdArg, caseTypeArg, stateArg, openedAtArg, priorityArg, visibilityArg, ownerIdArg = "", ownerRoleArg = "", contextArg = .nil
  self~initDomainAlchemy("RELATIONSHIPCASE", contextArg)
  caseId = caseIdArg~string
  caseType = .RelationshipCaseCanonical~token(caseTypeArg)
  state = .RelationshipCaseCanonical~token(stateArg)
  openedAt = openedAtArg
  updatedAt = openedAtArg
  priority = .RelationshipCaseCanonical~token(priorityArg)
  visibilityClass = .RelationshipCaseCanonical~token(visibilityArg)
  ownerId = ownerIdArg~string
  ownerRole = .RelationshipCaseCanonical~token(ownerRoleArg)
  revision = 0
  elements = .array~new
  events = .array~new
  if caseId = "" | caseType = "" | state = "" | openedAt == .nil then raise syntax 88.907 array("RelationshipCase identity fields required")
  self~registerStateVariable("caseId", "CUSTOMER", "case identity")
  self~registerStateVariable("caseType", "INTERNAL", "case classification")
  self~registerStateVariable("state", "INTERNAL", "policy-controlled case state")
  self~registerStateVariable("openedAt", "INTERNAL", "case opening time")
  self~registerStateVariable("updatedAt", "INTERNAL", "last mutation time")
  self~registerStateVariable("priority", "INTERNAL", "work priority")
  self~registerStateVariable("visibilityClass", "INTERNAL", "case-level information classification")
  self~registerStateVariable("ownerId", "SECRET", "case owner identity")
  self~registerStateVariable("ownerRole", "INTERNAL", "case owner role")
  self~registerStateVariable("revision", "INTERNAL", "monotonic case revision")
::method elements
  expose elements
  return .RelationshipCaseCanonical~copyArray(elements)
::method events
  expose events
  return .RelationshipCaseCanonical~copyArray(events)
::method hasElement
  expose elements
  use arg elementTypeArg, semanticKindArg = "*"
  et = .RelationshipCaseCanonical~token(elementTypeArg)
  sk = .RelationshipCaseCanonical~token(semanticKindArg)
  do element over elements
    if (et = "*" | element~elementType = et) & (sk = "*" | element~semanticKind = sk) then return .true
  end
  return .false
::method elementById
  expose elements
  use arg id
  do element over elements
    if element~elementId = id~string then return element
  end
  return .nil
::method appendElement package
  expose elements revision updatedAt
  use arg element, atTime
  if element == .nil then return .RelationshipCaseResult~failure("CASE_ELEMENT_REQUIRED")
  if \element~sealed then return .RelationshipCaseResult~failure("CASE_ELEMENT_NOT_SEALED", element~elementId)
  if self~elementById(element~elementId) <> .nil then return .RelationshipCaseResult~failure("CASE_ELEMENT_DUPLICATE", element~elementId)
  elements~append(element)
  revision += 1
  updatedAt = atTime
  self~recordRelationship("REFERENCES", element, element~elementType || ":" || element~semanticKind, "INTERNAL")
  return .RelationshipCaseResult~success(element)
::method appendEvent package
  expose events
  use arg event
  do existing over events
    if existing~eventId = event~eventId then return .RelationshipCaseResult~failure("CASE_EVENT_DUPLICATE", event~eventId)
  end
  events~append(event)
  return .RelationshipCaseResult~success(event)
::method applyState package
  expose state revision updatedAt
  use arg newState, atTime
  state = .RelationshipCaseCanonical~token(newState)
  updatedAt = atTime
  revision += 1
  return state
::method setOwner package
  expose ownerId ownerRole revision updatedAt
  use arg id, role, atTime
  ownerId = id~string
  ownerRole = .RelationshipCaseCanonical~token(role)
  updatedAt = atTime
  revision += 1
  return ownerId

::method queuePersistentType
  return "relationship.case.case/1"
::method queuePersistentState
  expose caseId caseType state openedAt updatedAt priority visibilityClass ownerId ownerRole revision elements events
  data = .table~new
  data["caseId"] = caseId; data["caseType"] = caseType; data["state"] = state
  data["openedAt"] = .RelationshipCasePersistenceValue~dateText(openedAt)
  data["updatedAt"] = .RelationshipCasePersistenceValue~dateText(updatedAt)
  data["priority"] = priority; data["visibilityClass"] = visibilityClass
  data["ownerId"] = ownerId; data["ownerRole"] = ownerRole; data["revision"] = revision~string
  data["elements"] = .RelationshipCaseCanonical~copyArray(elements)
  data["events"] = .RelationshipCaseCanonical~copyArray(events)
  return data
::method queueRestoreState
  expose caseId caseType state openedAt updatedAt priority visibilityClass ownerId ownerRole revision elements events
  use arg data
  caseId = data["caseId"]~string; caseType = .RelationshipCaseCanonical~token(data["caseType"]); state = .RelationshipCaseCanonical~token(data["state"])
  openedAt = .RelationshipCasePersistenceValue~dateValue(data["openedAt"]); updatedAt = .RelationshipCasePersistenceValue~dateValue(data["updatedAt"])
  priority = .RelationshipCaseCanonical~token(data["priority"]); visibilityClass = .RelationshipCaseCanonical~token(data["visibilityClass"])
  ownerId = data["ownerId"]~string; ownerRole = .RelationshipCaseCanonical~token(data["ownerRole"]); revision = data["revision"] + 0
  elements = .RelationshipCaseCanonical~copyArray(data["elements"]); events = .RelationshipCaseCanonical~copyArray(data["events"])
  return self

::class RelationshipCaseProjection public
::attribute caseId get
::attribute caseType get
::attribute state get
::attribute priority get
::attribute ownerRole get
::attribute shellOnly get
::attribute policyRuleId get
::method init
  expose caseId caseType state priority ownerRole shellOnly policyRuleId elements
  use arg caseObject, shellArg, ruleIdArg
  caseId = caseObject~caseId
  shellOnly = shellArg
  policyRuleId = ruleIdArg~string
  if shellOnly then do
    caseType = "RESTRICTED_CASE"
    state = "RESTRICTED"
    priority = ""
    ownerRole = ""
  end
  else do
    caseType = caseObject~caseType
    state = caseObject~state
    priority = caseObject~priority
    ownerRole = caseObject~ownerRole
  end
  elements = .array~new
::method addElement package
  expose elements
  use arg element
  elements~append(element)
::method elements
  expose elements
  return .RelationshipCaseCanonical~copyArray(elements)

::class RelationshipCaseRepository public
::method init
  expose byId subjectIndex
  byId = .directory~new
  subjectIndex = .directory~new
::method add
  expose byId
  use arg caseObject
  if caseObject == .nil then return .RelationshipCaseResult~failure("CASE_REQUIRED")
  if byId~hasIndex(caseObject~caseId) then return .RelationshipCaseResult~failure("CASE_DUPLICATE", caseObject~caseId)
  byId[caseObject~caseId] = caseObject
  self~reindex(caseObject)
  return .RelationshipCaseResult~success(caseObject)
::method get
  expose byId
  use arg caseId
  if byId~hasIndex(caseId~string) then return .RelationshipCaseResult~success(byId[caseId~string])
  return .RelationshipCaseResult~failure("CASE_NOT_FOUND", caseId)
::method reindex
  expose subjectIndex
  use arg caseObject
  do element over caseObject~elements
    if element~elementType = "SUBJECT" then do
      key = element~sourceSystem || "|" || element~sourceRef
      if subjectIndex~hasIndex(key) = .false then subjectIndex[key] = .directory~new
      subjectIndex[key][caseObject~caseId] = caseObject
    end
  end
  return .true
::method casesForSubject
  expose subjectIndex
  use arg sourceSystem, sourceRef
  key = .RelationshipCaseCanonical~token(sourceSystem) || "|" || sourceRef~string
  out = .array~new
  if subjectIndex~hasIndex(key) = .false then return out
  ids = subjectIndex[key]~allIndexes
  ids~sort
  do id over ids; out~append(subjectIndex[key][id]); end
  return out

::class RelationshipCasePolicyGate public
::method init
  expose catalog policyId deploymentPoint
  use arg catalogArg, policyIdArg = .nil, deploymentPointArg = .nil
  if catalogArg == .nil then raise syntax 88.908 array("RelationshipCasePolicyGate catalog required")
  catalog = catalogArg
  if policyIdArg == .nil then policyId = .RelationshipCaseBuild~DEFAULT_POLICY_ID
  else policyId = .RelationshipCaseCanonical~token(policyIdArg)
  deploymentPoint = deploymentPointArg
::method resolve
  expose catalog policyId deploymentPoint
  use arg atTime
  if deploymentPoint <> .nil & catalog~hasMethod("RESOLVEFORCONTEXT") then resolved = catalog~resolveForContext(policyId, deploymentPoint, atTime)
  else resolved = catalog~resolve(policyId, atTime)
  if resolved~ok = .false then return .RelationshipCaseResult~failure("CASE_POLICY_RESOLUTION_FAILED", resolved~code || ":" || resolved~detail, resolved)
  release = resolved~value
  if release~payload == .nil then return .RelationshipCaseResult~failure("CASE_POLICY_PAYLOAD_REQUIRED")
  d = .directory~new
  d["release"] = release
  d["policy"] = release~payload
  return .RelationshipCaseResult~success(d)

::class RelationshipCaseEngine subclass RelationshipCaseAlchemyObject public
::method init
  expose gate repository
  use arg policyCatalog, policyId = .nil, repositoryArg = .nil, deploymentPoint = .nil, contextArg = .nil
  self~initDomainAlchemy("RELATIONSHIPCASEENGINE", contextArg)
  gate = .RelationshipCasePolicyGate~new(policyCatalog, policyId, deploymentPoint)
  if repositoryArg == .nil then repository = .RelationshipCaseRepository~new
  else repository = repositoryArg
::method repository
  expose repository
  return repository
::method nextEventId private
  expose repository
  use arg caseId, eventType
  rr = repository~get(caseId)
  if rr~ok then sequence = rr~value~events~items + 1
  else sequence = 1
  return caseId || ":EV:" || sequence || ":" || eventType
::method policyEvidence private
  use arg resolved
  d = .directory~new
  release = resolved["release"]
  d["policyId"] = release~policyId
  d["policyVersion"] = release~version
  d["policyIdentity"] = release~semanticIdentity
  return d
::method openCase
  expose gate repository
  use arg request
  if request == .nil then return .RelationshipCaseResult~failure("CASE_OPEN_REQUEST_REQUIRED")
  if request~caseId = "" | request~caseType = "" | request~actorId = "" | request~actorRole = "" then return .RelationshipCaseResult~failure("CASE_OPEN_REQUEST_INVALID")
  if repository~get(request~caseId)~ok then return .RelationshipCaseResult~failure("CASE_DUPLICATE", request~caseId)
  rr = gate~resolve(request~requestedAt)
  if rr~ok = .false then return rr
  resolved = rr~value; policy = resolved["policy"]
  pd = policy~decideOpen(request)
  if pd~ok = .false then return pd
  decision = pd~value
  ownerId = request~ownerId
  ownerRole = request~ownerRole
  if ownerRole = "" then ownerRole = decision~ownerRole
  if ownerId = "" & ownerRole = request~actorRole then ownerId = request~actorId
  caseObject = .RelationshipCase~new(request~caseId, request~caseType, decision~targetState, request~requestedAt, decision~priority, decision~visibilityClass, ownerId, ownerRole)
  evidence = self~policyEvidence(resolved)
  ev = .RelationshipCaseEvent~new(self~nextEventId(caseObject~caseId, "OPENED"), "OPENED", caseObject~caseId, request~actorId, request~actorRole, request~requestedAt, "", caseObject~state, "", evidence["policyId"], evidence["policyVersion"], evidence["policyIdentity"], decision~code, decision~ruleId)~seal
  caseObject~appendEvent(ev)
  add = repository~add(caseObject)
  if add~ok = .false then return add
  return .RelationshipCaseResult~success(caseObject)
::method attachElement
  expose gate repository
  use arg caseObject, element, actorId, actorRole, atTime = .nil
  if caseObject == .nil | element == .nil then return .RelationshipCaseResult~failure("CASE_AND_ELEMENT_REQUIRED")
  if atTime == .nil then atTime = .DateTime~new
  if actorId~string = "" | actorRole~string = "" then return .RelationshipCaseResult~failure("CASE_ACTOR_REQUIRED")
  if \element~sealed then return .RelationshipCaseResult~failure("CASE_ELEMENT_NOT_SEALED", element~elementId)
  rr = gate~resolve(atTime)
  if rr~ok = .false then return rr
  resolved = rr~value; policy = resolved["policy"]
  pd = policy~decideElement(caseObject, element, actorRole)
  if pd~ok = .false then return pd
  appended = caseObject~appendElement(element, atTime)
  if appended~ok = .false then return appended
  evidence = self~policyEvidence(resolved)
  decision = pd~value
  ev = .RelationshipCaseEvent~new(self~nextEventId(caseObject~caseId, "ELEMENT_ATTACHED"), "ELEMENT_ATTACHED", caseObject~caseId, actorId, actorRole, atTime, caseObject~state, caseObject~state, element~elementId, evidence["policyId"], evidence["policyVersion"], evidence["policyIdentity"], decision~code, decision~ruleId)~seal
  caseObject~appendEvent(ev)
  repository~reindex(caseObject)
  return .RelationshipCaseResult~success(element)
::method transition
  expose gate
  use arg caseObject, command
  if caseObject == .nil | command == .nil then return .RelationshipCaseResult~failure("CASE_AND_COMMAND_REQUIRED")
  rr = gate~resolve(command~requestedAt)
  if rr~ok = .false then return rr
  resolved = rr~value; policy = resolved["policy"]
  pd = policy~decideTransition(caseObject, command)
  if pd~ok = .false then return pd
  decision = pd~value
  fromState = caseObject~state
  caseObject~applyState(decision~targetState, command~requestedAt)
  evidence = self~policyEvidence(resolved)
  ev = .RelationshipCaseEvent~new(self~nextEventId(caseObject~caseId, "STATE_CHANGED"), "STATE_CHANGED", caseObject~caseId, command~actorId, command~actorRole, command~requestedAt, fromState, caseObject~state, "", evidence["policyId"], evidence["policyVersion"], evidence["policyIdentity"], decision~code, decision~ruleId)~seal
  caseObject~appendEvent(ev)
  return .RelationshipCaseResult~success(caseObject)
::method project
  expose gate
  use arg caseObject, viewerRole, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  rr = gate~resolve(atTime)
  if rr~ok = .false then return rr
  resolved = rr~value; policy = resolved["policy"]
  pd = policy~decideProjection(caseObject, viewerRole)
  if pd~ok = .false then return pd
  p = pd~value
  maxRank = .RelationshipCaseCanonical~visibilityRank(p["maxVisibility"])
  caseRank = .RelationshipCaseCanonical~visibilityRank(caseObject~visibilityClass)
  shell = .false
  if caseRank > maxRank then do
    if p["hiddenCaseMode"] = "HIDE" then return .RelationshipCaseResult~failure("CASE_NOT_VISIBLE")
    shell = .true
  end
  projection = .RelationshipCaseProjection~new(caseObject, shell, p["ruleId"])
  if \shell then do element over caseObject~elements
    if .RelationshipCaseCanonical~visibilityRank(element~visibilityClass) <= maxRank then projection~addElement(element)
  end
  return .RelationshipCaseResult~success(projection)

::requires "AlchemyObject.cls"
