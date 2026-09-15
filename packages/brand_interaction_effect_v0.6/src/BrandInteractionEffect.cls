/*
 * Brand Interaction Effect v0.6
 *
 * Models customer-facing service, delivery, sales and recovery as one brand
 * experience.  It deliberately distinguishes observed events from assessed
 * communication style and from causal hypotheses.  The core model stores
 * controlled semantic residue and point references, not raw customer text.
 */

::class BrandInteractionBuild public
::constant VERSION "0.6"
::constant API_VERSION "brand.interaction.effect/0.6"
::constant PRODUCT "ooRexx Brand Interaction Effect"

::class BrandInteractionConstant public
/* polarity / disposition */
::constant CONCERN "CONCERN"
::constant SUPPORT "SUPPORT"
::constant OPPORTUNITY "OPPORTUNITY"
::constant INFO "INFO"
::constant CLEAR "CLEAR"
::constant WARN "WARN"
::constant REVIEW "REVIEW"
::constant HOLD "HOLD"

/* causal status */
::constant CAUSAL_NONE "NONE"
::constant CAUSAL_ASSOCIATED "ASSOCIATED"
::constant CAUSAL_CANDIDATE "CANDIDATE_NOT_PROVEN"
::constant CAUSAL_ESTABLISHED "ESTABLISHED_BY_EXTERNAL_AUTHORITY"

/* service-as-sales / brand findings */
::constant FIND_BRAND_TOUCHPOINT "BRAND_EXPERIENCE_TOUCHPOINT"
::constant FIND_SERVICE_AS_SALES "SERVICE_AS_SALES_TOUCHPOINT"
::constant FIND_STYLE_EXIT "STYLE_COMMERCIAL_EXIT_ASSOCIATION"
::constant FIND_RELATIONAL_TERMINATION "INTERPERSONAL_TERMINATION_REGISTER"
::constant FIND_SECURITY_SALES "SECURITY_SALES_COLLISION"
::constant FIND_SENSITIVE_COMMERCIAL_REPURPOSING "SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING"
::constant FIND_DECLARED_USE_MISMATCH "DECLARED_INFORMATION_USE_MISMATCH"
::constant FIND_RECOVERY "SERVICE_RECOVERY_SUPPORT"
::constant FIND_NEGATIVE_STATE "CUSTOMER_NEGATIVE_STATE_PRESENT"
::constant FIND_DISENGAGEMENT "POSSIBLE_DISENGAGEMENT"

/* mechanisms */
::constant MECH_DISMISSIVENESS "CUSTOMER_PERCEIVED_DISMISSIVENESS"
::constant MECH_RELATIONAL_TERMINATION "RELATIONAL_TERMINATION"
::constant MECH_TRUST_EROSION "TRUST_EROSION"
::constant MECH_COMMERCIAL_PRESSURE "INAPPROPRIATE_COMMERCIAL_PRESSURE"
::constant MECH_TRUST_RECOVERY "TRUST_RECOVERY"
::constant MECH_SERVICE_RECOVERY "SERVICE_RECOVERY"

/* outcomes */
::constant OUTCOME_COMMERCIAL_EXIT "COMMERCIAL_EXIT"
::constant OUTCOME_DISENGAGEMENT "DISENGAGEMENT"
::constant OUTCOME_RELATIONSHIP_PRESERVED "RELATIONSHIP_PRESERVED"

/* assessment types mirrored from Interaction Event without depending on it */
::constant ASSESS_SENTIMENT "CUSTOMER_SENTIMENT"
::constant ASSESS_STYLE "COMMUNICATION_STYLE"
::constant ASSESS_ENGAGEMENT "ENGAGEMENT_STATE"

::class BrandInteractionResult public
::attribute ok get
::attribute value get
::attribute code get
::attribute detail get
::method init
  expose ok value code detail
  use arg okArg, valueArg = .nil, codeArg = "", detailArg = ""
  ok = okArg; value = valueArg; code = codeArg; detail = detailArg
::method success class
  use arg value = .nil, detail = ""
  return self~new(.true, value, "OK", detail)
::method failure class
  use arg code, detail = ""
  return self~new(.false, .nil, code, detail)

