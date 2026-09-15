/* SecurityEffect.cls - Security Effect / "Bouncer" v0.14 */

::class SecurityEffectBuild public
::constant RELEASE "0.14"
::constant API_VERSION "security.effect/0.14"
::constant POLICY_SCHEMA "security.policy/0.5"
::constant DECISION_MODE "DETERMINISTIC_POLICY_ONLY"
::constant REVIEW_REFERRAL_SCHEMA "security.review.referral/0.1"
::constant INVOCATION_BINDING_SCHEMA "security.invocation.binding/0.1"
::constant INVOCATION_POLICY_SCHEMA "security.invocation.policy/0.1"
::constant CONTINUATION_POLICY_SCHEMA "security.continuation.policy/0.1"
::constant CONTINUATION_BINDING_SCHEMA "security.continuation.binding/0.1"

::class SecurityConstant public
::constant FINDING_CONCERN "CONCERN"
::constant FINDING_SUPPORT "SUPPORT"
::constant FINDING_UNKNOWN "UNKNOWN"
::constant DISP_ALLOW "ALLOW"
::constant DISP_CAUTION "CAUTION"
::constant DISP_REVIEW "REVIEW_REQUIRED"
::constant DISP_HOLD "HOLD"
::constant DISP_REJECT "REJECT"

::class SecurityResult public
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

::class SecurityCanonical public
::method field class
  use arg name, value
  if value == .nil then value = "<NIL>"
  return name~string~upper || "=" || value~string || '0a'x
::method copyArray class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item)
  end
  return out
::method copyTable class
  use arg source
  out = .directory~new
  if source == .nil then return out
  do key over source
    out[key] = source[key]
  end
  return out
::method sortedStrings class
  use arg source
  out = self~copyArray(source)
  out~sort
  return out
::method join class
  use arg label, values
  text = ""
  sorted = self~sortedStrings(values)
  do value over sorted
    text ||= self~field(label, value)
  end
  return text
::method hash class
  use arg text
  return .SHA256~new(text~string)~digest
::method containsString class
  use arg values, wanted
  wanted = wanted~string~upper
  do value over values
    if value~string~upper == wanted then return .true
  end
  return .false
::method timeSpanSeconds class
  use arg totalSeconds
  total = totalSeconds + 0
  if total < 0 then total = 0
  days = total % 86400
  rem = total // 86400
  hours = rem % 3600
  rem = rem // 3600
  minutes = rem % 60
  seconds = rem // 60
  return .TimeSpan~new(days, hours, minutes, seconds, 0)

::class SecurityEvidenceAnchor public
::attribute sourceId get
::attribute sourceKind get
::attribute locator get
::attribute observedAt get
::attribute confidence get
::attribute sourceObject get
::method init
  expose sourceId sourceKind locator observedAt confidence sourceObject
  use arg sourceIdArg, sourceKindArg, locatorArg = "", observedAtArg = .nil, confidenceArg = 100, sourceObjectArg = .nil
  sourceId = sourceIdArg~string
  sourceKind = sourceKindArg~string~upper
  locator = locatorArg~string
  if observedAtArg == .nil then observedAt = .DateTime~new
  else observedAt = observedAtArg
  confidence = confidenceArg + 0
  sourceObject = sourceObjectArg
::method canonicalText
  expose sourceId sourceKind locator observedAt confidence
  text = .SecurityCanonical~field("SOURCE_ID", sourceId)
  text ||= .SecurityCanonical~field("SOURCE_KIND", sourceKind)
  text ||= .SecurityCanonical~field("LOCATOR", locator)
  text ||= .SecurityCanonical~field("OBSERVED_AT", observedAt)
  text ||= .SecurityCanonical~field("CONFIDENCE", confidence)
  return text

::class SecurityObservation public
::attribute observationId get
::attribute observationKind get
::attribute subjectKind get
::attribute subjectId get
::attribute accessPointId get
::attribute occurredAt get
::attribute recordedAt get
::attribute confidence get
::attribute detail get
::attribute sealed get
::method init
  expose observationId observationKind subjectKind subjectId accessPointId occurredAt recordedAt confidence detail sealed evidence metadata
  use arg observationIdArg, observationKindArg, subjectKindArg, subjectIdArg, accessPointIdArg = "", occurredAtArg = .nil, confidenceArg = 100, detailArg = ""
  observationId = observationIdArg~string
  observationKind = observationKindArg~string~upper
  subjectKind = subjectKindArg~string~upper
  subjectId = subjectIdArg~string
  accessPointId = accessPointIdArg~string
  if occurredAtArg == .nil then occurredAt = .DateTime~new
  else occurredAt = occurredAtArg
  recordedAt = .DateTime~new
  confidence = confidenceArg + 0
  detail = detailArg~string
  sealed = .false
  evidence = .array~new
  metadata = .directory~new
::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .false
  if anchor == .nil then return .false
  evidence~append(anchor)
  return .true
::method putMetadata
  expose metadata sealed
  use arg name, value
  if sealed then return .false
  metadata[name~string~upper] = value
  return .true
::method metadataValue
  expose metadata
  use arg name
  key = name~string~upper
  if metadata~hasIndex(key) then return metadata[key]
  return .nil
::method evidence
  expose evidence
  return .SecurityCanonical~copyArray(evidence)
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose observationId observationKind subjectKind subjectId accessPointId occurredAt confidence detail evidence metadata
  text = .SecurityCanonical~field("OBSERVATION", observationId)
  text ||= .SecurityCanonical~field("KIND", observationKind)
  text ||= .SecurityCanonical~field("SUBJECT_KIND", subjectKind)
  text ||= .SecurityCanonical~field("SUBJECT_ID", subjectId)
  text ||= .SecurityCanonical~field("ACCESS_POINT", accessPointId)
  text ||= .SecurityCanonical~field("OCCURRED_AT", occurredAt)
  text ||= .SecurityCanonical~field("CONFIDENCE", confidence)
  text ||= .SecurityCanonical~field("DETAIL", detail)
  pairs = .array~new
  do key over metadata
    pairs~append(key~string~upper || "=" || metadata[key]~string)
  end
  text ||= .SecurityCanonical~join("META", pairs)
  ev = .array~new
  do anchor over evidence
    ev~append(anchor~canonicalText)
  end
  text ||= .SecurityCanonical~join("EVIDENCE", ev)
  return text

::class SecurityFinding public
::attribute findingId get
::attribute findingKind get
::attribute findingState get
::attribute subjectId get
::attribute confidence get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute detail get
::attribute sourceDomain get
::attribute sealed get
::method init
  expose findingId findingKind findingState subjectId confidence effectiveFrom effectiveUntil detail sourceDomain sealed evidence counterEvidence observationRefs
  use arg findingIdArg, findingKindArg, findingStateArg, subjectIdArg, confidenceArg = 100, effectiveFromArg = .nil, effectiveUntilArg = .nil, detailArg = "", sourceDomainArg = "SECURITY_EFFECT"
  findingId = findingIdArg~string
  findingKind = findingKindArg~string~upper
  findingState = findingStateArg~string~upper
  subjectId = subjectIdArg~string
  confidence = confidenceArg + 0
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new
  else effectiveFrom = effectiveFromArg
  effectiveUntil = effectiveUntilArg
  detail = detailArg~string
  sourceDomain = sourceDomainArg~string~upper
  sealed = .false
  evidence = .array~new
  counterEvidence = .array~new
  observationRefs = .array~new
::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .false
  if anchor == .nil then return .false
  evidence~append(anchor)
  return .true
::method addCounterEvidence
  expose counterEvidence sealed
  use arg anchor
  if sealed then return .false
  if anchor == .nil then return .false
  counterEvidence~append(anchor)
  return .true
::method addObservationRef
  expose observationRefs sealed
  use arg observationId
  if sealed then return .false
  observationRefs~append(observationId~string)
  return .true
::method evidence
  expose evidence
  return .SecurityCanonical~copyArray(evidence)
::method counterEvidence
  expose counterEvidence
  return .SecurityCanonical~copyArray(counterEvidence)
::method observationRefs
  expose observationRefs
  return .SecurityCanonical~copyArray(observationRefs)
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  if moment > effectiveUntil then return .false
  return .true
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose findingId findingKind findingState subjectId confidence effectiveFrom effectiveUntil detail sourceDomain evidence counterEvidence observationRefs
  text = .SecurityCanonical~field("FINDING", findingId)
  text ||= .SecurityCanonical~field("KIND", findingKind)
  text ||= .SecurityCanonical~field("STATE", findingState)
  text ||= .SecurityCanonical~field("SUBJECT", subjectId)
  text ||= .SecurityCanonical~field("CONFIDENCE", confidence)
  text ||= .SecurityCanonical~field("FROM", effectiveFrom)
  text ||= .SecurityCanonical~field("UNTIL", effectiveUntil)
  text ||= .SecurityCanonical~field("DOMAIN", sourceDomain)
  text ||= .SecurityCanonical~field("DETAIL", detail)
  text ||= .SecurityCanonical~join("OBSERVATION_REF", observationRefs)
  ev = .array~new
  do anchor over evidence
    ev~append(anchor~canonicalText)
  end
  text ||= .SecurityCanonical~join("EVIDENCE", ev)
  ce = .array~new
  do anchor over counterEvidence
    ce~append(anchor~canonicalText)
  end
  text ||= .SecurityCanonical~join("COUNTER_EVIDENCE", ce)
  return text

::class SecuritySnapshot public
::attribute snapshotId get
::attribute subjectId get
::attribute capturedAt get
::attribute sealed get
::method init
  expose snapshotId subjectId capturedAt sealed observations findings
  use arg snapshotIdArg, subjectIdArg, capturedAtArg = .nil
  snapshotId = snapshotIdArg~string
  subjectId = subjectIdArg~string
  if capturedAtArg == .nil then capturedAt = .DateTime~new
  else capturedAt = capturedAtArg
  sealed = .false
  observations = .array~new
  findings = .array~new
::method addObservation
  expose observations sealed subjectId
  use arg observation
  if sealed then return .false
  if observation == .nil then return .false
  if observation~sealed = .false then return .false
  if observation~subjectId <> subjectId then return .false
  observations~append(observation)
  return .true
::method addFinding
  expose findings sealed subjectId
  use arg finding
  if sealed then return .false
  if finding == .nil then return .false
  if finding~sealed = .false then return .false
  if finding~subjectId <> subjectId then return .false
  findings~append(finding)
  return .true
::method observations
  expose observations
  return .SecurityCanonical~copyArray(observations)
::method findings
  expose findings
  return .SecurityCanonical~copyArray(findings)
::method hasFinding
  expose findings capturedAt
  use arg findingKind, state = ""
  wanted = findingKind~string~upper
  wantedState = state~string~upper
  do finding over findings
    if finding~findingKind == wanted & finding~activeAt(capturedAt) then do
      if wantedState = "" then return .true
      if finding~findingState == wantedState then return .true
    end
  end
  return .false
::method findingsOfKind
  expose findings capturedAt
  use arg findingKind
  wanted = findingKind~string~upper
  out = .array~new
  do finding over findings
    if finding~findingKind == wanted & finding~activeAt(capturedAt) then out~append(finding)
  end
  return out
::method observationCount
  expose observations
  use arg observationKinds
  count = 0
  do observation over observations
    if .SecurityCanonical~containsString(observationKinds, observation~observationKind) then count += 1
  end
  return count
::method hasObservationKind
  expose observations
  use arg wantedKind
  wanted = wantedKind~string~upper
  do observation over observations
    if observation~observationKind == wanted then return .true
  end
  return .false
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose snapshotId subjectId capturedAt observations findings
  text = .SecurityCanonical~field("SNAPSHOT", snapshotId)
  text ||= .SecurityCanonical~field("SUBJECT", subjectId)
  text ||= .SecurityCanonical~field("CAPTURED_AT", capturedAt)
  obs = .array~new
  do item over observations
    obs~append(item~canonicalText)
  end
  text ||= .SecurityCanonical~join("OBS", obs)
  fs = .array~new
  do item over findings
    fs~append(item~canonicalText)
  end
  text ||= .SecurityCanonical~join("FINDING", fs)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityActionSurface public