::class BrandInteractionCanonical public
::method token class
  use arg value
  s = value~string~upper~strip
  if s = "" then return ""
  if verify(s, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-/:@") <> 0 then return ""
  return s
::method clamp class
  use arg value
  if \datatype(value, "N") then return 0
  if value < 0 then return 0
  if value > 100 then return 100
  return value + 0
::method copyArray class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source; out~append(item); end
  return out
::method copyTable class
  use arg source
  out = .table~new
  if source == .nil then return out
  do k over source; out[k] = source[k]; end
  return out
::method contains class
  use arg source, value
  do item over source
    if item~string == value~string then return .true
  end
  return .false
::method field class
  use arg name, value
  return name || "=" || value~string || d2c(10)
::method join class
  use arg name, source
  out = ""
  do item over source; out ||= self~field(name, item); end
  return out

/* Immutable assessment provenance.  Multiple assessors may disagree; the
   observation keeps each result rather than rewriting history to the latest. */
::class BrandAssessmentRecord public
::attribute assessmentId get
::attribute assessmentType get
::attribute value get
::attribute assessorKind get
::attribute assessorId get
::attribute modelId get
::attribute confidence get
::method init
  expose assessmentId assessmentType value assessorKind assessorId modelId confidence
  use arg assessmentIdArg, assessmentTypeArg, valueArg, assessorKindArg = "ASSESSOR", assessorIdArg = "UNSPECIFIED", modelIdArg = "UNSPECIFIED", confidenceArg = 0
  assessmentId=assessmentIdArg~string
  assessmentType=.BrandInteractionCanonical~token(assessmentTypeArg)
  value=.BrandInteractionCanonical~token(valueArg)
  assessorKind=.BrandInteractionCanonical~token(assessorKindArg)
  assessorId=.BrandInteractionCanonical~token(assessorIdArg)
  modelId=.BrandInteractionCanonical~token(modelIdArg)
  confidence=.BrandInteractionCanonical~clamp(confidenceArg)
  if assessmentId="" | assessmentType="" | value="" | assessorKind="" | assessorId="" | modelId="" then raise syntax 88.980 array("BrandAssessmentRecord requires controlled provenance")
::method pointId
  expose assessmentId
  return "BRAND_INTERACTION:ASSESSMENT:"||assessmentId
::method canonicalText
  expose assessmentId assessmentType value assessorKind assessorId modelId confidence
  out=.BrandInteractionCanonical~field("ASSESSMENT_ID",assessmentId)
  out||=.BrandInteractionCanonical~field("ASSESSMENT_TYPE",assessmentType)
  out||=.BrandInteractionCanonical~field("ASSESSMENT_VALUE",value)
  out||=.BrandInteractionCanonical~field("ASSESSOR_KIND",assessorKind)
  out||=.BrandInteractionCanonical~field("ASSESSOR_ID",assessorId)
  out||=.BrandInteractionCanonical~field("MODEL_ID",modelId)
  out||=.BrandInteractionCanonical~field("ASSESSMENT_CONFIDENCE",confidence)
  return out

/* A privacy-minimised semantic observation.  No raw customer utterance text,
   actor name, account id, address, or free-form model explanation belongs here. */
::class BrandInteractionObservation public
::attribute observationId get
::attribute sourceEventId get
::attribute eventKind get
::attribute pointId get
::attribute surface get
::attribute direction get
::attribute occurredAt get
::attribute sealed get
::method init
  expose observationId sourceEventId eventKind pointId surface direction occurredAt tags purposes assessmentValues assessmentRecords dimensions evidencePoints sealed
  use arg observationIdArg, sourceEventIdArg, eventKindArg, pointIdArg, surfaceArg = "", directionArg = "", occurredAtArg = .nil
  observationId = observationIdArg~string
  sourceEventId = sourceEventIdArg~string
  eventKind = .BrandInteractionCanonical~token(eventKindArg)
  pointId = pointIdArg~string
  surface = .BrandInteractionCanonical~token(surfaceArg)
  direction = .BrandInteractionCanonical~token(directionArg)
  if occurredAtArg == .nil then occurredAt = .DateTime~new; else occurredAt = occurredAtArg
  if observationId = "" | eventKind = "" | pointId = "" then raise syntax 88.981 array("BrandInteractionObservation requires id, event kind, and point")
  tags = .array~new
  purposes = .array~new
  assessmentValues = .table~new
  assessmentRecords = .array~new
  dimensions = .table~new
  evidencePoints = .array~new
  sealed = .false
::method addTag
  expose tags sealed
  use arg value
  if sealed then return .false
  t = .BrandInteractionCanonical~token(value)
  if t = "" then return .false
  if \.BrandInteractionCanonical~contains(tags,t) then tags~append(t)
  return .true
::method addPurpose
  expose purposes sealed
  use arg value
  if sealed then return .false
  t = .BrandInteractionCanonical~token(value)
  if t = "" then return .false
  if \.BrandInteractionCanonical~contains(purposes,t) then purposes~append(t)
  return .true
::method putAssessment
  expose assessmentValues sealed
  use arg assessmentTypeArg, valueArg
  if sealed then return .false
  t = .BrandInteractionCanonical~token(assessmentTypeArg)
  v = .BrandInteractionCanonical~token(valueArg)
  if t = "" | v = "" then return .false
  assessmentValues[t] = v
  return .true
::method addAssessmentRecord
  expose assessmentRecords sealed
  use arg record
  if sealed then return .false
  if record==.nil then return .false
  assessmentRecords~append(record)
  return .true
::method assessmentRecords
  expose assessmentRecords
  return .BrandInteractionCanonical~copyArray(assessmentRecords)
::method putDimension
  expose dimensions sealed
  use arg nameArg, valueArg
  if sealed then return .false
  n = .BrandInteractionCanonical~token(nameArg)
  if n = "" | \datatype(valueArg,"N") then return .false
  dimensions[n] = .BrandInteractionCanonical~clamp(valueArg)
  return .true
::method addEvidencePoint
  expose evidencePoints sealed
  use arg value
  if sealed | value~string = "" then return .false
  if \.BrandInteractionCanonical~contains(evidencePoints,value~string) then evidencePoints~append(value~string)
  return .true
::method tags
  expose tags
  return .BrandInteractionCanonical~copyArray(tags)
::method purposes
  expose purposes
  return .BrandInteractionCanonical~copyArray(purposes)
::method assessmentValues
  expose assessmentValues
  return .BrandInteractionCanonical~copyTable(assessmentValues)
::method dimensions
  expose dimensions
  return .BrandInteractionCanonical~copyTable(dimensions)
::method evidencePoints
  expose evidencePoints
  return .BrandInteractionCanonical~copyArray(evidencePoints)
::method hasTag
  expose tags
  use arg value
  return .BrandInteractionCanonical~contains(tags, .BrandInteractionCanonical~token(value))
::method hasPurpose
  expose purposes
  use arg value
  return .BrandInteractionCanonical~contains(purposes, .BrandInteractionCanonical~token(value))
::method assessmentValue
  expose assessmentValues
  use arg typeArg
  t = .BrandInteractionCanonical~token(typeArg)
  if assessmentValues~hasIndex(t) then return assessmentValues[t]
  return ""
::method dimension
  expose dimensions
  use arg nameArg, defaultArg = 0
  n = .BrandInteractionCanonical~token(nameArg)
  if dimensions~hasIndex(n) then return dimensions[n]
  return defaultArg
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose observationId sourceEventId eventKind pointId surface direction occurredAt tags purposes assessmentValues assessmentRecords dimensions evidencePoints sealed
  if \sealed then raise syntax 93.981 additional("BrandInteractionObservation must be sealed")
  out = .BrandInteractionCanonical~field("OBSERVATION", observationId)
  out ||= .BrandInteractionCanonical~field("SOURCE_EVENT", sourceEventId)
  out ||= .BrandInteractionCanonical~field("EVENT_KIND", eventKind)
  out ||= .BrandInteractionCanonical~field("POINT", pointId)
  out ||= .BrandInteractionCanonical~field("SURFACE", surface)
  out ||= .BrandInteractionCanonical~field("DIRECTION", direction)
  out ||= .BrandInteractionCanonical~field("OCCURRED_AT", occurredAt)
  out ||= .BrandInteractionCanonical~join("TAG", tags)
  out ||= .BrandInteractionCanonical~join("PURPOSE", purposes)
  pairs = .array~new
  do k over assessmentValues; pairs~append(k || "=" || assessmentValues[k]); end
  out ||= .BrandInteractionCanonical~join("ASSESSMENT", pairs)
  records=.array~new
  do ar over assessmentRecords; records~append(ar~canonicalText); end
  out ||= .BrandInteractionCanonical~join("ASSESSMENT_RECORD",records)
  pairs = .array~new
  do k over dimensions; pairs~append(k || "=" || dimensions[k]); end
  out ||= .BrandInteractionCanonical~join("DIM", pairs)
  out ||= .BrandInteractionCanonical~join("EVIDENCE_POINT", evidencePoints)
  return out

::class BrandInteractionEpisode public
::attribute episodeId get
::attribute relationshipClass get
::attribute sealed get
::method init
  expose episodeId relationshipClass observations contextTags opportunities sealed
  use arg episodeIdArg, relationshipClassArg = "CUSTOMER_RELATIONSHIP"
  episodeId = episodeIdArg~string
  relationshipClass = .BrandInteractionCanonical~token(relationshipClassArg)
  if episodeId = "" | relationshipClass = "" then raise syntax 88.982 array("BrandInteractionEpisode requires id and relationship class")
  observations = .array~new
  contextTags = .array~new
  opportunities = .array~new
  sealed = .false
::method addObservation
  expose observations sealed
  use arg observation
  if sealed | observation == .nil | \observation~sealed then return .false
  observations~append(observation)
  return .true
::method addContextTag
  expose contextTags sealed
  use arg value
  if sealed then return .false
  t = .BrandInteractionCanonical~token(value)
  if t = "" then return .false
  if \.BrandInteractionCanonical~contains(contextTags,t) then contextTags~append(t)
  return .true
::method addOpportunity
  expose opportunities sealed
  use arg value
  if sealed then return .false
  t = .BrandInteractionCanonical~token(value)
  if t = "" then return .false
  if \.BrandInteractionCanonical~contains(opportunities,t) then opportunities~append(t)
  return .true
::method observations
  expose observations
  return .BrandInteractionCanonical~copyArray(observations)
::method contextTags
  expose contextTags
  return .BrandInteractionCanonical~copyArray(contextTags)
::method opportunities
  expose opportunities
  return .BrandInteractionCanonical~copyArray(opportunities)
::method hasContextTag
  expose contextTags
  use arg value
  return .BrandInteractionCanonical~contains(contextTags, .BrandInteractionCanonical~token(value))
::method seal
  expose observations sealed
  if observations~items = 0 then return .BrandInteractionResult~failure("EPISODE_EMPTY")
  sealed = .true
  return .BrandInteractionResult~success(self)
::method pointId
  expose episodeId
  return "BRAND_INTERACTION:" || episodeId
::method canonicalText
  expose episodeId relationshipClass observations contextTags opportunities sealed
  if \sealed then raise syntax 93.982 additional("BrandInteractionEpisode must be sealed")
  out = .BrandInteractionCanonical~field("EPISODE", episodeId)
  out ||= .BrandInteractionCanonical~field("RELATIONSHIP_CLASS", relationshipClass)
  out ||= .BrandInteractionCanonical~join("CONTEXT", contextTags)
  out ||= .BrandInteractionCanonical~join("OPPORTUNITY", opportunities)
  obsTexts = .array~new
  do obs over observations; obsTexts~append(obs~canonicalText); end
  out ||= .BrandInteractionCanonical~join("OBSERVATION", obsTexts)
  return out

::class BrandEffectFinding public
::attribute findingId get
::attribute code get
::attribute polarity get
::attribute severity get
::attribute confidence get
::attribute explanationCode get
::attribute sealed get
::method init
  expose findingId code polarity severity confidence explanationCode evidencePoints sealed
  use arg findingIdArg, codeArg, polarityArg, severityArg = 50, confidenceArg = 50, explanationCodeArg = ""
  findingId = findingIdArg~string
  code = .BrandInteractionCanonical~token(codeArg)
  polarity = .BrandInteractionCanonical~token(polarityArg)
  severity = .BrandInteractionCanonical~clamp(severityArg)
  confidence = .BrandInteractionCanonical~clamp(confidenceArg)
  explanationCode = .BrandInteractionCanonical~token(explanationCodeArg)
  if findingId = "" | code = "" | polarity = "" then raise syntax 88.983 array("BrandEffectFinding requires id, code, polarity")
  evidencePoints = .array~new
  sealed = .false
::method addEvidencePoint
  expose evidencePoints sealed
  use arg value
  if sealed | value~string = "" then return .false
  if \.BrandInteractionCanonical~contains(evidencePoints,value~string) then evidencePoints~append(value~string)
  return .true
::method evidencePoints
  expose evidencePoints
  return .BrandInteractionCanonical~copyArray(evidencePoints)
::method seal
  expose sealed
  sealed = .true
  return self
::method pointId
  expose findingId
  return "BRAND_INTERACTION:FINDING:" || findingId
::method canonicalText
  expose findingId code polarity severity confidence explanationCode evidencePoints sealed
  if \sealed then raise syntax 93.983 additional("BrandEffectFinding must be sealed")
  out = .BrandInteractionCanonical~field("FINDING", findingId)
  out ||= .BrandInteractionCanonical~field("CODE", code)
  out ||= .BrandInteractionCanonical~field("POLARITY", polarity)
  out ||= .BrandInteractionCanonical~field("SEVERITY", severity)
  out ||= .BrandInteractionCanonical~field("CONFIDENCE", confidence)
  out ||= .BrandInteractionCanonical~field("EXPLANATION_CODE", explanationCode)
  out ||= .BrandInteractionCanonical~join("EVIDENCE_POINT", evidencePoints)
  return out

::class BrandEffectHypothesis public
::attribute hypothesisId get
::attribute triggerPoint get
::attribute outcomePoint get
::attribute outcomeKind get
::attribute confidence get
::attribute causalStatus get
::attribute createdBy get
::attribute sealed get
::method init
  expose hypothesisId triggerPoint outcomePoint outcomeKind confidence causalStatus createdBy mechanisms evidencePoints counterEvidencePoints alternatives sealed
  use arg hypothesisIdArg, triggerPointArg, outcomePointArg, outcomeKindArg, confidenceArg = 50, causalStatusArg = "CANDIDATE_NOT_PROVEN", createdByArg = "BRAND_INTERACTION_ENGINE"
  hypothesisId = hypothesisIdArg~string
  triggerPoint = triggerPointArg~string
  outcomePoint = outcomePointArg~string
  outcomeKind = .BrandInteractionCanonical~token(outcomeKindArg)
  confidence = .BrandInteractionCanonical~clamp(confidenceArg)
  causalStatus = .BrandInteractionCanonical~token(causalStatusArg)
  createdBy = .BrandInteractionCanonical~token(createdByArg)
  if hypothesisId = "" | triggerPoint = "" | outcomePoint = "" | outcomeKind = "" | causalStatus = "" then raise syntax 88.984 array("BrandEffectHypothesis requires ids, outcome and causal status")
  mechanisms = .array~new; evidencePoints = .array~new; counterEvidencePoints = .array~new; alternatives = .array~new
  sealed = .false
::method addMechanism
  expose mechanisms sealed
  use arg value
  if sealed then return .false
  t = .BrandInteractionCanonical~token(value); if t = "" then return .false
  if \.BrandInteractionCanonical~contains(mechanisms,t) then mechanisms~append(t)
  return .true
::method addEvidencePoint
  expose evidencePoints sealed
  use arg value
  if sealed | value~string = "" then return .false
  if \.BrandInteractionCanonical~contains(evidencePoints,value~string) then evidencePoints~append(value~string)
  return .true
::method addCounterEvidencePoint
  expose counterEvidencePoints sealed
  use arg value
  if sealed | value~string = "" then return .false
  if \.BrandInteractionCanonical~contains(counterEvidencePoints,value~string) then counterEvidencePoints~append(value~string)
  return .true
::method addAlternative
  expose alternatives sealed
  use arg value
  if sealed then return .false
  t = .BrandInteractionCanonical~token(value); if t = "" then return .false
  if \.BrandInteractionCanonical~contains(alternatives,t) then alternatives~append(t)
  return .true
::method mechanisms
  expose mechanisms
  return .BrandInteractionCanonical~copyArray(mechanisms)
::method evidencePoints
  expose evidencePoints
  return .BrandInteractionCanonical~copyArray(evidencePoints)
::method counterEvidencePoints
  expose counterEvidencePoints
  return .BrandInteractionCanonical~copyArray(counterEvidencePoints)
::method alternatives
  expose alternatives
  return .BrandInteractionCanonical~copyArray(alternatives)
::method seal
  expose causalStatus sealed
  /* Engine-generated causal claims may not silently promote themselves. */
  if causalStatus = .BrandInteractionConstant~CAUSAL_ESTABLISHED then return .BrandInteractionResult~failure("EXTERNAL_CAUSAL_AUTHORITY_REQUIRED")
  sealed = .true
  return .BrandInteractionResult~success(self)
::method pointId
  expose hypothesisId
  return "BRAND_INTERACTION:HYPOTHESIS:" || hypothesisId
::method canonicalText
  expose hypothesisId triggerPoint outcomePoint outcomeKind confidence causalStatus createdBy mechanisms evidencePoints counterEvidencePoints alternatives sealed
  if \sealed then raise syntax 93.984 additional("BrandEffectHypothesis must be sealed")
  out = .BrandInteractionCanonical~field("HYPOTHESIS", hypothesisId)
  out ||= .BrandInteractionCanonical~field("TRIGGER_POINT", triggerPoint)
  out ||= .BrandInteractionCanonical~field("OUTCOME_POINT", outcomePoint)
  out ||= .BrandInteractionCanonical~field("OUTCOME_KIND", outcomeKind)
  out ||= .BrandInteractionCanonical~field("CONFIDENCE", confidence)
  out ||= .BrandInteractionCanonical~field("CAUSAL_STATUS", causalStatus)
  out ||= .BrandInteractionCanonical~field("CREATED_BY", createdBy)
  out ||= .BrandInteractionCanonical~join("MECHANISM", mechanisms)
  out ||= .BrandInteractionCanonical~join("EVIDENCE_POINT", evidencePoints)
  out ||= .BrandInteractionCanonical~join("COUNTER_EVIDENCE_POINT", counterEvidencePoints)
  out ||= .BrandInteractionCanonical~join("ALTERNATIVE", alternatives)
  return out

::class BrandCausalAuthority public
::attribute authorityId get
::attribute authorityType get
::attribute scope get
::attribute decisionRef get
::attribute sealed get
::method init
  expose authorityId authorityType scope decisionRef sealed
  use arg authorityIdArg, authorityTypeArg, scopeArg, decisionRefArg
  authorityId=.BrandInteractionCanonical~token(authorityIdArg)
  authorityType=.BrandInteractionCanonical~token(authorityTypeArg)
  scope=.BrandInteractionCanonical~token(scopeArg)
  decisionRef=.BrandInteractionCanonical~token(decisionRefArg)
  sealed=.false
  if authorityId="" | authorityType="" | scope="" | decisionRef="" then raise syntax 88.985 array("BrandCausalAuthority requires named authority, scope and decision reference")
::method seal
  expose sealed
  sealed=.true; return self
::method canonicalText
  expose authorityId authorityType scope decisionRef sealed
  if \sealed then raise syntax 93.985 additional("BrandCausalAuthority must be sealed")
  out=.BrandInteractionCanonical~field("CAUSAL_AUTHORITY_ID",authorityId)
  out||=.BrandInteractionCanonical~field("CAUSAL_AUTHORITY_TYPE",authorityType)
  out||=.BrandInteractionCanonical~field("CAUSAL_AUTHORITY_SCOPE",scope)
  out||=.BrandInteractionCanonical~field("CAUSAL_DECISION_REF",decisionRef)
  return out

::class BrandCausalPromotion public
::attribute promotionId get
::attribute hypothesisPoint get
::attribute causalStatus get
::attribute authority get
::attribute evidencePoint get
::attribute sealed get
::method init
  expose promotionId hypothesisPoint causalStatus authority evidencePoint sealed
  use arg promotionIdArg, hypothesisArg, authorityArg, evidencePointArg
  promotionId=promotionIdArg~string
  hypothesisPoint=""
  causalStatus=.BrandInteractionConstant~CAUSAL_ESTABLISHED
  authority=authorityArg
  evidencePoint=evidencePointArg~string
  sealed=.false
  if hypothesisArg\==.nil then hypothesisPoint=hypothesisArg~pointId
  if promotionId="" | hypothesisPoint="" | evidencePoint="" then raise syntax 88.986 array("BrandCausalPromotion requires candidate and evidence")
::method seal
  expose authority sealed
  if authority==.nil then return .BrandInteractionResult~failure("NAMED_CAUSAL_AUTHORITY_REQUIRED")
  if \authority~sealed then return .BrandInteractionResult~failure("CAUSAL_AUTHORITY_NOT_SEALED")
  sealed=.true
  return .BrandInteractionResult~success(self)
::method pointId
  expose promotionId
  return "BRAND_INTERACTION:CAUSAL_PROMOTION:"||promotionId
::method canonicalText
  expose promotionId hypothesisPoint causalStatus authority evidencePoint sealed
  if \sealed then raise syntax 93.986 additional("BrandCausalPromotion must be sealed")
  out=.BrandInteractionCanonical~field("CAUSAL_PROMOTION",promotionId)
  out||=.BrandInteractionCanonical~field("HYPOTHESIS_POINT",hypothesisPoint)
  out||=.BrandInteractionCanonical~field("CAUSAL_STATUS",causalStatus)
  out||=.BrandInteractionCanonical~field("AUTHORITY_EVIDENCE_POINT",evidencePoint)
  out||=authority~canonicalText
  return out

::class BrandInteractionDecision public
::attribute episodeId get
::attribute disposition get
::method init
  expose episodeId findings hypotheses disposition
  use arg episodeIdArg
  episodeId = episodeIdArg~string
  findings = .array~new; hypotheses = .array~new; disposition = .BrandInteractionConstant~CLEAR
::method addFinding
  expose findings
  use arg finding
  if finding == .nil | \finding~sealed then return .false
  findings~append(finding); return .true
::method addHypothesis
  expose hypotheses
  use arg hypothesis
  if hypothesis == .nil | \hypothesis~sealed then return .false
  hypotheses~append(hypothesis); return .true
::method findings
  expose findings
  return .BrandInteractionCanonical~copyArray(findings)
::method hypotheses
  expose hypotheses
  return .BrandInteractionCanonical~copyArray(hypotheses)
::method containsCode
  expose findings
  use arg codeArg
  code = .BrandInteractionCanonical~token(codeArg)
  do f over findings; if f~code = code then return .true; end
  return .false
::method findingByCode
  expose findings
  use arg codeArg
  code = .BrandInteractionCanonical~token(codeArg)
  do f over findings; if f~code = code then return f; end
  return .nil
::method finalize
  expose findings disposition
  worst = 0
  do f over findings
    if f~polarity = .BrandInteractionConstant~CONCERN then worst = max(worst, f~severity)
  end
  if worst >= 85 then disposition = .BrandInteractionConstant~HOLD
  else if worst >= 65 then disposition = .BrandInteractionConstant~REVIEW
  else if worst >= 40 then disposition = .BrandInteractionConstant~WARN
  else disposition = .BrandInteractionConstant~CLEAR
  return self
::method canonicalText
  expose episodeId findings hypotheses disposition
  out = .BrandInteractionCanonical~field("EPISODE", episodeId)
  out ||= .BrandInteractionCanonical~field("DISPOSITION", disposition)
  texts = .array~new; do f over findings; texts~append(f~canonicalText); end
  out ||= .BrandInteractionCanonical~join("FINDING", texts)
  texts = .array~new; do h over hypotheses; texts~append(h~canonicalText); end
  out ||= .BrandInteractionCanonical~join("HYPOTHESIS", texts)
  return out

::class BrandInteractionPolicy public
::attribute styleWarnThreshold get
::attribute styleHighThreshold get
::attribute exitWindowEvents get
::method init
  expose styleWarnThreshold styleHighThreshold exitWindowEvents
  styleWarnThreshold = 65; styleHighThreshold = 80; exitWindowEvents = 6
::method setStyleWarnThreshold
  expose styleWarnThreshold
  use arg value
  styleWarnThreshold = .BrandInteractionCanonical~clamp(value); return self
::method setStyleHighThreshold
  expose styleHighThreshold
  use arg value
  styleHighThreshold = .BrandInteractionCanonical~clamp(value); return self
::method setExitWindowEvents
  expose exitWindowEvents
  use arg value
  if datatype(value,"W") & value > 0 then exitWindowEvents = value
  return self

::class BrandInteractionEngine subclass AlchemyObject public
::method init
  meta=.directory~new
  meta["purpose"]="Evaluate privacy-minimised interaction evidence without claiming causal authority"
  meta["package_version"]=.BrandInteractionBuild~VERSION
  meta["api_version"]=.BrandInteractionBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerMethodContract("EVALUATE", "derive brand-effect findings and causal candidates", .array~of("EPISODE","POLICY"), "BRANDINTERACTIONRESULT", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerExternalRequirement("library","alchemy_objects","0.4.3",.true)
  self~registerInstrumentationPoint("BRAND_INTERACTION.EVALUATE", "brand interaction evaluation requested", .true, "ALL", "INTERNAL")
::method evaluate
  self~alchemyTouch("EVALUATE")
  self~alchemyInstrument("BRAND_INTERACTION.EVALUATE")
  use arg episode, policy = .nil
  if episode == .nil | \episode~sealed then return .BrandInteractionResult~failure("EPISODE_NOT_SEALED")
  if policy == .nil then policy = .BrandInteractionPolicy~new
  d = .BrandInteractionDecision~new(episode~episodeId)
  obs = episode~observations
  seq = 0
  do i = 1 to obs~items
    o = obs[i]
    /* Every customer-facing service/delivery/sales/billing touchpoint can be
       brand work; this does not imply an upsell. */
    if o~hasTag("BRAND_FUNCTION/BRAND_ENGAGEMENT") | o~hasTag("BRAND_FUNCTION/REPUTATIONAL_WORK") | o~hasTag("BRAND_FUNCTION/COMMERCIAL_RELATIONSHIP_WORK") then do
      seq += 1
      f = .BrandEffectFinding~new(episode~episodeId || "-touch-" || seq, .BrandInteractionConstant~FIND_BRAND_TOUCHPOINT, .BrandInteractionConstant~INFO, 10, 100, "CUSTOMER_FACING_BRAND_WORK")
      f~addEvidencePoint(o~pointId); f~seal; d~addFinding(f)
    end
    if o~hasTag("BRAND_FUNCTION/PROMOTIONAL_WORK") & o~hasTag("NO_EXPLICIT_SALES_PROPOSITION") then do
      seq += 1
      f = .BrandEffectFinding~new(episode~episodeId || "-sas-" || seq, .BrandInteractionConstant~FIND_SERVICE_AS_SALES, .BrandInteractionConstant~OPPORTUNITY, 20, 100, "SERVICE_IS_PROMOTIONAL_WITHOUT_UPSELL")
      f~addEvidencePoint(o~pointId); f~seal; d~addFinding(f)
    end
    sentiment = o~assessmentValue(.BrandInteractionConstant~ASSESS_SENTIMENT)
    if self~isNegativeSentiment(sentiment) then do
      seq += 1
      f = .BrandEffectFinding~new(episode~episodeId || "-neg-" || seq, .BrandInteractionConstant~FIND_NEGATIVE_STATE, .BrandInteractionConstant~INFO, 20, 70, "ASSESSED_NOT_FACT")
      f~addEvidencePoint(o~pointId); f~seal; d~addFinding(f)
    end
    engage = o~assessmentValue(.BrandInteractionConstant~ASSESS_ENGAGEMENT)
    if engage = "POSSIBLE_DISENGAGEMENT" then do
      seq += 1
      f = .BrandEffectFinding~new(episode~episodeId || "-disengage-" || seq, .BrandInteractionConstant~FIND_DISENGAGEMENT, .BrandInteractionConstant~CONCERN, 45, 65, "ASSESSED_DISENGAGEMENT_NOT_OBSERVED_INTENT")
      f~addEvidencePoint(o~pointId); f~seal; d~addFinding(f)
    end
    /* Security/safety-sensitive context plus a sales proposition is a
       judgement collision even where the warning/refusal itself is proper. */
    if o~hasTag("CONTEXT/SECURITY_SENSITIVE_SERVICE_INTERACTION") & o~hasTag("EXPLICIT_SALES_PROPOSITION") then do
      if o~hasPurpose("WARNLAW") | o~hasPurpose("REFUSE_ILLEGAL_ASSISTANCE") then do
        seq += 1
        f = .BrandEffectFinding~new(episode~episodeId || "-security-sales-" || seq, .BrandInteractionConstant~FIND_SECURITY_SALES, .BrandInteractionConstant~CONCERN, 78, 90, "VALID_WARNING_THEN_INAPPROPRIATE_COMMERCIAL_TRANSITION")
        f~addEvidencePoint(o~pointId); f~seal; d~addFinding(f)
      end
    end

    /* Structured Utterance v0.2 can preserve the pre-flattening edge showing
       that customer-sensitive information structurally justified a sales act.
       Brand Effect consumes that evidence; it does not re-parse raw prose. */
    if o~hasTag("STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING") then do
      seq += 1
      f = .BrandEffectFinding~new(episode~episodeId || "-sensitive-commercial-" || seq, .BrandInteractionConstant~FIND_SENSITIVE_COMMERCIAL_REPURPOSING, .BrandInteractionConstant~CONCERN, 88, 95, "CUSTOMER_SENSITIVE_INFORMATION_USED_TO_JUSTIFY_COMMERCIAL_PERSUASION")
      f~addEvidencePoint(o~pointId); f~seal; d~addFinding(f)
    end
    if o~hasTag("STRUCTURED_FINDING/DECLARED_INFORMATION_USE_MISMATCH") then do
      seq += 1
      f = .BrandEffectFinding~new(episode~episodeId || "-declared-use-mismatch-" || seq, .BrandInteractionConstant~FIND_DECLARED_USE_MISMATCH, .BrandInteractionConstant~CONCERN, 55, 90, "MODEL_DECLARED_INFORMATION_USE_DIFFERS_FROM_STRUCTURAL_EFFECTIVE_USE")
      f~addEvidencePoint(o~pointId); f~seal; d~addFinding(f)
    end

    sass = o~dimension("SASS")
    abrupt = o~dimension("ABRUPTNESS")
    dismissive = o~dimension("DISMISSIVENESS")
    closure = o~dimension("CLOSURE_STRENGTH")
    if dismissive >= policy~styleHighThreshold & closure >= policy~styleWarnThreshold then do
      seq += 1
      f = .BrandEffectFinding~new(episode~episodeId || "-relterm-" || seq, .BrandInteractionConstant~FIND_RELATIONAL_TERMINATION, .BrandInteractionConstant~CONCERN, max(dismissive,closure), 80, "SUPPORT_AGENT_SOUNDS_LIKE_INTERPERSONAL_CONFLICT")
      f~addEvidencePoint(o~pointId); f~seal; d~addFinding(f)
    end

    if (sass >= policy~styleWarnThreshold | abrupt >= policy~styleHighThreshold | dismissive >= policy~styleHighThreshold) then do
      outcomeIndex = self~findExit(obs, i + 1, policy~exitWindowEvents)
      if outcomeIndex > 0 then do
        outcome = obs[outcomeIndex]
        score = 35
        if sass >= policy~styleWarnThreshold then score += 10
        if abrupt >= policy~styleHighThreshold then score += 10
        if dismissive >= policy~styleHighThreshold then score += 15
        if closure >= policy~styleWarnThreshold then score += 10
        if self~priorNegativeState(obs,i) then score += 10
        if outcome~eventKind = "SUBSCRIPTION_CANCELLED" | outcome~eventKind = "ORDER_CANCELLED" then score += 10
        score = .BrandInteractionCanonical~clamp(score)
        seq += 1
        f = .BrandEffectFinding~new(episode~episodeId || "-style-exit-" || seq, .BrandInteractionConstant~FIND_STYLE_EXIT, .BrandInteractionConstant~CONCERN, score, min(95, score), "STYLE_FOLLOWED_BY_COMMERCIAL_EXIT")
        f~addEvidencePoint(o~pointId); f~addEvidencePoint(outcome~pointId); f~seal; d~addFinding(f)
        h = .BrandEffectHypothesis~new(episode~episodeId || "-hyp-" || seq, o~pointId, outcome~pointId, .BrandInteractionConstant~OUTCOME_COMMERCIAL_EXIT, min(90, score), .BrandInteractionConstant~CAUSAL_CANDIDATE)
        if dismissive >= policy~styleHighThreshold then h~addMechanism(.BrandInteractionConstant~MECH_DISMISSIVENESS)
        if closure >= policy~styleWarnThreshold then h~addMechanism(.BrandInteractionConstant~MECH_RELATIONAL_TERMINATION)
        h~addMechanism(.BrandInteractionConstant~MECH_TRUST_EROSION)
        h~addEvidencePoint(o~pointId); h~addEvidencePoint(outcome~pointId)
        h~addAlternative("PREEXISTING_CUSTOMER_DISSATISFACTION")
        h~addAlternative("INDEPENDENT_PRICE_OR_PRODUCT_REASON")
        if h~seal~ok then d~addHypothesis(h)
      end
    end

    if self~isRecoveryObservation(o) then do
      priorConcern = self~hasPriorConcernSignal(obs,i)
      if priorConcern then do
        seq += 1
        f = .BrandEffectFinding~new(episode~episodeId || "-recovery-" || seq, .BrandInteractionConstant~FIND_RECOVERY, .BrandInteractionConstant~SUPPORT, 60, 85, "RECOVERY_DOES_NOT_ERASE_PRIOR_FAILURE")
        f~addEvidencePoint(o~pointId); f~seal; d~addFinding(f)
      end
    end
  end
  d~finalize
  return .BrandInteractionResult~success(d)

::method isNegativeSentiment private
  use arg value
  return value = "FRUSTRATED" | value = "ANGRY" | value = "FURIOUS" | value = "VERY_NEGATIVE" | value = "UPSET" | value = "HOSTILE"
::method isExitKind private
  use arg kind
  return kind = "SUBSCRIPTION_MANAGEMENT_OPENED" | kind = "CANCELLATION_FLOW_ENTERED" | kind = "SUBSCRIPTION_CANCELLED" | kind = "ORDER_CANCELLED" | kind = "COMMERCIAL_EXIT" | kind = "NEGATIVE_EXTERNAL_COMMUNICATION"
::method findExit private
  use arg observations, startIndex, window
  last = min(observations~items, startIndex + window - 1)
  do j = startIndex to last
    if self~isExitKind(observations[j]~eventKind) then return j
  end
  return 0
::method priorNegativeState private
  use arg observations, index
  first = max(1,index-3)
  do j = first to index
    if self~isNegativeSentiment(observations[j]~assessmentValue(.BrandInteractionConstant~ASSESS_SENTIMENT)) then return .true
  end
  return .false
::method isRecoveryObservation private
  use arg o
  return o~hasPurpose("APOLOGY") | o~hasPurpose("CORRECTIVE_STATEMENT") | o~hasPurpose("SERVICE_RESOLUTION") | o~hasTag("BRAND_OPPORTUNITY/RECOVERY") | o~eventKind = "SERVICE_RECOVERY_COMPLETED" | o~eventKind = "SERVICE_RESOLVED"
::method hasPriorConcernSignal private
  use arg observations, index
  if index <= 1 then return .false
  do j = 1 to index - 1
    o = observations[j]
    if self~isNegativeSentiment(o~assessmentValue(.BrandInteractionConstant~ASSESS_SENTIMENT)) then return .true
    if o~dimension("DISMISSIVENESS") >= 65 | o~dimension("ABRUPTNESS") >= 80 then return .true
    if o~eventKind = "SERVICE_FAILURE" | o~eventKind = "COMPLAINT" then return .true
  end
  return .false

::class BrandInteractionExplainer public
::method concise class
  use arg decision
  if decision == .nil then return ""
  if decision~containsCode(.BrandInteractionConstant~FIND_SENSITIVE_COMMERCIAL_REPURPOSING) then
    return "Customer-sensitive information was structurally reused as part of a commercial persuasion rationale. This is a brand-effect finding, not a legal conclusion."
  if decision~containsCode(.BrandInteractionConstant~FIND_STYLE_EXIT) then
    return "Commercial exit followed a response assessed as unusually sassy, abrupt or dismissive. Treat that response as a candidate contributor, not a proven cause."
  if decision~containsCode(.BrandInteractionConstant~FIND_SECURITY_SALES) then
    return "A valid safety/legal warning was immediately combined with a sales proposition, creating a brand-judgement collision."
  if decision~containsCode(.BrandInteractionConstant~FIND_RECOVERY) then
    return "The interaction contains an explicit recovery signal; it can support trust restoration without erasing the earlier failure."
  if decision~containsCode(.BrandInteractionConstant~FIND_SERVICE_AS_SALES) then
    return "This service interaction is promotional and reputational brand work even though it contains no upsell."
  return "No high-signal brand interaction pattern was identified."
::method informal class
  use arg decision
  if decision == .nil then return ""
  if decision~containsCode(.BrandInteractionConstant~FIND_SENSITIVE_COMMERCIAL_REPURPOSING) then return "The bot turned sensitive customer context into part of the sales pitch."
  if decision~containsCode(.BrandInteractionConstant~FIND_STYLE_EXIT) then return "You may have lost the order because you used too much sass."
  if decision~containsCode(.BrandInteractionConstant~FIND_SECURITY_SALES) then return "The warning was sensible; the sales pitch immediately afterwards was the bit where the brand rather lost the plot."
  if decision~containsCode(.BrandInteractionConstant~FIND_SERVICE_AS_SALES) then return "Nobody upsold anything, but this was still sales work: the customer was experiencing the brand."
  return self~concise(decision)

::requires 'AlchemyObject.cls'