::attribute actionId get
::attribute subjectId get
::attribute actionType get
::attribute intendedAt get
::attribute consequenceClass get
::attribute capabilityId get
::attribute sealed get
::method init
  expose actionId subjectId actionType intendedAt consequenceClass capabilityId sealed attributes
  use arg actionIdArg, subjectIdArg, actionTypeArg, intendedAtArg = .nil, consequenceClassArg = "NORMAL", capabilityIdArg = ""
  actionId = actionIdArg~string
  subjectId = subjectIdArg~string
  actionType = actionTypeArg~string~upper
  if intendedAtArg == .nil then intendedAt = .DateTime~new
  else intendedAt = intendedAtArg
  consequenceClass = consequenceClassArg~string~upper
  capabilityId = capabilityIdArg~string~upper
  sealed = .false
  attributes = .directory~new
::method putAttribute
  expose attributes sealed
  use arg name, value
  if sealed then return .false
  attributes[name~string~upper] = value
  return .true
::method attribute
  expose attributes
  use arg name
  key = name~string~upper
  if attributes~hasIndex(key) then return attributes[key]
  return .nil
::method attributes
  expose attributes
  return .SecurityCanonical~copyTable(attributes)
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose actionId subjectId actionType intendedAt consequenceClass capabilityId attributes
  text = .SecurityCanonical~field("ACTION", actionId)
  text ||= .SecurityCanonical~field("SUBJECT", subjectId)
  text ||= .SecurityCanonical~field("TYPE", actionType)
  text ||= .SecurityCanonical~field("INTENDED_AT", intendedAt)
  text ||= .SecurityCanonical~field("CONSEQUENCE", consequenceClass)
  text ||= .SecurityCanonical~field("CAPABILITY", capabilityId)
  pairs = .array~new
  do key over attributes
    pairs~append(key~string~upper || "=" || attributes[key]~string)
  end
  text ||= .SecurityCanonical~join("ATTRIBUTE", pairs)
  return text

::class SecurityConstraint public
::attribute code get
::attribute scope get
::attribute detail get
::method init
  expose code scope detail
  use arg codeArg, scopeArg = "ACTION", detailArg = ""
  code = codeArg~string~upper
  scope = scopeArg~string~upper
  detail = detailArg~string
::method canonicalText
  expose code scope detail
  text = .SecurityCanonical~field("CONSTRAINT", code)
  text ||= .SecurityCanonical~field("SCOPE", scope)
  text ||= .SecurityCanonical~field("DETAIL", detail)
  return text

::class SecurityActionCriterion public
::attribute name get
::attribute operator get
::attribute expected get
::method init
  expose name operator expected
  use arg nameArg, operatorArg, expectedArg
  name = nameArg~string~upper
  operator = operatorArg~string~upper
  expected = expectedArg
::method matches
  use arg action
  actual = action~attribute(self~name)
  if actual == .nil then return .false
  select
    when self~operator = "EQ" then return actual~string~upper == self~expected~string~upper
    when self~operator = "NE" then return actual~string~upper <> self~expected~string~upper
    when self~operator = "GE" then return (actual + 0) >= (self~expected + 0)
    when self~operator = "GT" then return (actual + 0) > (self~expected + 0)
    when self~operator = "LE" then return (actual + 0) <= (self~expected + 0)
    when self~operator = "LT" then return (actual + 0) < (self~expected + 0)
    when self~operator = "CONTAINS" then return actual~string~upper~pos(self~expected~string~upper) > 0
    otherwise return .false
  end
::method canonicalText
  return .SecurityCanonical~field("CRITERION", self~name || "|" || self~operator || "|" || self~expected)

::class SecurityPolicyRule public
::attribute ruleId get
::attribute priority get
::attribute actionType get
::attribute disposition get
::attribute rationale get
::attribute sealed get
::method init
  expose ruleId priority actionType disposition rationale sealed requiredFindings forbiddenFindings criteria constraints unaffectedAbilities
  use arg ruleIdArg, priorityArg, actionTypeArg, dispositionArg, rationaleArg = ""
  ruleId = ruleIdArg~string~upper
  priority = priorityArg + 0
  actionType = actionTypeArg~string~upper
  disposition = dispositionArg~string~upper
  rationale = rationaleArg~string
  sealed = .false
  requiredFindings = .array~new
  forbiddenFindings = .array~new
  criteria = .array~new
  constraints = .array~new
  unaffectedAbilities = .array~new
::method requireFinding
  expose requiredFindings sealed
  use arg kind
  if sealed then return .false
  requiredFindings~append(kind~string~upper)
  return .true
::method forbidFinding
  expose forbiddenFindings sealed
  use arg kind
  if sealed then return .false
  forbiddenFindings~append(kind~string~upper)
  return .true
::method addCriterion
  expose criteria sealed
  use arg name, operator, expected
  if sealed then return .false
  criteria~append(.SecurityActionCriterion~new(name, operator, expected))
  return .true
::method addConstraint
  expose constraints sealed
  use arg code, scope = "ACTION", detail = ""
  if sealed then return .false
  constraints~append(.SecurityConstraint~new(code, scope, detail))
  return .true
::method addUnaffectedAbility
  expose unaffectedAbilities sealed
  use arg ability
  if sealed then return .false
  unaffectedAbilities~append(ability~string~upper)
  return .true
::method requiredFindings
  expose requiredFindings
  return .SecurityCanonical~copyArray(requiredFindings)
::method constraints
  expose constraints
  return .SecurityCanonical~copyArray(constraints)
::method unaffectedAbilities
  expose unaffectedAbilities
  return .SecurityCanonical~copyArray(unaffectedAbilities)
::method seal
  expose sealed
  sealed = .true
  return self
::method matches
  expose actionType requiredFindings forbiddenFindings criteria
  use arg action, snapshot
  if actionType <> "*" & action~actionType <> actionType then return .false
  do kind over requiredFindings
    if snapshot~hasFinding(kind) = .false then return .false
  end
  do kind over forbiddenFindings
    if snapshot~hasFinding(kind) then return .false
  end
  do criterion over criteria
    if criterion~matches(action) = .false then return .false
  end
  return .true
::method canonicalText
  expose ruleId priority actionType disposition rationale requiredFindings forbiddenFindings criteria constraints unaffectedAbilities
  text = .SecurityCanonical~field("RULE", ruleId)
  text ||= .SecurityCanonical~field("PRIORITY", priority)
  text ||= .SecurityCanonical~field("ACTION_TYPE", actionType)
  text ||= .SecurityCanonical~field("DISPOSITION", disposition)
  text ||= .SecurityCanonical~field("RATIONALE", rationale)
  text ||= .SecurityCanonical~join("REQUIRE_FINDING", requiredFindings)
  text ||= .SecurityCanonical~join("FORBID_FINDING", forbiddenFindings)
  cs = .array~new
  do item over criteria
    cs~append(item~canonicalText)
  end
  text ||= .SecurityCanonical~join("CRITERION", cs)
  xs = .array~new
  do item over constraints
    xs~append(item~canonicalText)
  end
  text ||= .SecurityCanonical~join("CONSTRAINT", xs)
  text ||= .SecurityCanonical~join("UNAFFECTED", unaffectedAbilities)
  return text

::class SecurityPolicyFramework public
::attribute policyId get
::attribute version get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute authoredBy get
::attribute approvedBy get
::attribute supersedes get
::attribute executionModel get
::attribute sealed get
::method init
  expose policyId version effectiveFrom effectiveUntil authoredBy approvedBy supersedes executionModel sealed rules
  use arg policyIdArg, versionArg, effectiveFromArg = .nil, effectiveUntilArg = .nil, authoredByArg = "", approvedByArg = "", supersedesArg = ""
  policyId = policyIdArg~string~upper
  version = versionArg~string
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new
  else effectiveFrom = effectiveFromArg
  if effectiveUntilArg == .nil then effectiveUntil = .nil
  else if effectiveUntilArg~string = "" then effectiveUntil = .nil
  else effectiveUntil = effectiveUntilArg
  authoredBy = authoredByArg~string
  approvedBy = approvedByArg~string
  supersedes = supersedesArg~string
  executionModel = .InstitutionalPolicyBuild~EXECUTION_MODEL
  sealed = .false
  rules = .array~new
::method addRule
  expose rules sealed
  use arg rule
  if sealed then return .false
  if rule == .nil then return .false
  if rule~sealed = .false then return .false
  do existing over rules
    if existing~ruleId == rule~ruleId then return .false
  end
  rules~append(rule)
  return .true
::method rules
  expose rules
  return .SecurityCanonical~copyArray(rules)
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  if moment >= effectiveUntil then return .false
  return .true
::method publicationEligible
  expose sealed authoredBy approvedBy
  if sealed = .false then return .false
  if authoredBy = "" then return .false
  if approvedBy = "" then return .false
  return .true
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose policyId version effectiveFrom effectiveUntil authoredBy approvedBy supersedes executionModel rules
  text = .SecurityCanonical~field("POLICY_ID", policyId)
  text ||= .SecurityCanonical~field("VERSION", version)
  text ||= .SecurityCanonical~field("SCHEMA", .SecurityEffectBuild~POLICY_SCHEMA)
  text ||= .SecurityCanonical~field("EFFECTIVE_FROM", effectiveFrom)
  text ||= .SecurityCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)
  text ||= .SecurityCanonical~field("AUTHORED_BY", authoredBy)
  text ||= .SecurityCanonical~field("APPROVED_BY", approvedBy)
  text ||= .SecurityCanonical~field("SUPERSEDES", supersedes)
  text ||= .SecurityCanonical~field("EXECUTION_MODEL", executionModel)
  rs = .array~new
  do rule over rules
    rs~append(rule~canonicalText)
  end
  text ||= .SecurityCanonical~join("RULE", rs)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityRuleTrace public
::attribute ruleId get
::attribute matched get
::attribute disposition get
::attribute rationale get
::method init
  expose ruleId matched disposition rationale findingIds
  use arg ruleIdArg, matchedArg, dispositionArg = "", rationaleArg = ""
  ruleId = ruleIdArg~string~upper
  matched = matchedArg
  disposition = dispositionArg~string~upper
  rationale = rationaleArg~string
  findingIds = .array~new
::method addFindingId
  expose findingIds
  use arg findingId
  findingIds~append(findingId~string)
  return self
::method findingIds
  expose findingIds
  return .SecurityCanonical~copyArray(findingIds)
::method canonicalText
  expose ruleId matched disposition rationale findingIds
  text = .SecurityCanonical~field("RULE", ruleId)
  text ||= .SecurityCanonical~field("MATCHED", matched)
  text ||= .SecurityCanonical~field("DISPOSITION", disposition)
  text ||= .SecurityCanonical~field("RATIONALE", rationale)
  text ||= .SecurityCanonical~join("FINDING_ID", findingIds)
  return text

::class SecurityDecisionTrace public
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute actionId get
::attribute actionIdentity get
::attribute snapshotId get
::attribute snapshotIdentity get
::attribute evaluationMode get
::attribute finalDisposition get
::attribute sealed get
::method init
  expose policyId policyVersion policyIdentity actionId actionIdentity snapshotId snapshotIdentity evaluationMode finalDisposition sealed traces
  use arg framework, action, snapshot, evaluationModeArg = "OPERATIVE"
  policyId = framework~policyId
  policyVersion = framework~version
  policyIdentity = framework~semanticIdentity
  actionId = action~actionId
  actionIdentity = action~canonicalText
  snapshotId = snapshot~snapshotId
  snapshotIdentity = snapshot~semanticIdentity
  evaluationMode = evaluationModeArg~string~upper
  finalDisposition = ""
  sealed = .false
  traces = .array~new
::method add
  expose traces sealed
  use arg trace
  if sealed then return .false
  traces~append(trace)
  return .true
::method traces
  expose traces
  return .SecurityCanonical~copyArray(traces)
::method finalize
  expose finalDisposition sealed
  use arg disposition
  finalDisposition = disposition~string~upper
  sealed = .true
  return self
::method canonicalText
  expose policyId policyVersion policyIdentity actionId actionIdentity snapshotId snapshotIdentity evaluationMode finalDisposition traces
  text = .SecurityCanonical~field("POLICY", policyId)
  text ||= .SecurityCanonical~field("VERSION", policyVersion)
  text ||= .SecurityCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .SecurityCanonical~field("ACTION", actionId)
  text ||= .SecurityCanonical~field("ACTION_IDENTITY", actionIdentity)
  text ||= .SecurityCanonical~field("SNAPSHOT", snapshotId)
  text ||= .SecurityCanonical~field("SNAPSHOT_IDENTITY", snapshotIdentity)
  text ||= .SecurityCanonical~field("EVALUATION_MODE", evaluationMode)
  ts = .array~new
  do trace over traces
    ts~append(trace~canonicalText)
  end
  text ||= .SecurityCanonical~join("TRACE", ts)
  text ||= .SecurityCanonical~field("FINAL", finalDisposition)
  return text
::method traceIdentity
  return self~canonicalText

::class SecurityAssessment public
::attribute action get
::attribute snapshot get
::attribute policy get
::attribute disposition get
::attribute trace get
::method init
  expose action snapshot policy disposition constraints unaffectedAbilities appliedRules trace
  use arg actionArg, snapshotArg, policyArg, evaluationModeArg = "OPERATIVE"
  action = actionArg
  snapshot = snapshotArg
  policy = policyArg
  disposition = .SecurityConstant~DISP_ALLOW
  constraints = .array~new
  unaffectedAbilities = .array~new
  appliedRules = .array~new
  trace = .SecurityDecisionTrace~new(policyArg, actionArg, snapshotArg, evaluationModeArg)
::method addAppliedRule
  expose appliedRules
  use arg rule
  appliedRules~append(rule)
  return self
::method addConstraint
  expose constraints
  use arg constraint
  do existing over constraints
    if existing~code == constraint~code & existing~scope == constraint~scope then return self
  end
  constraints~append(constraint)
  return self
::method addUnaffectedAbility
  expose unaffectedAbilities
  use arg ability
  if .SecurityCanonical~containsString(unaffectedAbilities, ability) = .false then unaffectedAbilities~append(ability~string~upper)
  return self
::method setDisposition
  expose disposition
  use arg newDisposition
  disposition = newDisposition~string~upper
  return self
::method constraints
  expose constraints
  return .SecurityCanonical~copyArray(constraints)
::method unaffectedAbilities
  expose unaffectedAbilities
  return .SecurityCanonical~copyArray(unaffectedAbilities)
::method appliedRules
  expose appliedRules
  return .SecurityCanonical~copyArray(appliedRules)
::method containsConstraint
  expose constraints
  use arg code
  wanted = code~string~upper
  do item over constraints
    if item~code == wanted then return .true
  end
  return .false
::method finalise
  expose trace disposition
  trace~finalize(disposition)
  return self
::method outcomeCanonicalText
  expose disposition constraints unaffectedAbilities
  text = .SecurityCanonical~field("DISPOSITION", disposition)
  xs = .array~new
  do constraint over constraints
    xs~append(constraint~canonicalText)
  end
  text ||= .SecurityCanonical~join("CONSTRAINT", xs)
  text ||= .SecurityCanonical~join("UNAFFECTED", unaffectedAbilities)
  return text

::class SecurityAlchemySupport public
::method metadata class
  use arg purpose
  d = .directory~new
  d["component"] = "SECURITY_EFFECT"
  d["package"] = "security_effect"
  d["package_version"] = .SecurityEffectBuild~RELEASE
  d["release"] = .SecurityEffectBuild~RELEASE
  d["api"] = .SecurityEffectBuild~API_VERSION
  d["purpose"] = purpose~string
  d["authorship"] = .array~of("OpenAI implementation under Architect direction")
  d["standards"] = .array~of("ALCHEMY-HOUSE-OBJECT-0.8", .SecurityEffectBuild~API_VERSION)
  d["design_limitations"] = .array~of("in-memory evidence/policy/deployment stores; durable backing belongs to host integration", "policy engine consumes findings but does not replace specialist sensors", "cross-domain mapping requires an explicit sealed mapping policy", "v0.14 retains Institutional Policy v0.8 governance, Relationship Case referral, exact invocation freshness, and adds non-authoritative continuation/commit revalidation so irreversible publication requires a current Security snapshot and exact staged-state/context identity")
  return d

::class SecurityEvidenceStore subclass AlchemyObject public
::method init
  expose observations findings subjectObservations subjectFindings sequence
  use arg sealer = .nil, authority = .nil
  observations = .directory~new
  findings = .directory~new
  subjectObservations = .directory~new
  subjectFindings = .directory~new
  sequence = 0
  self~init:super(.SecurityAlchemySupport~metadata("append-only security evidence and institutional memory"), sealer, authority)
  self~registerStateVariable("observations", "INTERNAL", "append-only security observations")
  self~registerStateVariable("findings", "INTERNAL", "append-only security findings")
  self~registerMethodContract("RECORDOBSERVATION", "record sealed security observation", .array~of("OBSERVATION"), "SECURITYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("RECORDFINDING", "record sealed security finding", .array~of("FINDING"), "SECURITYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("SNAPSHOTFOR", "construct subject security snapshot", .array~of("SUBJECT_ID", "AT_TIME"), "SECURITYSNAPSHOT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method ensureBucket private
  use arg directory, key
  if directory~hasIndex(key) = .false then directory[key] = .array~new
  return directory[key]
::method recordObservation
  expose observations subjectObservations
  use arg observation
  if observation == .nil then return .SecurityResult~failure("OBSERVATION_REQUIRED")
  if observation~sealed = .false then return .SecurityResult~failure("OBSERVATION_NOT_SEALED", observation~observationId)
  if observations~hasIndex(observation~observationId) then return .SecurityResult~failure("OBSERVATION_DUPLICATE", observation~observationId)
  observations[observation~observationId] = observation
  bucket = self~ensureBucket(subjectObservations, observation~subjectId)
  bucket~append(observation)
  self~recordRelationship("CAPTURES", observation, "sealed security observation", "INTERNAL")
  return .SecurityResult~success(observation)
::method recordFinding
  expose findings subjectFindings
  use arg finding
  if finding == .nil then return .SecurityResult~failure("FINDING_REQUIRED")
  if finding~sealed = .false then return .SecurityResult~failure("FINDING_NOT_SEALED", finding~findingId)
  if findings~hasIndex(finding~findingId) then return .SecurityResult~failure("FINDING_DUPLICATE", finding~findingId)
  findings[finding~findingId] = finding
  bucket = self~ensureBucket(subjectFindings, finding~subjectId)
  bucket~append(finding)
  self~recordRelationship("CAPTURES", finding, "sealed security finding", "INTERNAL")
  return .SecurityResult~success(finding)
::method snapshotFor
  expose subjectObservations subjectFindings sequence
  use arg subjectId, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  sequence += 1
  snap = .SecuritySnapshot~new("SEC-SNAPSHOT-" || sequence, subjectId, atTime)
  key = subjectId~string
  if subjectObservations~hasIndex(key) then do observation over subjectObservations[key]
    if observation~occurredAt <= atTime then snap~addObservation(observation)
  end
  if subjectFindings~hasIndex(key) then do finding over subjectFindings[key]
    if finding~effectiveFrom <= atTime & finding~activeAt(atTime) then snap~addFinding(finding)
  end
  return snap~seal

::class SecurityEffectEngine subclass AlchemyObject public
::method init
  use arg sealer = .nil, authority = .nil
  self~init:super(.SecurityAlchemySupport~metadata("deterministic action-scoped security policy evaluator"), sealer, authority)
  self~registerMethodContract("EVALUATE", "evaluate sealed action against sealed snapshot and operative policy", .array~of("ACTION", "SNAPSHOT", "POLICY"), "SECURITYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "USE")
  self~registerMethodContract("EVALUATECOUNTERFACTUAL", "evaluate sealed historical action against explicit non-operative policy for comparison", .array~of("ACTION", "SNAPSHOT", "POLICY"), "SECURITYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "USE")
::method evaluate
  use arg action, snapshot, framework
  return self~evaluateInternal(action, snapshot, framework, .true, "OPERATIVE")
::method evaluateCounterfactual
  use arg action, snapshot, framework
  return self~evaluateInternal(action, snapshot, framework, .false, "COUNTERFACTUAL")
::method evaluateInternal private
  use arg action, snapshot, framework, enforceEffective, evaluationMode
  if action == .nil then return .SecurityResult~failure("ACTION_REQUIRED")
  if snapshot == .nil then return .SecurityResult~failure("SNAPSHOT_REQUIRED")
  if framework == .nil then return .SecurityResult~failure("POLICY_REQUIRED")
  if action~sealed = .false then return .SecurityResult~failure("ACTION_NOT_SEALED")
  if snapshot~sealed = .false then return .SecurityResult~failure("SNAPSHOT_NOT_SEALED")
  if framework~sealed = .false then return .SecurityResult~failure("POLICY_NOT_SEALED")
  if action~subjectId <> snapshot~subjectId then return .SecurityResult~failure("SUBJECT_MISMATCH")
  if enforceEffective then policyGate = .InstitutionalPolicyReplayGuard~operative(framework, action~intendedAt)
  else policyGate = .InstitutionalPolicyReplayGuard~counterfactual(framework, action~intendedAt)
  if policyGate~ok = .false then return .SecurityResult~failure(policyGate~code, policyGate~detail)
  evaluationMode = policyGate~value~evaluationMode
  assessment = .SecurityAssessment~new(action, snapshot, framework, evaluationMode)
  rules = self~sortedRules(framework~rules)
  finalDisposition = .SecurityConstant~DISP_ALLOW
  finalRank = self~rank(finalDisposition)
  do rule over rules
    matched = rule~matches(action, snapshot)
    ruleTrace = .SecurityRuleTrace~new(rule~ruleId, matched, rule~disposition, rule~rationale)
    if matched then do kind over rule~requiredFindings
      do finding over snapshot~findingsOfKind(kind)
        ruleTrace~addFindingId(finding~findingId)
      end
    end
    assessment~trace~add(ruleTrace)
    if matched = .false then iterate
    assessment~addAppliedRule(rule)
    rank = self~rank(rule~disposition)
    if rank > finalRank then do
      finalRank = rank
      finalDisposition = rule~disposition
    end
    do constraint over rule~constraints
      assessment~addConstraint(constraint)
    end
    do ability over rule~unaffectedAbilities
      assessment~addUnaffectedAbility(ability)
    end
  end
  assessment~setDisposition(finalDisposition)~finalise
  return .SecurityResult~success(assessment)
::method rank private
  use arg disposition
  select
    when disposition = .SecurityConstant~DISP_ALLOW then return 0
    when disposition = .SecurityConstant~DISP_CAUTION then return 1
    when disposition = .SecurityConstant~DISP_REVIEW then return 2
    when disposition = .SecurityConstant~DISP_HOLD then return 3
    when disposition = .SecurityConstant~DISP_REJECT then return 4
    otherwise return 5
  end
::method sortedRules private
  use arg source
  remaining = .SecurityCanonical~copyArray(source)
  out = .array~new
  do while remaining~items > 0
    bestIndex = 1
    best = remaining[1]
    i = 2
    do while i <= remaining~items
      candidate = remaining[i]
      if candidate~priority < best~priority then do
        bestIndex = i
        best = candidate
      end
      else if candidate~priority = best~priority & candidate~ruleId < best~ruleId then do
        bestIndex = i
        best = candidate
      end
      i += 1
    end
    out~append(best)
    next = .array~new
    i = 1
    do while i <= remaining~items
      if i <> bestIndex then next~append(remaining[i])
      i += 1
    end
    remaining = next
  end
  return out

::class SecurityProbePolicy public
::attribute policyId get
::attribute version get
::attribute minimumSignals get
::attribute sealed get
::method init
  expose policyId version minimumSignals sealed probeKinds decisiveKinds
  use arg policyIdArg = "SECURITY-PROBE-POLICY", versionArg = "1.0", minimumSignalsArg = 3
  policyId = policyIdArg~string~upper
  version = versionArg~string
  minimumSignals = minimumSignalsArg + 0
  sealed = .false
  probeKinds = .array~of("ROUTE_ENUMERATION", "RESOURCE_ENUMERATION", "SQL_INJECTION_CANDIDATE", "COMMAND_INJECTION_CANDIDATE", "PATH_TRAVERSAL_CANDIDATE", "TEMPLATE_INJECTION_CANDIDATE", "CANARY_RESOURCE_ACCESSED", "PRIVILEGE_BOUNDARY_PROBE", "ABILITY_DISCOVERY_PROBE")
  decisiveKinds = .array~of("CANARY_RESOURCE_ACCESSED", "PRIVILEGE_BOUNDARY_PROBE")
::method probeKinds
  expose probeKinds
  return .SecurityCanonical~copyArray(probeKinds)
::method decisiveKinds
  expose decisiveKinds
  return .SecurityCanonical~copyArray(decisiveKinds)
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose policyId version minimumSignals probeKinds decisiveKinds
  text = .SecurityCanonical~field("PROBE_POLICY", policyId)
  text ||= .SecurityCanonical~field("VERSION", version)
  text ||= .SecurityCanonical~field("MINIMUM_SIGNALS", minimumSignals)
  text ||= .SecurityCanonical~join("PROBE_KIND", probeKinds)
  text ||= .SecurityCanonical~join("DECISIVE_KIND", decisiveKinds)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityProbeAnalyzer public
::method analyze
  use arg snapshot, policy
  if snapshot == .nil then return .SecurityResult~failure("SNAPSHOT_REQUIRED")
  if policy == .nil then return .SecurityResult~failure("PROBE_POLICY_REQUIRED")
  if snapshot~sealed = .false then return .SecurityResult~failure("SNAPSHOT_NOT_SEALED")
  if policy~sealed = .false then return .SecurityResult~failure("PROBE_POLICY_NOT_SEALED")
  signals = snapshot~observationCount(policy~probeKinds)
  decisive = .false
  do kind over policy~decisiveKinds
    if snapshot~hasObservationKind(kind) then decisive = .true
  end
  if signals = 0 then return .SecurityResult~success(.nil, "NO_PROBE_FINDING")
  if signals >= policy~minimumSignals | decisive then do
    confidence = 60 + signals * 10
    if decisive then confidence = confidence + 15
    if confidence > 100 then confidence = 100
    finding = .SecurityFinding~new("PROBE:" || snapshot~snapshotId, "ACTIVE_EXPLOIT_PROBE", "CONCERN", snapshot~subjectId, confidence, snapshot~capturedAt, .nil, "fixed probe policy correlated " || signals || " probe signal(s)", "SECURITY_EFFECT")
    finding~addEvidence(.SecurityEvidenceAnchor~new(policy~policyId || ":" || policy~version, "SECURITY_PROBE_POLICY", policy~semanticIdentity, snapshot~capturedAt, 100, policy))
    return .SecurityResult~success(finding~seal, "ACTIVE_EXPLOIT_PROBE")
  end
  finding = .SecurityFinding~new("PROBE:" || snapshot~snapshotId, "PROBE_ACTIVITY_OBSERVED", "CONCERN", snapshot~subjectId, 50, snapshot~capturedAt, .nil, "probe-like traffic observed below active-campaign threshold", "SECURITY_EFFECT")
  return .SecurityResult~success(finding~seal, "PROBE_ACTIVITY_OBSERVED")

::class SecurityFindingFactory public
::method external class
  use arg findingId, kind, state, subjectId, confidence, sourceDomain, sourceObject = .nil, detail = "", effectiveFrom = .nil, effectiveUntil = .nil
  finding = .SecurityFinding~new(findingId, kind, state, subjectId, confidence, effectiveFrom, effectiveUntil, detail, sourceDomain)
  if sourceObject <> .nil then finding~addEvidence(.SecurityEvidenceAnchor~new(findingId || ":SOURCE", sourceDomain, "external-object", .DateTime~new, confidence, sourceObject))
  return finding~seal


/* ------------------------------------------------------------------------- */
/* v0.2 policy lifecycle, replay and capability-envelope language            */
/* ------------------------------------------------------------------------- */

::class SecurityPolicyCatalog subclass InstitutionalPolicyCatalog public
::method init
  use arg sealer = .nil, authority = .nil, authorityEvaluator = .nil, lifecycleEvaluator = .nil, deploymentEvaluator = .nil
  self~init:super(.SecurityAlchemySupport~metadata("published deterministic security policy catalogue with immutable lifecycle and scoped deployment topology evidence"), sealer, authority, .SecurityResult, authorityEvaluator, lifecycleEvaluator, deploymentEvaluator)

::class SecurityPolicyComparison public
::attribute action get
::attribute snapshot get
::attribute fromAssessment get
::attribute toAssessment get
::attribute changed get
::attribute traceChanged get
::method init
  expose action snapshot fromAssessment toAssessment changed traceChanged
  use arg actionArg, snapshotArg, fromArg, toArg
  action = actionArg
  snapshot = snapshotArg
  fromAssessment = fromArg
  toAssessment = toArg
  commonComparison = .InstitutionalPolicyComparison~new(fromArg~policy, toArg~policy, fromArg~outcomeCanonicalText, toArg~outcomeCanonicalText, fromArg~trace~traceIdentity, toArg~trace~traceIdentity)
  changed = commonComparison~outcomeChanged
  traceChanged = commonComparison~traceChanged
::method canonicalText
  expose action snapshot fromAssessment toAssessment changed traceChanged
  text = .SecurityCanonical~field("ACTION", action~actionId)
  text ||= .SecurityCanonical~field("SNAPSHOT", snapshot~snapshotId)
  text ||= .SecurityCanonical~field("FROM_POLICY", fromAssessment~policy~policyId || "@" || fromAssessment~policy~version)
  text ||= .SecurityCanonical~field("FROM_DISPOSITION", fromAssessment~disposition)
  text ||= .SecurityCanonical~field("FROM_TRACE", fromAssessment~trace~traceIdentity)
  text ||= .SecurityCanonical~field("TO_POLICY", toAssessment~policy~policyId || "@" || toAssessment~policy~version)
  text ||= .SecurityCanonical~field("TO_DISPOSITION", toAssessment~disposition)
  text ||= .SecurityCanonical~field("TO_TRACE", toAssessment~trace~traceIdentity)
  text ||= .SecurityCanonical~field("OUTCOME_CHANGED", changed)
  text ||= .SecurityCanonical~field("TRACE_CHANGED", traceChanged)
  return text

::class SecurityPolicyReplayEngine subclass AlchemyObject public
::method init
  expose engine
  use arg sealer = .nil, authority = .nil
  engine = .SecurityEffectEngine~new
  self~init:super(.SecurityAlchemySupport~metadata("historical replay and policy comparison service"), sealer, authority)
  self~registerMethodContract("REPLAY", "replay an historical action under the supplied policy artefact", .array~of("ACTION", "SNAPSHOT", "POLICY"), "SECURITYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "USE")
  self~registerMethodContract("REPLAYPUBLISHED", "replay using the exact policy deployment state operative in a published catalogue", .array~of("ACTION", "SNAPSHOT", "CATALOG", "POLICY_ID"), "SECURITYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "USE")
  self~registerMethodContract("COUNTERFACTUAL", "evaluate historical evidence under an explicit alternate policy regardless of its effective window", .array~of("ACTION", "SNAPSHOT", "POLICY"), "SECURITYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "USE")
  self~registerMethodContract("COMPARE", "compare operative historical result with an explicit alternate policy", .array~of("ACTION", "SNAPSHOT", "FROM_POLICY", "TO_POLICY"), "SECURITYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "USE")
::method replay
  expose engine
  use arg action, snapshot, framework
  return engine~evaluate(action, snapshot, framework)
::method replayPublished
  expose engine
  use arg action, snapshot, catalog, policyId = "SECURITY-POLICY-CORE", deploymentPoint = .nil
  if catalog == .nil then return .SecurityResult~failure("POLICY_CATALOG_REQUIRED")
  if catalog~hasMethod("RESOLVEFORCONTEXT") then resolved = catalog~resolveForContext(policyId, deploymentPoint, action~intendedAt)
  else resolved = catalog~resolve(policyId, action~intendedAt)
  if resolved~ok = .false then return resolved
  return engine~evaluate(action, snapshot, resolved~value)
::method counterfactual
  expose engine
  use arg action, snapshot, framework
  return engine~evaluateCounterfactual(action, snapshot, framework)
::method compare
  expose engine
  use arg action, snapshot, fromPolicy, toPolicy
  fromResult = engine~evaluate(action, snapshot, fromPolicy)
  if fromResult~ok = .false then return fromResult
  toResult = engine~evaluateCounterfactual(action, snapshot, toPolicy)
  if toResult~ok = .false then return toResult
  return .SecurityResult~success(.SecurityPolicyComparison~new(action, snapshot, fromResult~value, toResult~value))

::class SecurityCapabilityContribution public
::attribute sourceDomain get
::attribute sourceRef get
::attribute disposition get
::attribute detail get
::attribute sealed get
::method init
  expose sourceDomain sourceRef disposition detail constraints sealed
  use arg sourceDomainArg, sourceRefArg, dispositionArg, detailArg = ""
  sourceDomain = sourceDomainArg~string~upper
  sourceRef = sourceRefArg~string
  disposition = dispositionArg~string~upper
  detail = detailArg~string
  constraints = .array~new
  sealed = .false
::method addConstraint
  expose constraints sealed
  use arg constraint
  if sealed then return .false
  if constraint <> .nil then constraints~append(constraint)
  return self
::method seal
  expose sealed
  sealed = .true
  return self
::method constraints
  expose constraints
  return .SecurityCanonical~copyArray(constraints)
::method canonicalText
  expose sourceDomain sourceRef disposition detail constraints
  text = .SecurityCanonical~field("SOURCE_DOMAIN", sourceDomain)
  text ||= .SecurityCanonical~field("SOURCE_REF", sourceRef)
  text ||= .SecurityCanonical~field("DISPOSITION", disposition)
  text ||= .SecurityCanonical~field("DETAIL", detail)
  xs = .array~new
  do item over constraints
    xs~append(item~canonicalText)
  end
  text ||= .SecurityCanonical~join("CONSTRAINT", xs)
  return text

::class SecurityCapabilityEntry public
::attribute capabilityId get
::attribute disposition get
::attribute sealed get
::method init
  expose capabilityId disposition contributions sealed
  use arg capabilityIdArg
  capabilityId = capabilityIdArg~string~upper
  disposition = .SecurityConstant~DISP_ALLOW
  contributions = .array~new
  sealed = .false
::method addContribution
  expose contributions disposition sealed
  use arg contribution
  if sealed then return .false
  if contribution == .nil then return .false
  if contribution~sealed = .false then return .false
  contributions~append(contribution)
  if self~rank(contribution~disposition) > self~rank(disposition) then disposition = contribution~disposition
  return self
::method contributions
  expose contributions
  return .SecurityCanonical~copyArray(contributions)
::method seal
  expose sealed
  sealed = .true
  return self
::method constraints
  expose contributions
  out = .array~new
  do contribution over contributions
    do constraint over contribution~constraints
      duplicate = .false
      do existing over out
        if existing~code == constraint~code & existing~scope == constraint~scope then duplicate = .true
      end
      if duplicate = .false then out~append(constraint)
    end
  end
  return out
::method rank private
  use arg value
  select
    when value = .SecurityConstant~DISP_ALLOW then return 0
    when value = .SecurityConstant~DISP_CAUTION then return 1
    when value = .SecurityConstant~DISP_REVIEW then return 2
    when value = .SecurityConstant~DISP_HOLD then return 3
    when value = .SecurityConstant~DISP_REJECT then return 4
    otherwise return 5
  end
::method canonicalText
  expose capabilityId disposition contributions
  text = .SecurityCanonical~field("CAPABILITY", capabilityId)
  text ||= .SecurityCanonical~field("DISPOSITION", disposition)
  cs = .array~new
  do item over contributions
    cs~append(item~canonicalText)
  end
  text ||= .SecurityCanonical~join("CONTRIBUTION", cs)
  return text

::class SecurityCapabilityEnvelope public
::attribute subjectId get
::attribute capturedAt get
::attribute sealed get
::method init
  expose subjectId capturedAt sealed entries
  use arg subjectIdArg, capturedAtArg = .nil
  subjectId = subjectIdArg~string
  if capturedAtArg == .nil then capturedAt = .DateTime~new
  else capturedAt = capturedAtArg
  sealed = .false
  entries = .directory~new
::method ensureEntry private
  expose entries
  use arg capabilityId
  key = capabilityId~string~upper
  if entries~hasIndex(key) = .false then entries[key] = .SecurityCapabilityEntry~new(key)
  return entries[key]
::method addContribution
  expose sealed
  use arg capabilityId, contribution
  if sealed then return .false
  if contribution == .nil then return .false
  if contribution~sealed = .false then return .false
  return self~ensureEntry(capabilityId)~addContribution(contribution)
::method applyAssessment
  expose sealed subjectId
  use arg assessment, sourceDomain = "SECURITY_EFFECT"
  if sealed then return .false
  if assessment == .nil then return .false
  if assessment~action~subjectId <> subjectId then return .false
  ability = assessment~action~capabilityId
  if ability = "" then ability = assessment~action~actionType
  contribution = .SecurityCapabilityContribution~new(sourceDomain, assessment~trace~traceIdentity, assessment~disposition, "action-scoped assessment")
  do constraint over assessment~constraints
    contribution~addConstraint(constraint)
  end
  contribution~seal
  self~addContribution(ability, contribution)
  do unaffected over assessment~unaffectedAbilities
    self~addContribution(unaffected, .SecurityCapabilityContribution~new(sourceDomain, assessment~trace~traceIdentity, .SecurityConstant~DISP_ALLOW, "explicitly unaffected by this assessment")~seal)
  end
  return .true
::method merge
  expose sealed subjectId
  use arg other
  if sealed then return .false
  if other == .nil then return .false
  if other~subjectId <> subjectId then return .false
  do entry over other~entries
    do contribution over entry~contributions
      self~addContribution(entry~capabilityId, contribution)
    end
  end
  return .true
::method entry
  expose entries
  use arg capabilityId
  key = capabilityId~string~upper
  if entries~hasIndex(key) then return entries[key]
  return .nil
::method entries
  expose entries
  out = .array~new
  keys = .array~new
  do key over entries
    keys~append(key)
  end
  keys~sort
  do key over keys
    out~append(entries[key])
  end
  return out
::method seal
  expose sealed entries
  do key over entries
    entries[key]~seal
  end
  sealed = .true
  return self
::method canonicalText
  expose subjectId capturedAt entries
  text = .SecurityCanonical~field("SUBJECT", subjectId)
  text ||= .SecurityCanonical~field("CAPTURED_AT", capturedAt)
  es = .array~new
  do item over self~entries
    es~append(item~canonicalText)
  end
  text ||= .SecurityCanonical~join("ENTRY", es)
  return text

/* ------------------------------------------------------------------------- */
/* v0.2 explicit, versioned cross-domain interpretation                       */
/* ------------------------------------------------------------------------- */

::class SecurityExternalSignal public
::attribute sourceDomain get
::attribute signalKind get
::attribute subjectId get
::attribute sourceId get
::attribute observedAt get
::attribute confidence get
::attribute sourceObject get
::attribute detail get
::method init
  expose sourceDomain signalKind subjectId sourceId observedAt confidence sourceObject detail
  use arg sourceDomainArg, signalKindArg, subjectIdArg, sourceIdArg, observedAtArg = .nil, confidenceArg = 100, sourceObjectArg = .nil, detailArg = ""
  sourceDomain = sourceDomainArg~string~upper
  signalKind = signalKindArg~string~upper
  subjectId = subjectIdArg~string
  sourceId = sourceIdArg~string
  if observedAtArg == .nil then observedAt = .DateTime~new
  else observedAt = observedAtArg
  confidence = confidenceArg + 0
  sourceObject = sourceObjectArg
  detail = detailArg~string
::method canonicalText
  expose sourceDomain signalKind subjectId sourceId observedAt confidence detail
  text = .SecurityCanonical~field("SOURCE_DOMAIN", sourceDomain)
  text ||= .SecurityCanonical~field("SIGNAL_KIND", signalKind)
  text ||= .SecurityCanonical~field("SUBJECT", subjectId)
  text ||= .SecurityCanonical~field("SOURCE_ID", sourceId)
  text ||= .SecurityCanonical~field("OBSERVED_AT", observedAt)
  text ||= .SecurityCanonical~field("CONFIDENCE", confidence)
  text ||= .SecurityCanonical~field("DETAIL", detail)
  return text

::class SecurityEvidenceMappingRule public
::attribute ruleId get
::attribute sourceDomain get
::attribute signalKind get
::attribute findingKind get
::attribute findingState get
::attribute confidenceCap get
::attribute validitySeconds get
::attribute sealed get
::method init
  expose ruleId sourceDomain signalKind findingKind findingState confidenceCap validitySeconds sealed
  use arg ruleIdArg, sourceDomainArg, signalKindArg, findingKindArg, findingStateArg = "CONCERN", confidenceCapArg = 100, validitySecondsArg = 3600
  ruleId = ruleIdArg~string~upper
  sourceDomain = sourceDomainArg~string~upper
  signalKind = signalKindArg~string~upper
  findingKind = findingKindArg~string~upper
  findingState = findingStateArg~string~upper
  confidenceCap = confidenceCapArg + 0
  validitySeconds = validitySecondsArg + 0
  sealed = .false
::method matches
  use arg signal
  return signal~sourceDomain == self~sourceDomain & signal~signalKind == self~signalKind
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose ruleId sourceDomain signalKind findingKind findingState confidenceCap validitySeconds
  text = .SecurityCanonical~field("RULE", ruleId)
  text ||= .SecurityCanonical~field("SOURCE_DOMAIN", sourceDomain)
  text ||= .SecurityCanonical~field("SIGNAL_KIND", signalKind)
  text ||= .SecurityCanonical~field("FINDING_KIND", findingKind)
  text ||= .SecurityCanonical~field("FINDING_STATE", findingState)
  text ||= .SecurityCanonical~field("CONFIDENCE_CAP", confidenceCap)
  text ||= .SecurityCanonical~field("VALIDITY_SECONDS", validitySeconds)
  return text

::class SecurityEvidenceMappingPolicy public
::attribute policyId get
::attribute version get
::attribute authoredBy get
::attribute approvedBy get
::attribute sealed get
::method init
  expose policyId version authoredBy approvedBy sealed rules
  use arg policyIdArg, versionArg, authoredByArg = "", approvedByArg = ""
  policyId = policyIdArg~string~upper
  version = versionArg~string
  authoredBy = authoredByArg~string
  approvedBy = approvedByArg~string
  sealed = .false
  rules = .array~new
::method addRule
  expose sealed rules
  use arg rule
  if sealed then return .false
  if rule == .nil then return .false
  if rule~sealed = .false then return .false
  do existing over rules
    if existing~ruleId == rule~ruleId then return .false
  end
  rules~append(rule)
  return .true
::method matchingRule
  expose rules
  use arg signal
  found = .nil
  do rule over rules
    if rule~matches(signal) then do
      if found <> .nil then return .false
      found = rule
    end
  end
  return found
::method rules
  expose rules
  return .SecurityCanonical~copyArray(rules)
::method publicationEligible
  expose sealed authoredBy approvedBy
  return sealed & authoredBy <> "" & approvedBy <> ""
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose policyId version authoredBy approvedBy rules
  text = .SecurityCanonical~field("MAPPING_POLICY", policyId)
  text ||= .SecurityCanonical~field("VERSION", version)
  text ||= .SecurityCanonical~field("AUTHORED_BY", authoredBy)
  text ||= .SecurityCanonical~field("APPROVED_BY", approvedBy)
  rs = .array~new
  do rule over rules
    rs~append(rule~canonicalText)
  end
  text ||= .SecurityCanonical~join("RULE", rs)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityExternalEvidenceBridge public
::method map
  use arg signal, policy
  if signal == .nil then return .SecurityResult~failure("EXTERNAL_SIGNAL_REQUIRED")
  if policy == .nil then return .SecurityResult~failure("MAPPING_POLICY_REQUIRED")
  if policy~sealed = .false then return .SecurityResult~failure("MAPPING_POLICY_NOT_SEALED")
  if policy~publicationEligible = .false then return .SecurityResult~failure("MAPPING_POLICY_NOT_APPROVED")
  rule = policy~matchingRule(signal)
  if rule == .false then return .SecurityResult~failure("MAPPING_POLICY_AMBIGUOUS", signal~sourceDomain || ":" || signal~signalKind)
  if rule == .nil then return .SecurityResult~success(.nil, "NO_MAPPING")
  confidence = signal~confidence
  if confidence > rule~confidenceCap then confidence = rule~confidenceCap
  until = signal~observedAt + .SecurityCanonical~timeSpanSeconds(rule~validitySeconds)
  id = "MAP:" || policy~policyId || ":" || policy~version || ":" || rule~ruleId || ":" || signal~sourceId
  finding = .SecurityFinding~new(id, rule~findingKind, rule~findingState, signal~subjectId, confidence, signal~observedAt, until, signal~detail, signal~sourceDomain)
  finding~addEvidence(.SecurityEvidenceAnchor~new(signal~sourceId, signal~sourceDomain, signal~signalKind, signal~observedAt, signal~confidence, signal~sourceObject))
  finding~addEvidence(.SecurityEvidenceAnchor~new(policy~policyId || ":" || policy~version, "SECURITY_MAPPING_POLICY", rule~ruleId, signal~observedAt, 100, policy))
  return .SecurityResult~success(finding~seal, rule~ruleId)


/* Exact method/object binding surface for the Access Permissions boundary.
 * This remains a Security Effect value object: it does not grant permission and
 * does not call the Permission authority. */
::class SecurityMethodActionFactory public
::method create class
  use arg actionId, subjectId, objectId, objectClass, methodName, intendedAt = .nil, consequenceClass = "NORMAL", capabilityId = ""
  if actionId~string = "" | subjectId~string = "" | objectId~string = "" | objectClass~string = "" | methodName~string = "" then return .SecurityResult~failure("METHOD_ACTION_IDENTITY_REQUIRED")
  action = .SecurityActionSurface~new(actionId, subjectId, "METHOD_INVOCATION", intendedAt, consequenceClass, capabilityId)
  action~putAttribute("OBJECT_ID", objectId~string)
  action~putAttribute("OBJECT_CLASS", objectClass~string~upper)
  action~putAttribute("METHOD", methodName~string~upper)
  return .SecurityResult~success(action)
::method createInvocation class
  use arg actionId, subjectId, objectId, objectClass, methodName, invocationEvidence, intendedAt = .nil, consequenceClass = "NORMAL", capabilityId = ""
  if invocationEvidence == .nil | \invocationEvidence~sealed then return .SecurityResult~failure("SECURITY_INVOCATION_EVIDENCE_REQUIRED")
  base = self~create(actionId, subjectId, objectId, objectClass, methodName, intendedAt, consequenceClass, capabilityId)
  if \base~ok then return base
  action = base~value
  action~putAttribute("INVOCATION_ID", invocationEvidence~invocationId)
  action~putAttribute("ARGUMENT_IDENTITY", invocationEvidence~argumentIdentity)
  action~putAttribute("CONTEXT_IDENTITY", invocationEvidence~contextIdentity)
  action~putAttribute("INVOCATION_EVIDENCE_IDENTITY", invocationEvidence~semanticIdentity)
  return .SecurityResult~success(action)
/* Fresh invocation evidence prevents an earlier Security ALLOW from being
 * replayed against changed method arguments, a changed session context or a
 * later invocation.  This evidence is not authority and does not replace a
 * fresh Access Permissions decision. */
::class SecurityInvocationPolicy public
::attribute policyId get
::attribute version get
::attribute maximumAgeSeconds get
::attribute maximumFutureSkewSeconds get
::attribute requireArgumentIdentity get
::attribute requireContextIdentity get
::attribute singleUse get
::attribute authoredBy get
::attribute approvedBy get
::attribute sealed get
::method init
  expose policyId version maximumAgeSeconds maximumFutureSkewSeconds requireArgumentIdentity requireContextIdentity singleUse authoredBy approvedBy sealed
  use arg policyIdArg = "SECURITY-INVOCATION", versionArg = "1", maximumAgeSecondsArg = 30, maximumFutureSkewSecondsArg = 5, requireArgumentIdentityArg = .true, requireContextIdentityArg = .true, singleUseArg = .true, authoredByArg = "SECURITY", approvedByArg = "RISK"
  policyId = policyIdArg~string~upper
  version = versionArg~string
  maximumAgeSeconds = maximumAgeSecondsArg + 0
  maximumFutureSkewSeconds = maximumFutureSkewSecondsArg + 0
  requireArgumentIdentity = requireArgumentIdentityArg
  requireContextIdentity = requireContextIdentityArg
  singleUse = singleUseArg
  authoredBy = authoredByArg~string
  approvedBy = approvedByArg~string
  sealed = .false
::method publicationEligible
  expose sealed authoredBy approvedBy
  return sealed & authoredBy <> "" & approvedBy <> ""
::method seal
  expose policyId version maximumAgeSeconds maximumFutureSkewSeconds sealed
  if policyId = "" | version = "" then raise syntax 88.900 array("invocation policy identity required")
  if maximumAgeSeconds <= 0 then raise syntax 88.900 array("invocation maximum age must be positive")
  if maximumFutureSkewSeconds < 0 then raise syntax 88.900 array("invocation future skew cannot be negative")
  sealed = .true
  return self
::method canonicalText
  expose policyId version maximumAgeSeconds maximumFutureSkewSeconds requireArgumentIdentity requireContextIdentity singleUse authoredBy approvedBy sealed
  if \sealed then raise syntax 88.900 array("invocation policy must be sealed")
  text = "SECURITY-INVOCATION-POLICY/1" || '0a'x
  text ||= .SecurityCanonical~field("SCHEMA", .SecurityEffectBuild~INVOCATION_POLICY_SCHEMA)
  text ||= .SecurityCanonical~field("POLICY_ID", policyId)
  text ||= .SecurityCanonical~field("VERSION", version)
  text ||= .SecurityCanonical~field("MAXIMUM_AGE_SECONDS", maximumAgeSeconds)
  text ||= .SecurityCanonical~field("MAXIMUM_FUTURE_SKEW_SECONDS", maximumFutureSkewSeconds)
  text ||= .SecurityCanonical~field("REQUIRE_ARGUMENT_IDENTITY", requireArgumentIdentity)
  text ||= .SecurityCanonical~field("REQUIRE_CONTEXT_IDENTITY", requireContextIdentity)
  text ||= .SecurityCanonical~field("SINGLE_USE", singleUse)
  text ||= .SecurityCanonical~field("AUTHORED_BY", authoredBy)
  text ||= .SecurityCanonical~field("APPROVED_BY", approvedBy)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityInvocationEvidence public
::attribute invocationId get
::attribute argumentIdentity get
::attribute contextIdentity get
::attribute observedAt get
::attribute sealed get
::method init
  expose invocationId argumentIdentity contextIdentity observedAt sealed
  use arg invocationIdArg, argumentIdentityArg = "", contextIdentityArg = "", observedAtArg = .nil
  invocationId = invocationIdArg~string
  argumentIdentity = argumentIdentityArg~string
  contextIdentity = contextIdentityArg~string
  if observedAtArg == .nil then observedAt = .DateTime~new
  else observedAt = observedAtArg
  sealed = .false
::method seal
  expose invocationId sealed
  if invocationId = "" then raise syntax 88.900 array("invocation id required")
  sealed = .true
  return self
::method canonicalText
  expose invocationId argumentIdentity contextIdentity observedAt sealed
  if \sealed then raise syntax 88.900 array("invocation evidence must be sealed")
  text = "SECURITY-INVOCATION-EVIDENCE/1" || '0a'x
  text ||= .SecurityCanonical~field("SCHEMA", .SecurityEffectBuild~INVOCATION_BINDING_SCHEMA)
  text ||= .SecurityCanonical~field("INVOCATION_ID", invocationId)
  text ||= .SecurityCanonical~field("ARGUMENT_IDENTITY", argumentIdentity)
  text ||= .SecurityCanonical~field("CONTEXT_IDENTITY", contextIdentity)
  text ||= .SecurityCanonical~field("OBSERVED_AT", observedAt)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityInvocationValidation public
::attribute binding get
::attribute evidence get
::attribute policy get
::attribute validatedAt get
::attribute identity get
::method init
  expose binding evidence policy validatedAt identity
  use arg bindingArg, evidenceArg, policyArg, validatedAtArg
  binding = bindingArg
  evidence = evidenceArg
  policy = policyArg
  validatedAt = validatedAtArg
  identity = .SecurityCanonical~hash(self~canonicalText)
::method canonicalText
  expose binding evidence policy validatedAt
  text = "SECURITY-INVOCATION-VALIDATION/1" || '0a'x
  text ||= .SecurityCanonical~field("BINDING", binding~semanticIdentity)
  text ||= .SecurityCanonical~field("EVIDENCE", evidence~semanticIdentity)
  text ||= .SecurityCanonical~field("POLICY", policy~semanticIdentity)
  text ||= .SecurityCanonical~field("VALIDATED_AT", validatedAt)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityInvocationGuard public
::method init
  expose consumed
  consumed = .directory~new
::method validate
  expose consumed
  use arg binding, evidence, policy, atTime = .nil
  if binding == .nil then return .SecurityResult~failure("SECURITY_PERMISSION_BINDING_REQUIRED")
  if evidence == .nil then return .SecurityResult~failure("SECURITY_INVOCATION_EVIDENCE_REQUIRED")
  if policy == .nil then return .SecurityResult~failure("SECURITY_INVOCATION_POLICY_REQUIRED")
  if \evidence~sealed then return .SecurityResult~failure("SECURITY_INVOCATION_EVIDENCE_NOT_SEALED")
  if \policy~sealed then return .SecurityResult~failure("SECURITY_INVOCATION_POLICY_NOT_SEALED")
  if \policy~publicationEligible then return .SecurityResult~failure("SECURITY_INVOCATION_POLICY_NOT_APPROVED")
  if atTime == .nil then atTime = .DateTime~new
  if binding~invocationEvidenceIdentity = "" then return .SecurityResult~failure("SECURITY_INVOCATION_BINDING_REQUIRED")
  if binding~invocationEvidenceIdentity <> evidence~semanticIdentity then return .SecurityResult~failure("SECURITY_INVOCATION_EVIDENCE_MISMATCH")
  if binding~invocationId <> evidence~invocationId then return .SecurityResult~failure("SECURITY_INVOCATION_ID_MISMATCH")
  if binding~argumentIdentity <> evidence~argumentIdentity then return .SecurityResult~failure("SECURITY_INVOCATION_ARGUMENT_MISMATCH")
  if binding~contextIdentity <> evidence~contextIdentity then return .SecurityResult~failure("SECURITY_INVOCATION_CONTEXT_MISMATCH")
  if policy~requireArgumentIdentity & evidence~argumentIdentity = "" then return .SecurityResult~failure("SECURITY_INVOCATION_ARGUMENT_IDENTITY_REQUIRED")
  if policy~requireContextIdentity & evidence~contextIdentity = "" then return .SecurityResult~failure("SECURITY_INVOCATION_CONTEXT_IDENTITY_REQUIRED")
  futureSeconds = (evidence~observedAt - atTime)~totalSeconds
  if futureSeconds > policy~maximumFutureSkewSeconds then return .SecurityResult~failure("SECURITY_INVOCATION_FROM_FUTURE")
  ageSeconds = (atTime - evidence~observedAt)~totalSeconds
  if ageSeconds > policy~maximumAgeSeconds then return .SecurityResult~failure("SECURITY_INVOCATION_EXPIRED")
  key = binding~semanticIdentity
  if policy~singleUse & consumed~hasIndex(key) then return .SecurityResult~failure("SECURITY_INVOCATION_ALREADY_USED")
  return .SecurityResult~success(.SecurityInvocationValidation~new(binding, evidence, policy, atTime))
::method consume
  expose consumed
  use arg validation
  if validation == .nil then return .SecurityResult~failure("SECURITY_INVOCATION_VALIDATION_REQUIRED")
  key = validation~binding~semanticIdentity
  if validation~policy~singleUse & consumed~hasIndex(key) then return .SecurityResult~failure("SECURITY_INVOCATION_ALREADY_USED")
  consumed[key] = validation~semanticIdentity
  return .SecurityResult~success(validation)
::method used
  expose consumed
  use arg binding
  if binding == .nil then return .false
  return consumed~hasIndex(binding~semanticIdentity)

::class SecurityPermissionBinding public
::attribute subjectId get
::attribute objectId get
::attribute objectClass get
::attribute methodName get
::attribute intendedAt get
::attribute disposition get
::attribute securityPolicyIdentity get
::attribute securityTraceIdentity get
::attribute actionIdentity get
::attribute snapshotIdentity get
::attribute invocationId get
::attribute argumentIdentity get
::attribute contextIdentity get
::attribute invocationEvidenceIdentity get
::attribute assessment get
::method init
  expose subjectId objectId objectClass methodName intendedAt disposition securityPolicyIdentity securityTraceIdentity actionIdentity snapshotIdentity invocationId argumentIdentity contextIdentity invocationEvidenceIdentity assessment constraints
  use arg assessmentArg, objectIdArg, objectClassArg, methodNameArg
  assessment = assessmentArg
  subjectId = assessment~action~subjectId
  objectId = objectIdArg~string
  objectClass = objectClassArg~string~upper
  methodName = methodNameArg~string~upper
  intendedAt = assessment~action~intendedAt
  disposition = assessment~disposition~string~upper
  securityPolicyIdentity = assessment~policy~semanticIdentity
  securityTraceIdentity = assessment~trace~traceIdentity
  actionIdentity = assessment~action~canonicalText
  snapshotIdentity = assessment~snapshot~semanticIdentity
  invocationId = ""
  argumentIdentity = ""
  contextIdentity = ""
  invocationEvidenceIdentity = ""
  attr = assessment~action~attribute("INVOCATION_ID")
  if attr <> .nil then invocationId = attr~string
  attr = assessment~action~attribute("ARGUMENT_IDENTITY")
  if attr <> .nil then argumentIdentity = attr~string
  attr = assessment~action~attribute("CONTEXT_IDENTITY")
  if attr <> .nil then contextIdentity = attr~string
  attr = assessment~action~attribute("INVOCATION_EVIDENCE_IDENTITY")
  if attr <> .nil then invocationEvidenceIdentity = attr~string
  constraints = .array~new
  do constraint over assessment~constraints
    constraints~append(constraint~code~string~upper || ":" || constraint~scope~string~upper)
  end
::method constraints
  expose constraints
  return .SecurityCanonical~copyArray(constraints)
::method hasConstraint
  expose constraints
  use arg code, scope = "*"
  wantedCode = code~string~upper
  wantedScope = scope~string~upper
  do value over constraints
    split = value~pos(":")
    if split = 0 then iterate
    actualCode = value~left(split - 1)
    actualScope = value~substr(split + 1)
    if actualCode = wantedCode & (wantedScope = "*" | actualScope = wantedScope) then return .true
  end
  return .false
::method invocationBound
  expose invocationEvidenceIdentity
  return invocationEvidenceIdentity <> ""
::method canonicalText
  expose subjectId objectId objectClass methodName intendedAt disposition securityPolicyIdentity securityTraceIdentity actionIdentity snapshotIdentity invocationId argumentIdentity contextIdentity invocationEvidenceIdentity constraints
  text = "SECURITY-PERMISSION-BINDING/2" || '0a'x
  text ||= .SecurityCanonical~field("SCHEMA", .SecurityEffectBuild~INVOCATION_BINDING_SCHEMA)
  text ||= .SecurityCanonical~field("SUBJECT", subjectId)
  text ||= .SecurityCanonical~field("OBJECT_ID", objectId)
  text ||= .SecurityCanonical~field("OBJECT_CLASS", objectClass)
  text ||= .SecurityCanonical~field("METHOD", methodName)
  text ||= .SecurityCanonical~field("INTENDED_AT", intendedAt)
  text ||= .SecurityCanonical~field("DISPOSITION", disposition)
  text ||= .SecurityCanonical~field("SECURITY_POLICY_IDENTITY", securityPolicyIdentity)
  text ||= .SecurityCanonical~field("SECURITY_TRACE_IDENTITY", securityTraceIdentity)
  text ||= .SecurityCanonical~field("ACTION_IDENTITY", actionIdentity)
  text ||= .SecurityCanonical~field("SNAPSHOT_IDENTITY", snapshotIdentity)
  text ||= .SecurityCanonical~field("INVOCATION_ID", invocationId)
  text ||= .SecurityCanonical~field("ARGUMENT_IDENTITY", argumentIdentity)
  text ||= .SecurityCanonical~field("CONTEXT_IDENTITY", contextIdentity)
  text ||= .SecurityCanonical~field("INVOCATION_EVIDENCE_IDENTITY", invocationEvidenceIdentity)
  text ||= .SecurityCanonical~join("CONSTRAINT", constraints)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityPermissionBindingFactory public
::method fromAssessment class
  use arg assessment
  if assessment == .nil then return .SecurityResult~failure("SECURITY_ASSESSMENT_REQUIRED")
  action = assessment~action
  if action == .nil then return .SecurityResult~failure("SECURITY_ACTION_REQUIRED")
  if action~actionType <> "METHOD_INVOCATION" then return .SecurityResult~failure("SECURITY_ACTION_NOT_METHOD_INVOCATION")
  objectId = action~attribute("OBJECT_ID")
  objectClass = action~attribute("OBJECT_CLASS")
  methodName = action~attribute("METHOD")
  if objectId == .nil | objectClass == .nil | methodName == .nil then return .SecurityResult~failure("SECURITY_METHOD_BINDING_INCOMPLETE")
  if objectId~string = "" | objectClass~string = "" | methodName~string = "" then return .SecurityResult~failure("SECURITY_METHOD_BINDING_INCOMPLETE")
  return .SecurityResult~success(.SecurityPermissionBinding~new(assessment, objectId, objectClass, methodName))
::method fromInvocationAssessment class
  use arg assessment
  result = self~fromAssessment(assessment)
  if \result~ok then return result
  if \result~value~invocationBound then return .SecurityResult~failure("SECURITY_INVOCATION_BINDING_REQUIRED")
  return result

/* ------------------------------------------------------------------------- */
/* v0.14 continuation / irreversible-commit revalidation                     */
/* ------------------------------------------------------------------------- */

/* A continuation is evidence that an already-admitted invocation opened a
 * longer-lived operation.  It is not Permission authority and is not itself
 * sufficient to commit anything. */
::class SecurityContinuationPolicy public
::attribute policyId get
::attribute version get
::attribute maximumContinuationAgeSeconds get
::attribute maximumCommitEvidenceAgeSeconds get
::attribute maximumFutureSkewSeconds get
::attribute requireStateIdentity get
::attribute requireContextIdentity get
::attribute singleUseCommit get
::attribute authoredBy get
::attribute approvedBy get
::attribute sealed get
::method init
  expose policyId version maximumContinuationAgeSeconds maximumCommitEvidenceAgeSeconds maximumFutureSkewSeconds requireStateIdentity requireContextIdentity singleUseCommit authoredBy approvedBy sealed
  use arg policyIdArg = "SECURITY-CONTINUATION", versionArg = "1", maximumContinuationAgeSecondsArg = 300, maximumCommitEvidenceAgeSecondsArg = 10, maximumFutureSkewSecondsArg = 5, requireStateIdentityArg = .true, requireContextIdentityArg = .true, singleUseCommitArg = .true, authoredByArg = "SECURITY", approvedByArg = "RISK"
  policyId = policyIdArg~string~upper
  version = versionArg~string
  maximumContinuationAgeSeconds = maximumContinuationAgeSecondsArg + 0
  maximumCommitEvidenceAgeSeconds = maximumCommitEvidenceAgeSecondsArg + 0
  maximumFutureSkewSeconds = maximumFutureSkewSecondsArg + 0
  requireStateIdentity = requireStateIdentityArg
  requireContextIdentity = requireContextIdentityArg
  singleUseCommit = singleUseCommitArg
  authoredBy = authoredByArg~string
  approvedBy = approvedByArg~string
  sealed = .false
::method publicationEligible
  expose sealed authoredBy approvedBy
  return sealed & authoredBy <> "" & approvedBy <> ""
::method seal
  expose policyId version maximumContinuationAgeSeconds maximumCommitEvidenceAgeSeconds maximumFutureSkewSeconds sealed
  if policyId = "" | version = "" then raise syntax 88.900 array("continuation policy identity required")
  if maximumContinuationAgeSeconds <= 0 then raise syntax 88.900 array("continuation maximum age must be positive")
  if maximumCommitEvidenceAgeSeconds <= 0 then raise syntax 88.900 array("commit evidence maximum age must be positive")
  if maximumFutureSkewSeconds < 0 then raise syntax 88.900 array("continuation future skew cannot be negative")
  sealed = .true
  return self
::method canonicalText
  expose policyId version maximumContinuationAgeSeconds maximumCommitEvidenceAgeSeconds maximumFutureSkewSeconds requireStateIdentity requireContextIdentity singleUseCommit authoredBy approvedBy sealed
  if \sealed then raise syntax 88.900 array("continuation policy must be sealed")
  text = "SECURITY-CONTINUATION-POLICY/1" || '0a'x
  text ||= .SecurityCanonical~field("SCHEMA", .SecurityEffectBuild~CONTINUATION_POLICY_SCHEMA)
  text ||= .SecurityCanonical~field("POLICY_ID", policyId)
  text ||= .SecurityCanonical~field("VERSION", version)
  text ||= .SecurityCanonical~field("MAXIMUM_CONTINUATION_AGE_SECONDS", maximumContinuationAgeSeconds)
  text ||= .SecurityCanonical~field("MAXIMUM_COMMIT_EVIDENCE_AGE_SECONDS", maximumCommitEvidenceAgeSeconds)
  text ||= .SecurityCanonical~field("MAXIMUM_FUTURE_SKEW_SECONDS", maximumFutureSkewSeconds)
  text ||= .SecurityCanonical~field("REQUIRE_STATE_IDENTITY", requireStateIdentity)
  text ||= .SecurityCanonical~field("REQUIRE_CONTEXT_IDENTITY", requireContextIdentity)
  text ||= .SecurityCanonical~field("SINGLE_USE_COMMIT", singleUseCommit)
  text ||= .SecurityCanonical~field("AUTHORED_BY", authoredBy)
  text ||= .SecurityCanonical~field("APPROVED_BY", approvedBy)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityContinuationEvidence public
::attribute continuationId get
::attribute subjectId get
::attribute originBindingIdentity get
::attribute originExecutionEvidenceIdentity get
::attribute operationId get
::attribute operationIntentIdentity get
::attribute contextIdentity get
::attribute openedAt get
::attribute sealed get
::method init
  expose continuationId subjectId originBindingIdentity originExecutionEvidenceIdentity operationId operationIntentIdentity contextIdentity openedAt sealed
  use arg continuationIdArg, subjectIdArg, originBindingIdentityArg, originExecutionEvidenceIdentityArg, operationIdArg, operationIntentIdentityArg = "", contextIdentityArg = "", openedAtArg = .nil
  continuationId = continuationIdArg~string
  subjectId = subjectIdArg~string
  originBindingIdentity = originBindingIdentityArg~string
  if originExecutionEvidenceIdentityArg == .nil then originExecutionEvidenceIdentity = ""
  else originExecutionEvidenceIdentity = originExecutionEvidenceIdentityArg~string
  operationId = operationIdArg~string
  operationIntentIdentity = operationIntentIdentityArg~string
  contextIdentity = contextIdentityArg~string
  if openedAtArg == .nil then openedAt = .DateTime~new
  else openedAt = openedAtArg
  sealed = .false
::method seal
  expose continuationId subjectId originBindingIdentity originExecutionEvidenceIdentity operationId sealed
  if continuationId = "" | subjectId = "" | originBindingIdentity = "" | originExecutionEvidenceIdentity = "" | operationId = "" then raise syntax 88.900 array("continuation identity and origin execution evidence required")
  sealed = .true
  return self
::method canonicalText
  expose continuationId subjectId originBindingIdentity originExecutionEvidenceIdentity operationId operationIntentIdentity contextIdentity openedAt sealed
  if \sealed then raise syntax 88.900 array("continuation evidence must be sealed")
  text = "SECURITY-CONTINUATION-EVIDENCE/1" || '0a'x
  text ||= .SecurityCanonical~field("SCHEMA", .SecurityEffectBuild~CONTINUATION_BINDING_SCHEMA)
  text ||= .SecurityCanonical~field("CONTINUATION_ID", continuationId)
  text ||= .SecurityCanonical~field("SUBJECT", subjectId)
  text ||= .SecurityCanonical~field("ORIGIN_BINDING_IDENTITY", originBindingIdentity)
  text ||= .SecurityCanonical~field("ORIGIN_EXECUTION_EVIDENCE_IDENTITY", originExecutionEvidenceIdentity)
  text ||= .SecurityCanonical~field("OPERATION_ID", operationId)
  text ||= .SecurityCanonical~field("OPERATION_INTENT_IDENTITY", operationIntentIdentity)
  text ||= .SecurityCanonical~field("CONTEXT_IDENTITY", contextIdentity)
  text ||= .SecurityCanonical~field("OPENED_AT", openedAt)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityContinuationFactory public
::method open class
  use arg invocationValidation, continuationId, originExecutionEvidenceIdentity, operationId, operationIntentIdentity = "", contextIdentity = "", openedAt = .nil
  if invocationValidation == .nil then return .SecurityResult~failure("SECURITY_INVOCATION_VALIDATION_REQUIRED")
  if \invocationValidation~hasMethod("BINDING") then return .SecurityResult~failure("SECURITY_INVOCATION_VALIDATION_INVALID")
  binding = invocationValidation~binding
  if binding == .nil | \binding~invocationBound then return .SecurityResult~failure("SECURITY_INVOCATION_BINDING_REQUIRED")
  if continuationId~string = "" | operationId~string = "" then return .SecurityResult~failure("SECURITY_CONTINUATION_IDENTITY_REQUIRED")
  if originExecutionEvidenceIdentity == .nil then return .SecurityResult~failure("SECURITY_ORIGIN_EXECUTION_EVIDENCE_REQUIRED")
  if originExecutionEvidenceIdentity~string = "" then return .SecurityResult~failure("SECURITY_ORIGIN_EXECUTION_EVIDENCE_REQUIRED")
  if openedAt == .nil then openedAt = invocationValidation~validatedAt
  if contextIdentity~string = "" then contextIdentity = binding~contextIdentity
  evidence = .SecurityContinuationEvidence~new(continuationId, binding~subjectId, binding~semanticIdentity, originExecutionEvidenceIdentity, operationId, operationIntentIdentity, contextIdentity, openedAt)~seal
  return .SecurityResult~success(evidence)

::class SecurityCommitEvidence public
::attribute commitId get
::attribute continuationIdentity get
::attribute operationId get
::attribute stagedStateIdentity get
::attribute contextIdentity get
::attribute observedAt get
::attribute sealed get
::method init
  expose commitId continuationIdentity operationId stagedStateIdentity contextIdentity observedAt sealed
  use arg commitIdArg, continuationIdentityArg, operationIdArg, stagedStateIdentityArg = "", contextIdentityArg = "", observedAtArg = .nil
  commitId = commitIdArg~string
  continuationIdentity = continuationIdentityArg~string
  operationId = operationIdArg~string
  stagedStateIdentity = stagedStateIdentityArg~string
  contextIdentity = contextIdentityArg~string
  if observedAtArg == .nil then observedAt = .DateTime~new
  else observedAt = observedAtArg
  sealed = .false
::method seal
  expose commitId continuationIdentity operationId sealed
  if commitId = "" | continuationIdentity = "" | operationId = "" then raise syntax 88.900 array("commit evidence identity required")
  sealed = .true
  return self
::method canonicalText
  expose commitId continuationIdentity operationId stagedStateIdentity contextIdentity observedAt sealed
  if \sealed then raise syntax 88.900 array("commit evidence must be sealed")
  text = "SECURITY-COMMIT-EVIDENCE/1" || '0a'x
  text ||= .SecurityCanonical~field("SCHEMA", .SecurityEffectBuild~CONTINUATION_BINDING_SCHEMA)
  text ||= .SecurityCanonical~field("COMMIT_ID", commitId)
  text ||= .SecurityCanonical~field("CONTINUATION_IDENTITY", continuationIdentity)
  text ||= .SecurityCanonical~field("OPERATION_ID", operationId)
  text ||= .SecurityCanonical~field("STAGED_STATE_IDENTITY", stagedStateIdentity)
  text ||= .SecurityCanonical~field("CONTEXT_IDENTITY", contextIdentity)
  text ||= .SecurityCanonical~field("OBSERVED_AT", observedAt)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityCommitActionFactory public
::method createInvocation class
  use arg actionId, continuation, commitEvidence, objectId, objectClass, methodName, invocationEvidence, intendedAt = .nil, consequenceClass = "HIGH", capabilityId = ""
  if continuation == .nil | \continuation~sealed then return .SecurityResult~failure("SECURITY_CONTINUATION_EVIDENCE_REQUIRED")
  if commitEvidence == .nil | \commitEvidence~sealed then return .SecurityResult~failure("SECURITY_COMMIT_EVIDENCE_REQUIRED")
  if commitEvidence~continuationIdentity <> continuation~semanticIdentity then return .SecurityResult~failure("SECURITY_COMMIT_CONTINUATION_MISMATCH")
  if commitEvidence~operationId <> continuation~operationId then return .SecurityResult~failure("SECURITY_COMMIT_OPERATION_MISMATCH")
  base = .SecurityMethodActionFactory~createInvocation(actionId, continuation~subjectId, objectId, objectClass, methodName, invocationEvidence, intendedAt, consequenceClass, capabilityId)
  if \base~ok then return base
  action = base~value
  action~putAttribute("SECURITY_PHASE", "COMMIT")
  action~putAttribute("CONTINUATION_ID", continuation~continuationId)
  action~putAttribute("CONTINUATION_IDENTITY", continuation~semanticIdentity)
  action~putAttribute("ORIGIN_BINDING_IDENTITY", continuation~originBindingIdentity)
  action~putAttribute("ORIGIN_EXECUTION_EVIDENCE_IDENTITY", continuation~originExecutionEvidenceIdentity)
  action~putAttribute("OPERATION_ID", continuation~operationId)
  action~putAttribute("OPERATION_INTENT_IDENTITY", continuation~operationIntentIdentity)
  action~putAttribute("STAGED_STATE_IDENTITY", commitEvidence~stagedStateIdentity)
  action~putAttribute("CONTINUATION_CONTEXT_IDENTITY", commitEvidence~contextIdentity)
  action~putAttribute("COMMIT_EVIDENCE_IDENTITY", commitEvidence~semanticIdentity)
  return .SecurityResult~success(action)

::class SecurityCommitValidation public
::attribute originBinding get
::attribute continuation get
::attribute commitEvidence get
::attribute commitBinding get
::attribute assessment get
::attribute policy get
::attribute validatedAt get
::attribute liveStateIdentity get
::attribute liveContextIdentity get
::attribute identity get
::method init
  expose originBinding continuation commitEvidence commitBinding assessment policy validatedAt liveStateIdentity liveContextIdentity identity
  use arg originBindingArg, continuationArg, commitEvidenceArg, commitBindingArg, assessmentArg, policyArg, validatedAtArg, liveStateIdentityArg, liveContextIdentityArg
  originBinding = originBindingArg
  continuation = continuationArg
  commitEvidence = commitEvidenceArg
  commitBinding = commitBindingArg
  assessment = assessmentArg
  policy = policyArg
  validatedAt = validatedAtArg
  liveStateIdentity = liveStateIdentityArg~string
  liveContextIdentity = liveContextIdentityArg~string
  identity = .SecurityCanonical~hash(self~canonicalText)
::method canonicalText
  expose originBinding continuation commitEvidence commitBinding assessment policy validatedAt liveStateIdentity liveContextIdentity
  text = "SECURITY-COMMIT-VALIDATION/1" || '0a'x
  text ||= .SecurityCanonical~field("ORIGIN_BINDING", originBinding~semanticIdentity)
  text ||= .SecurityCanonical~field("CONTINUATION", continuation~semanticIdentity)
  text ||= .SecurityCanonical~field("COMMIT_EVIDENCE", commitEvidence~semanticIdentity)
  text ||= .SecurityCanonical~field("COMMIT_BINDING", commitBinding~semanticIdentity)
  text ||= .SecurityCanonical~field("ASSESSMENT_TRACE", assessment~trace~traceIdentity)
  text ||= .SecurityCanonical~field("POLICY", policy~semanticIdentity)
  text ||= .SecurityCanonical~field("VALIDATED_AT", validatedAt)
  text ||= .SecurityCanonical~field("LIVE_STATE_IDENTITY", liveStateIdentity)
  text ||= .SecurityCanonical~field("LIVE_CONTEXT_IDENTITY", liveContextIdentity)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityContinuationGuard public
::method init
  expose consumed
  consumed = .directory~new
::method validateCommit
  expose consumed
  use arg originBinding, continuation, commitEvidence, commitAssessment, policy, atTime = .nil, liveStateIdentity = "", liveContextIdentity = ""
  if originBinding == .nil then return .SecurityResult~failure("SECURITY_ORIGIN_BINDING_REQUIRED")
  if continuation == .nil then return .SecurityResult~failure("SECURITY_CONTINUATION_EVIDENCE_REQUIRED")
  if commitEvidence == .nil then return .SecurityResult~failure("SECURITY_COMMIT_EVIDENCE_REQUIRED")
  if commitAssessment == .nil then return .SecurityResult~failure("SECURITY_COMMIT_ASSESSMENT_REQUIRED")
  if policy == .nil then return .SecurityResult~failure("SECURITY_CONTINUATION_POLICY_REQUIRED")
  if \originBinding~invocationBound then return .SecurityResult~failure("SECURITY_INVOCATION_BINDING_REQUIRED")
  if \continuation~sealed then return .SecurityResult~failure("SECURITY_CONTINUATION_EVIDENCE_NOT_SEALED")
  if \commitEvidence~sealed then return .SecurityResult~failure("SECURITY_COMMIT_EVIDENCE_NOT_SEALED")
  if \policy~sealed then return .SecurityResult~failure("SECURITY_CONTINUATION_POLICY_NOT_SEALED")
  if \policy~publicationEligible then return .SecurityResult~failure("SECURITY_CONTINUATION_POLICY_NOT_APPROVED")
  if atTime == .nil then atTime = .DateTime~new
  if continuation~originBindingIdentity <> originBinding~semanticIdentity then return .SecurityResult~failure("SECURITY_CONTINUATION_ORIGIN_MISMATCH")
  if continuation~subjectId <> originBinding~subjectId then return .SecurityResult~failure("SECURITY_CONTINUATION_SUBJECT_MISMATCH")
  if commitEvidence~continuationIdentity <> continuation~semanticIdentity then return .SecurityResult~failure("SECURITY_COMMIT_CONTINUATION_MISMATCH")
  if commitEvidence~operationId <> continuation~operationId then return .SecurityResult~failure("SECURITY_COMMIT_OPERATION_MISMATCH")
  action = commitAssessment~action
  if action == .nil | action~actionType <> "METHOD_INVOCATION" then return .SecurityResult~failure("SECURITY_COMMIT_ACTION_REQUIRED")
  phase = action~attribute("SECURITY_PHASE")
  if phase == .nil | phase~string~upper <> "COMMIT" then return .SecurityResult~failure("SECURITY_COMMIT_ACTION_REQUIRED")
  if action~subjectId <> continuation~subjectId then return .SecurityResult~failure("SECURITY_COMMIT_SUBJECT_MISMATCH")
  if action~attribute("CONTINUATION_IDENTITY") <> continuation~semanticIdentity then return .SecurityResult~failure("SECURITY_COMMIT_ACTION_CONTINUATION_MISMATCH")
  if action~attribute("ORIGIN_EXECUTION_EVIDENCE_IDENTITY") <> continuation~originExecutionEvidenceIdentity then return .SecurityResult~failure("SECURITY_COMMIT_ACTION_ORIGIN_EXECUTION_MISMATCH")
  if action~attribute("COMMIT_EVIDENCE_IDENTITY") <> commitEvidence~semanticIdentity then return .SecurityResult~failure("SECURITY_COMMIT_ACTION_EVIDENCE_MISMATCH")
  if action~attribute("OPERATION_ID") <> continuation~operationId then return .SecurityResult~failure("SECURITY_COMMIT_ACTION_OPERATION_MISMATCH")
  if commitAssessment~snapshot~capturedAt < continuation~openedAt then return .SecurityResult~failure("SECURITY_COMMIT_SNAPSHOT_PRECEDES_CONTINUATION")
  if commitAssessment~snapshot~capturedAt < commitEvidence~observedAt then return .SecurityResult~failure("SECURITY_COMMIT_SNAPSHOT_STALE")
  if commitAssessment~disposition <> .SecurityConstant~DISP_ALLOW then return .SecurityResult~failure("SECURITY_COMMIT_NOT_ALLOWED", commitAssessment~disposition)
  futureOpen = (continuation~openedAt - atTime)~totalSeconds
  if futureOpen > policy~maximumFutureSkewSeconds then return .SecurityResult~failure("SECURITY_CONTINUATION_FROM_FUTURE")
  continuationAge = (atTime - continuation~openedAt)~totalSeconds
  if continuationAge > policy~maximumContinuationAgeSeconds then return .SecurityResult~failure("SECURITY_CONTINUATION_EXPIRED")
  futureCommit = (commitEvidence~observedAt - atTime)~totalSeconds
  if futureCommit > policy~maximumFutureSkewSeconds then return .SecurityResult~failure("SECURITY_COMMIT_EVIDENCE_FROM_FUTURE")
  commitAge = (atTime - commitEvidence~observedAt)~totalSeconds
  if commitAge > policy~maximumCommitEvidenceAgeSeconds then return .SecurityResult~failure("SECURITY_COMMIT_EVIDENCE_EXPIRED")
  if policy~requireStateIdentity & commitEvidence~stagedStateIdentity = "" then return .SecurityResult~failure("SECURITY_COMMIT_STATE_IDENTITY_REQUIRED")
  if policy~requireStateIdentity & liveStateIdentity~string = "" then return .SecurityResult~failure("SECURITY_COMMIT_LIVE_STATE_IDENTITY_REQUIRED")
  if liveStateIdentity~string <> "" & commitEvidence~stagedStateIdentity <> liveStateIdentity~string then return .SecurityResult~failure("SECURITY_COMMIT_STATE_MISMATCH")
  if action~attribute("STAGED_STATE_IDENTITY") <> commitEvidence~stagedStateIdentity then return .SecurityResult~failure("SECURITY_COMMIT_ACTION_STATE_MISMATCH")
  if policy~requireContextIdentity & commitEvidence~contextIdentity = "" then return .SecurityResult~failure("SECURITY_COMMIT_CONTEXT_IDENTITY_REQUIRED")
  if policy~requireContextIdentity & liveContextIdentity~string = "" then return .SecurityResult~failure("SECURITY_COMMIT_LIVE_CONTEXT_IDENTITY_REQUIRED")
  if liveContextIdentity~string <> "" & commitEvidence~contextIdentity <> liveContextIdentity~string then return .SecurityResult~failure("SECURITY_COMMIT_CONTEXT_MISMATCH")
  commitBindingResult = .SecurityPermissionBindingFactory~fromInvocationAssessment(commitAssessment)
  if \commitBindingResult~ok then return commitBindingResult
  commitBinding = commitBindingResult~value
  key = continuation~semanticIdentity
  if policy~singleUseCommit & consumed~hasIndex(key) then return .SecurityResult~failure("SECURITY_CONTINUATION_ALREADY_COMMITTED")
  validation = .SecurityCommitValidation~new(originBinding, continuation, commitEvidence, commitBinding, commitAssessment, policy, atTime, liveStateIdentity, liveContextIdentity)
  return .SecurityResult~success(validation)
::method consume
  expose consumed
  use arg validation
  if validation == .nil then return .SecurityResult~failure("SECURITY_COMMIT_VALIDATION_REQUIRED")
  key = validation~continuation~semanticIdentity
  if validation~policy~singleUseCommit & consumed~hasIndex(key) then return .SecurityResult~failure("SECURITY_CONTINUATION_ALREADY_COMMITTED")
  consumed[key] = validation~semanticIdentity
  return .SecurityResult~success(validation)
::method consumeWithInvocation
  expose consumed
  use arg validation, invocationGuard, invocationValidation
  if validation == .nil then return .SecurityResult~failure("SECURITY_COMMIT_VALIDATION_REQUIRED")
  if invocationGuard == .nil | invocationValidation == .nil then return .SecurityResult~failure("SECURITY_INVOCATION_VALIDATION_REQUIRED")
  key = validation~continuation~semanticIdentity
  if validation~policy~singleUseCommit & consumed~hasIndex(key) then return .SecurityResult~failure("SECURITY_CONTINUATION_ALREADY_COMMITTED")
  if invocationGuard~used(invocationValidation~binding) then return .SecurityResult~failure("SECURITY_INVOCATION_ALREADY_USED")
  consumed[key] = validation~semanticIdentity
  invocationConsumed = invocationGuard~consume(invocationValidation)
  if \invocationConsumed~ok then return .SecurityResult~failure("SECURITY_COMMIT_CONSUMPTION_FAILED_CLOSED", invocationConsumed~code)
  return .SecurityResult~success(validation)
::method committed
  expose consumed
  use arg continuation
  if continuation == .nil then return .false
  return consumed~hasIndex(continuation~semanticIdentity)

::requires 'InstitutionalPolicy.cls'
::requires 'AlchemyObject.cls'
