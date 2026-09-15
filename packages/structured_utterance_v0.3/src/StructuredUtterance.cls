/*
 * Structured Utterance v0.3
 *
 * Preserves what an agent/LLM knows about its own reply before the reply is
 * flattened into plain text: communicative purpose, data role, information
 * lineage, privacy classification, brand/commercial context, and stable
 * action points.  Privacy policy and access-point instrumentation remain
 * external concerns.
 */

::class StructuredUtteranceBuild public
::constant VERSION "0.3"
::constant API_VERSION "structured.utterance/0.3"
::constant PRODUCT "ooRexx Structured Utterance"

::class StructuredUtteranceConstant public
/* privacy classes intentionally align with Interaction Event v0.1 */
::constant PRIVACY_PUBLIC "PUBLIC"
::constant PRIVACY_ORGANISATION "ORGANISATION"
::constant PRIVACY_DERIVED_NONCUSTOMER "DERIVED_NONCUSTOMER"
::constant PRIVACY_CUSTOMER_PSEUDONYMOUS "CUSTOMER_PSEUDONYMOUS"
::constant PRIVACY_CUSTOMER_SPECIFIC "CUSTOMER_SPECIFIC"
::constant PRIVACY_CUSTOMER_SENSITIVE "CUSTOMER_SENSITIVE"
::constant PRIVACY_UNKNOWN "UNKNOWN"

::constant RETAIN "RETAIN"
::constant ABSTRACT_ONLY "ABSTRACT_ONLY"
::constant DROP "DROP"

/* communicative purposes / roles */
::constant PURPOSE_GENERAL "GENERAL"
::constant PURPOSE_WARNLAW "WARNLAW"
::constant PURPOSE_SALESPROP "SALESPROP"
::constant PURPOSE_SERVICE_RESOLUTION "SERVICE_RESOLUTION"
::constant PURPOSE_APOLOGY "APOLOGY"
::constant PURPOSE_INFORMATION "INFORMATION"
::constant PURPOSE_REFUSAL "REFUSAL"
::constant PURPOSE_RECOVERY "RECOVERY"

/* orthogonal data roles */
::constant DATA_NONE "NONE"
::constant DATA_CUSTNAME "CUSTNAME"
::constant DATA_CUSTREF "CUSTREF"
::constant DATA_CUSTDATA "CUSTDATA"
::constant DATA_CUSTSENSITIVE "CUSTSENSITIVE"

/* lineage */
::constant LINEAGE_COPIED_CUSTOMER "COPIED_FROM_CUSTOMER"
::constant LINEAGE_REFERENCES_CUSTOMER_ENTITY "REFERENCES_CUSTOMER_ENTITY"
::constant LINEAGE_DERIVED_CUSTOMER_FACT "DERIVED_FROM_CUSTOMER_FACT"
::constant LINEAGE_INFERRED_CUSTOMER_DATA "INFERRED_FROM_CUSTOMER_DATA"
::constant LINEAGE_DERIVED_EXTERNAL "DERIVED_FROM_EXTERNAL_DATA"
::constant LINEAGE_MODEL_GENERATED "MODEL_GENERATED"
::constant LINEAGE_SYSTEM_POLICY "SYSTEM_POLICY"
::constant LINEAGE_SAFE_ABSTRACTION "DERIVED_SAFE_ABSTRACTION"

/* information-use relationships are separate from communicative purpose.
   A model may declare a use, but effective use is derived from the structural
   relationship between information-bearing segments and communicative acts. */
::constant USE_SUBJECT "SUBJECT"
::constant USE_JUSTIFICATION "JUSTIFICATION"
::constant USE_EVIDENCE "EVIDENCE"
::constant USE_PERSONALISATION "PERSONALISATION"
::constant USE_TARGET_SELECTION "TARGET_SELECTION"
::constant USE_SAFETY_REASON "SAFETY_REASON"
::constant USE_SERVICE_REASON "SERVICE_REASON"
::constant USE_COMMERCIAL_REASON "COMMERCIAL_REASON"
::constant USE_RISK_AVOIDANCE "RISK_AVOIDANCE"
::constant USE_EMPATHETIC_CONTEXT "EMPATHETIC_CONTEXT"
::constant USE_SUPPORTIVE_CONTEXT "SUPPORTIVE_CONTEXT"

::constant DECLARED_USE_SAFETY_WARNING "SAFETY_WARNING"
::constant DECLARED_USE_EMPATHETIC_ACK "EMPATHETIC_ACK"
::constant DECLARED_USE_SERVICE_RESOLUTION "SERVICE_RESOLUTION"
::constant DECLARED_USE_COMMERCIAL_PERSUASION "COMMERCIAL_PERSUASION"
::constant DECLARED_USE_SALES_JUSTIFICATION "SALES_JUSTIFICATION"
::constant DECLARED_USE_SUPPORTIVE_CONTEXT "SUPPORTIVE_CONTEXT"

::constant EFFECTIVE_USE_SAFETY_WARNING "SAFETY_WARNING"
::constant EFFECTIVE_USE_EMPATHETIC_ACK "EMPATHETIC_ACK"
::constant EFFECTIVE_USE_SERVICE_RESOLUTION "SERVICE_RESOLUTION"
::constant EFFECTIVE_USE_COMMERCIAL_PERSUASION "COMMERCIAL_PERSUASION"
::constant EFFECTIVE_USE_INFORMATIONAL "INFORMATIONAL"
::constant EFFECTIVE_USE_UNKNOWN "UNKNOWN"

::constant FIND_SENSITIVE_COMMERCIAL_REPURPOSING "SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING"
::constant FIND_DECLARED_USE_MISMATCH "DECLARED_INFORMATION_USE_MISMATCH"

::constant AUTHORITY_MODEL "MODEL"
::constant AUTHORITY_SYSTEM "SYSTEM"
::constant AUTHORITY_PRIVACY_ENGINE "PRIVACY_ENGINE"
::constant AUTHORITY_HUMAN "HUMAN"

/* brand experience domains */
::constant DOMAIN_SUPPORT "SUPPORT"
::constant DOMAIN_DELIVERY "DELIVERY"
::constant DOMAIN_SALES "SALES"
::constant DOMAIN_BILLING "BILLING"
::constant DOMAIN_OPERATIONS "OPERATIONS"
::constant DOMAIN_SECURITY "SECURITY"

/* the work an interaction performs for the brand */
::constant BRAND_ENGAGEMENT "BRAND_ENGAGEMENT"
::constant BRAND_PROMOTIONAL_WORK "PROMOTIONAL_WORK"
::constant BRAND_REPUTATIONAL_WORK "REPUTATIONAL_WORK"
::constant BRAND_COMMERCIAL_RELATIONSHIP_WORK "COMMERCIAL_RELATIONSHIP_WORK"

/* opportunity / risk dimensions */
::constant OPP_TRUST_MAINTENANCE "TRUST_MAINTENANCE"
::constant OPP_RECOVERY "RECOVERY"
::constant OPP_RETENTION "RETENTION"
::constant OPP_ADVOCACY "ADVOCACY"
::constant OPP_ACQUISITION "ACQUISITION"
::constant OPP_PURCHASE "PURCHASE"
::constant OPP_COMMERCIAL_OPPORTUNITY "COMMERCIAL_OPPORTUNITY"
::constant OPP_CHURN_RISK "CHURN_RISK"
::constant OPP_REPUTATIONAL_RISK "REPUTATIONAL_RISK"

::class StructuredUtteranceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg = "OK", detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  value = valueArg
::method success class
  use arg valueArg = .nil, detailArg = ""
  return self~new(.true, "OK", detailArg, valueArg)
::method failure class
  use arg codeArg, detailArg = "", valueArg = .nil
  return self~new(.false, codeArg, detailArg, valueArg)

::class StructuredUtteranceCanonical public
::method token class
  use arg value
  if value == .nil then return ""
  s = value~string~upper~strip
  if s = "" then return ""
  if verify(s, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-/:+") <> 0 then return ""
  return s
::method copyArray class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item)
  end
  return out
::method containsToken class
  use arg source, wanted
  wanted = self~token(wanted)
  if wanted = "" | source == .nil then return .false
  do item over source
    if self~token(item) = wanted then return .true
  end
  return .false
::method clamp class
  use arg value, low = 0, high = 100
  n = value + 0
  if n < low then return low
  if n > high then return high
  return n
::method field class
  use arg tag, value = ""
  if value == .nil then rendered = "<NIL>"; else rendered = value~string
  return tag~string || ":" || rendered~length || ":" || rendered
::method join class
  use arg tag, source
  vals = .array~new
  if source \== .nil then do item over source; vals~append(item~string); end
  vals~sort
  text = self~field(tag || "_COUNT", vals~items)
  do value over vals
    text ||= self~field(tag, value)
  end
  return text
::method isWhitespace class
  use arg value
  if value == .nil then return .true
  s = value~string
  if s = "" then return .true
  allowed = " " || d2c(9) || d2c(10) || d2c(13)
  return verify(s, allowed) = 0
::method privacyRank class
  use arg privacyClass
  p = self~token(privacyClass)
  select
    when p = .StructuredUtteranceConstant~PRIVACY_PUBLIC then return 0
    when p = .StructuredUtteranceConstant~PRIVACY_ORGANISATION then return 1
    when p = .StructuredUtteranceConstant~PRIVACY_DERIVED_NONCUSTOMER then return 1
    when p = .StructuredUtteranceConstant~PRIVACY_CUSTOMER_PSEUDONYMOUS then return 2
    when p = .StructuredUtteranceConstant~PRIVACY_CUSTOMER_SPECIFIC then return 3
    when p = .StructuredUtteranceConstant~PRIVACY_CUSTOMER_SENSITIVE then return 4
    otherwise return 99
  end
::method privacyAtLeast class
  use arg actual, floor
  actualToken = self~token(actual)
  floorToken = self~token(floor)
  if floorToken = .StructuredUtteranceConstant~PRIVACY_UNKNOWN then return actualToken = floorToken
  if actualToken = .StructuredUtteranceConstant~PRIVACY_UNKNOWN then return .true
  return self~privacyRank(actualToken) >= self~privacyRank(floorToken)

::class UtteranceLineageEdge public
::attribute edgeId get
::attribute lineageKind get
::attribute sourceRef get
::attribute sourcePrivacyClass get
::attribute privacyFloor get
::attribute authorityKind get
::attribute authorityId get
::attribute confidence get
::method init
  expose edgeId lineageKind sourceRef sourcePrivacyClass privacyFloor authorityKind authorityId confidence
  use arg edgeIdArg, lineageKindArg, sourceRefArg = "", sourcePrivacyArg = "UNKNOWN", privacyFloorArg = "", authorityKindArg = "MODEL", authorityIdArg = "", confidenceArg = 100
  edgeId = edgeIdArg~string
  lineageKind = .StructuredUtteranceCanonical~token(lineageKindArg)
  sourceRef = sourceRefArg~string
  sourcePrivacyClass = .StructuredUtteranceCanonical~token(sourcePrivacyArg)
  if sourcePrivacyClass = "" then sourcePrivacyClass = .StructuredUtteranceConstant~PRIVACY_UNKNOWN
  if privacyFloorArg~string = "" then privacyFloor = sourcePrivacyClass
  else privacyFloor = .StructuredUtteranceCanonical~token(privacyFloorArg)
  if privacyFloor = "" then privacyFloor = .StructuredUtteranceConstant~PRIVACY_UNKNOWN
  authorityKind = .StructuredUtteranceCanonical~token(authorityKindArg)
  if authorityKind = "" then authorityKind = .StructuredUtteranceConstant~AUTHORITY_MODEL
  authorityId = authorityIdArg~string
  confidence = .StructuredUtteranceCanonical~clamp(confidenceArg)
  if edgeId = "" | lineageKind = "" then raise syntax 88.971 array("UtteranceLineageEdge requires id and token lineageKind")
::method validate
  expose lineageKind sourcePrivacyClass privacyFloor authorityKind sourceRef
  /* A privacy downgrade is only accepted as an explicit safe abstraction
     attested by a privacy engine.  The model cannot downgrade its own data. */
  sourceRank = .StructuredUtteranceCanonical~privacyRank(sourcePrivacyClass)
  floorRank = .StructuredUtteranceCanonical~privacyRank(privacyFloor)
  if sourcePrivacyClass = .StructuredUtteranceConstant~PRIVACY_UNKNOWN then do
    if privacyFloor \= .StructuredUtteranceConstant~PRIVACY_UNKNOWN then
      return .StructuredUtteranceResult~failure("LINEAGE_UNKNOWN_DOWNGRADE", sourceRef)
  end
  else if floorRank < sourceRank then do
    if lineageKind \= .StructuredUtteranceConstant~LINEAGE_SAFE_ABSTRACTION | authorityKind \= .StructuredUtteranceConstant~AUTHORITY_PRIVACY_ENGINE then
      return .StructuredUtteranceResult~failure("LINEAGE_PRIVACY_DOWNGRADE_UNAUTHORISED", sourceRef)
  end
  return .StructuredUtteranceResult~success(self)
::method canonicalText
  expose edgeId lineageKind sourceRef sourcePrivacyClass privacyFloor authorityKind authorityId confidence
  text = .StructuredUtteranceCanonical~field("EDGE", edgeId)
  text ||= .StructuredUtteranceCanonical~field("KIND", lineageKind)
  text ||= .StructuredUtteranceCanonical~field("SOURCE", sourceRef)
  text ||= .StructuredUtteranceCanonical~field("SOURCE_PRIVACY", sourcePrivacyClass)
  text ||= .StructuredUtteranceCanonical~field("PRIVACY_FLOOR", privacyFloor)
  text ||= .StructuredUtteranceCanonical~field("AUTHORITY_KIND", authorityKind)
  text ||= .StructuredUtteranceCanonical~field("AUTHORITY_ID", authorityId)
  text ||= .StructuredUtteranceCanonical~field("CONFIDENCE", confidence)
  return text

::class StructuredUtteranceSegment public
::attribute segmentId get
::attribute text get
::attribute abstractText get
::attribute primaryPurpose get
::attribute dataRole get
::attribute privacyClass get
::attribute retentionClass get
::attribute separatorBefore get
::attribute confidence get
::attribute sealed get
::method init
  expose segmentId text abstractText primaryPurpose dataRole privacyClass retentionClass separatorBefore confidence roles lineage metadata sealed
  use arg segmentIdArg, textArg, primaryPurposeArg = "GENERAL", dataRoleArg = "NONE", privacyClassArg = "DERIVED_NONCUSTOMER", abstractTextArg = "", retentionClassArg = "RETAIN", separatorBeforeArg = "", confidenceArg = 100
  segmentId = segmentIdArg~string
  text = textArg~string
  abstractText = abstractTextArg~string
  primaryPurpose = .StructuredUtteranceCanonical~token(primaryPurposeArg)
  dataRole = .StructuredUtteranceCanonical~token(dataRoleArg)
  privacyClass = .StructuredUtteranceCanonical~token(privacyClassArg)
  retentionClass = .StructuredUtteranceCanonical~token(retentionClassArg)
  separatorBefore = separatorBeforeArg~string
  confidence = .StructuredUtteranceCanonical~clamp(confidenceArg)
  if segmentId = "" | primaryPurpose = "" | dataRole = "" | privacyClass = "" | retentionClass = "" then
    raise syntax 88.972 array("StructuredUtteranceSegment requires id and controlled token fields")
  roles = .array~new
  lineage = .array~new
  metadata = .table~new
  sealed = .false
::method addRole
  expose roles sealed
  use arg value
  if sealed then return .false
  token = .StructuredUtteranceCanonical~token(value)
  if token = "" then return .false
  if \.StructuredUtteranceCanonical~containsToken(roles, token) then roles~append(token)
  return .true
::method addLineage
  expose lineage sealed
  use arg edge
  if sealed | edge == .nil then return .false
  lineage~append(edge)
  return .true
::method putMetadata
  expose metadata sealed
  use arg keyArg, valueArg
  if sealed then return .false
  key = .StructuredUtteranceCanonical~token(keyArg)
  if key = "" then return .false
  metadata[key] = valueArg~string
  return .true
::method roles
  expose roles
  return .StructuredUtteranceCanonical~copyArray(roles)
::method lineage
  expose lineage
  return .StructuredUtteranceCanonical~copyArray(lineage)
::method metadata
  expose metadata
  out = .table~new
  do k over metadata; out[k] = metadata[k]; end
  return out
::method validate
  expose segmentId text primaryPurpose dataRole privacyClass retentionClass separatorBefore lineage
  if text = "" then return .StructuredUtteranceResult~failure("SEGMENT_TEXT_EMPTY", segmentId)
  if \.StructuredUtteranceCanonical~isWhitespace(separatorBefore) then return .StructuredUtteranceResult~failure("SEGMENT_SEPARATOR_NOT_WHITESPACE", segmentId)
  if retentionClass \= .StructuredUtteranceConstant~RETAIN & retentionClass \= .StructuredUtteranceConstant~ABSTRACT_ONLY & retentionClass \= .StructuredUtteranceConstant~DROP then
    return .StructuredUtteranceResult~failure("SEGMENT_RETENTION_INVALID", retentionClass)
  /* Data-role claims and privacy classification are orthogonal, but a customer
     data-role cannot be presented as public/non-customer data. */
  if dataRole \= .StructuredUtteranceConstant~DATA_NONE then do
    if .StructuredUtteranceCanonical~privacyRank(privacyClass) < .StructuredUtteranceCanonical~privacyRank(.StructuredUtteranceConstant~PRIVACY_CUSTOMER_PSEUDONYMOUS) then
      return .StructuredUtteranceResult~failure("SEGMENT_CUSTOMER_ROLE_PRIVACY_TOO_LOW", segmentId)
  end
  do edge over lineage
    vr = edge~validate
    if \vr~ok then return vr
    if \.StructuredUtteranceCanonical~privacyAtLeast(privacyClass, edge~privacyFloor) then
      return .StructuredUtteranceResult~failure("SEGMENT_BELOW_LINEAGE_PRIVACY_FLOOR", segmentId || ":" || edge~edgeId)
  end
  return .StructuredUtteranceResult~success(self)
::method seal
  expose sealed
  result = self~validate
  if \result~ok then return result
  sealed = .true
  return .StructuredUtteranceResult~success(self)
::method canonicalText
  expose segmentId text abstractText primaryPurpose dataRole privacyClass retentionClass separatorBefore confidence roles lineage metadata sealed
  if \sealed then raise syntax 93.971 additional("StructuredUtteranceSegment must be sealed before canonicalisation")
  out = .StructuredUtteranceCanonical~field("SEGMENT", segmentId)
  out ||= .StructuredUtteranceCanonical~field("TEXT", text)
  out ||= .StructuredUtteranceCanonical~field("ABSTRACT", abstractText)
  out ||= .StructuredUtteranceCanonical~field("PURPOSE", primaryPurpose)
  out ||= .StructuredUtteranceCanonical~field("DATA_ROLE", dataRole)
  out ||= .StructuredUtteranceCanonical~field("PRIVACY", privacyClass)
  out ||= .StructuredUtteranceCanonical~field("RETENTION", retentionClass)
  out ||= .StructuredUtteranceCanonical~field("SEPARATOR", separatorBefore)
  out ||= .StructuredUtteranceCanonical~field("CONFIDENCE", confidence)
  out ||= .StructuredUtteranceCanonical~join("ROLE", roles)
  edgeTexts = .array~new
  do edge over lineage; edgeTexts~append(edge~canonicalText); end
  out ||= .StructuredUtteranceCanonical~join("LINEAGE", edgeTexts)
  pairs = .array~new
  do k over metadata; pairs~append(k || "=" || metadata[k]); end
  out ||= .StructuredUtteranceCanonical~join("META", pairs)
  return out

::class UtteranceCommunicativeAct public
::attribute actId get
::attribute kind get
::attribute authorityKind get
::attribute authorityId get
::attribute confidence get
::attribute sealed get
::method init
  expose actId kind authorityKind authorityId confidence segmentIds sealed
  use arg actIdArg, kindArg, authorityKindArg = "MODEL", authorityIdArg = "", confidenceArg = 100
  actId = actIdArg~string
  kind = .StructuredUtteranceCanonical~token(kindArg)
  authorityKind = .StructuredUtteranceCanonical~token(authorityKindArg)
  if authorityKind = "" then authorityKind = .StructuredUtteranceConstant~AUTHORITY_MODEL
  authorityId = authorityIdArg~string
  confidence = .StructuredUtteranceCanonical~clamp(confidenceArg)
  if actId = "" | kind = "" then raise syntax 88.974 array("UtteranceCommunicativeAct requires id and token kind")
  segmentIds = .array~new
  sealed = .false
::method addSegmentId
  expose segmentIds sealed
  use arg segmentIdArg
  if sealed then return .false
  id = segmentIdArg~string
  if id = "" then return .false
  do existing over segmentIds; if existing = id then return .true; end
  segmentIds~append(id)
  return .true
::method segmentIds
  expose segmentIds
  return .StructuredUtteranceCanonical~copyArray(segmentIds)
::method validate
  expose actId segmentIds
  if segmentIds~items = 0 then return .StructuredUtteranceResult~failure("ACT_NO_SEGMENTS", actId)
  return .StructuredUtteranceResult~success(self)
::method seal
  expose sealed
  r = self~validate
  if \r~ok then return r
  sealed = .true
  return .StructuredUtteranceResult~success(self)
::method canonicalText
  expose actId kind authorityKind authorityId confidence segmentIds sealed
  if \sealed then raise syntax 93.973 additional("UtteranceCommunicativeAct must be sealed before canonicalisation")
  out = .StructuredUtteranceCanonical~field("ACT", actId)
  out ||= .StructuredUtteranceCanonical~field("KIND", kind)
  out ||= .StructuredUtteranceCanonical~field("AUTHORITY_KIND", authorityKind)
  out ||= .StructuredUtteranceCanonical~field("AUTHORITY_ID", authorityId)
  out ||= .StructuredUtteranceCanonical~field("CONFIDENCE", confidence)
  out ||= .StructuredUtteranceCanonical~join("SEGMENT_ID", segmentIds)
  return out

::class UtteranceInformationUseEdge public
::attribute useEdgeId get
::attribute segmentId get
::attribute lineageEdgeId get
::attribute targetActId get
::attribute relationRole get
::attribute declaredUse get
::attribute authorityKind get
::attribute authorityId get
::attribute confidence get
::attribute sealed get
::method init
  expose useEdgeId segmentId lineageEdgeId targetActId relationRole declaredUse authorityKind authorityId confidence sealed
  use arg useEdgeIdArg, segmentIdArg, lineageEdgeIdArg, targetActIdArg, relationRoleArg, declaredUseArg = "", authorityKindArg = "MODEL", authorityIdArg = "", confidenceArg = 100
  useEdgeId = useEdgeIdArg~string
  segmentId = segmentIdArg~string
  lineageEdgeId = lineageEdgeIdArg~string
  targetActId = targetActIdArg~string
  relationRole = .StructuredUtteranceCanonical~token(relationRoleArg)
  declaredUse = .StructuredUtteranceCanonical~token(declaredUseArg)
  authorityKind = .StructuredUtteranceCanonical~token(authorityKindArg)
  if authorityKind = "" then authorityKind = .StructuredUtteranceConstant~AUTHORITY_MODEL
  authorityId = authorityIdArg~string
  confidence = .StructuredUtteranceCanonical~clamp(confidenceArg)
  if useEdgeId = "" | segmentId = "" | lineageEdgeId = "" | targetActId = "" | relationRole = "" then
    raise syntax 88.975 array("UtteranceInformationUseEdge requires ids and token relation role")
  sealed = .false
::method seal
  expose sealed
  sealed = .true
  return .StructuredUtteranceResult~success(self)
::method canonicalText
  expose useEdgeId segmentId lineageEdgeId targetActId relationRole declaredUse authorityKind authorityId confidence sealed
  if \sealed then raise syntax 93.974 additional("UtteranceInformationUseEdge must be sealed before canonicalisation")
  out = .StructuredUtteranceCanonical~field("USE_EDGE", useEdgeId)
  out ||= .StructuredUtteranceCanonical~field("SEGMENT", segmentId)
  out ||= .StructuredUtteranceCanonical~field("LINEAGE_EDGE", lineageEdgeId)
  out ||= .StructuredUtteranceCanonical~field("TARGET_ACT", targetActId)
  out ||= .StructuredUtteranceCanonical~field("RELATION_ROLE", relationRole)
  out ||= .StructuredUtteranceCanonical~field("DECLARED_USE", declaredUse)
  out ||= .StructuredUtteranceCanonical~field("AUTHORITY_KIND", authorityKind)
  out ||= .StructuredUtteranceCanonical~field("AUTHORITY_ID", authorityId)
  out ||= .StructuredUtteranceCanonical~field("CONFIDENCE", confidence)
  return out

::class UtteranceGenerationIntent public
::attribute intentId get
::attribute targetActId get
::attribute intendedAct get
::attribute intendedRegister get
::attribute intendedOutcome get
::attribute authorityKind get
::attribute authorityId get
::attribute confidence get
::attribute createdAt get
::attribute sealed get
::method init
  expose intentId targetActId intendedAct intendedRegister intendedOutcome authorityKind authorityId confidence createdAt informationUseIds constraints sealed
  use arg intentIdArg, targetActIdArg, intendedActArg, intendedRegisterArg = "NEUTRAL", intendedOutcomeArg = "", authorityKindArg = "MODEL", authorityIdArg = "", confidenceArg = 100, createdAtArg = .nil
  intentId = intentIdArg~string
  targetActId = targetActIdArg~string
  intendedAct = .StructuredUtteranceCanonical~token(intendedActArg)
  intendedRegister = .StructuredUtteranceCanonical~token(intendedRegisterArg)
  intendedOutcome = .StructuredUtteranceCanonical~token(intendedOutcomeArg)
  authorityKind = .StructuredUtteranceCanonical~token(authorityKindArg)
  if authorityKind = "" then authorityKind = .StructuredUtteranceConstant~AUTHORITY_MODEL
  authorityId = authorityIdArg~string
  confidence = .StructuredUtteranceCanonical~clamp(confidenceArg)
  if createdAtArg == .nil then createdAt = .DateTime~new; else createdAt = createdAtArg
  if intentId = "" | targetActId = "" | intendedAct = "" | intendedRegister = "" then
    raise syntax 88.976 array("UtteranceGenerationIntent requires ids and controlled intended act/register")
  informationUseIds = .array~new
  constraints = .array~new
  sealed = .false
::method addInformationUseId
  expose informationUseIds sealed
  use arg value
  if sealed then return .false
  id = value~string
  if id = "" then return .false
  do existing over informationUseIds; if existing = id then return .true; end
  informationUseIds~append(id)
  return .true
::method addConstraint
  expose constraints sealed
  use arg value
  if sealed then return .false
  t = .StructuredUtteranceCanonical~token(value)
  if t = "" then return .false
  if \.StructuredUtteranceCanonical~containsToken(constraints, t) then constraints~append(t)
  return .true
::method informationUseIds
  expose informationUseIds
  return .StructuredUtteranceCanonical~copyArray(informationUseIds)
::method constraints
  expose constraints
  return .StructuredUtteranceCanonical~copyArray(constraints)
::method seal
  expose sealed
  sealed = .true
  return .StructuredUtteranceResult~success(self)
::method canonicalText
  expose intentId targetActId intendedAct intendedRegister intendedOutcome authorityKind authorityId confidence createdAt informationUseIds constraints sealed
  if \sealed then raise syntax 93.975 additional("UtteranceGenerationIntent must be sealed before canonicalisation")
  out = .StructuredUtteranceCanonical~field("INTENT", intentId)
  out ||= .StructuredUtteranceCanonical~field("TARGET_ACT", targetActId)
  out ||= .StructuredUtteranceCanonical~field("INTENDED_ACT", intendedAct)
  out ||= .StructuredUtteranceCanonical~field("INTENDED_REGISTER", intendedRegister)
  out ||= .StructuredUtteranceCanonical~field("INTENDED_OUTCOME", intendedOutcome)
  out ||= .StructuredUtteranceCanonical~field("AUTHORITY_KIND", authorityKind)
  out ||= .StructuredUtteranceCanonical~field("AUTHORITY_ID", authorityId)
  out ||= .StructuredUtteranceCanonical~field("CONFIDENCE", confidence)
  out ||= .StructuredUtteranceCanonical~field("CREATED_AT", createdAt)
  out ||= .StructuredUtteranceCanonical~join("INFORMATION_USE", informationUseIds)
  out ||= .StructuredUtteranceCanonical~join("CONSTRAINT", constraints)
  return out

::class UtteranceUseFinding public
::attribute findingId get
::attribute code get
::attribute sourceRef get
::attribute segmentId get
::attribute actId get
::attribute relationRole get
::attribute declaredUse get
::attribute effectiveUse get
::attribute sourcePrivacyClass get
::attribute confidence get
::method init
  expose findingId code sourceRef segmentId actId relationRole declaredUse effectiveUse sourcePrivacyClass confidence
  use arg findingIdArg, codeArg, sourceRefArg, segmentIdArg, actIdArg, relationRoleArg, declaredUseArg, effectiveUseArg, sourcePrivacyArg, confidenceArg = 100
  findingId = findingIdArg~string
  code = .StructuredUtteranceCanonical~token(codeArg)
  sourceRef = sourceRefArg~string
  segmentId = segmentIdArg~string
  actId = actIdArg~string
  relationRole = .StructuredUtteranceCanonical~token(relationRoleArg)
  declaredUse = .StructuredUtteranceCanonical~token(declaredUseArg)
  effectiveUse = .StructuredUtteranceCanonical~token(effectiveUseArg)
  sourcePrivacyClass = .StructuredUtteranceCanonical~token(sourcePrivacyArg)
  confidence = .StructuredUtteranceCanonical~clamp(confidenceArg)
::method pointId
  expose findingId
  return "STRUCTURED_UTTERANCE:FINDING:" || findingId
::method canonicalText
  expose findingId code sourceRef segmentId actId relationRole declaredUse effectiveUse sourcePrivacyClass confidence
  out = .StructuredUtteranceCanonical~field("FINDING", findingId)
  out ||= .StructuredUtteranceCanonical~field("CODE", code)
  out ||= .StructuredUtteranceCanonical~field("SOURCE", sourceRef)
  out ||= .StructuredUtteranceCanonical~field("SEGMENT", segmentId)
  out ||= .StructuredUtteranceCanonical~field("ACT", actId)
  out ||= .StructuredUtteranceCanonical~field("RELATION_ROLE", relationRole)
  out ||= .StructuredUtteranceCanonical~field("DECLARED_USE", declaredUse)
  out ||= .StructuredUtteranceCanonical~field("EFFECTIVE_USE", effectiveUse)
  out ||= .StructuredUtteranceCanonical~field("SOURCE_PRIVACY", sourcePrivacyClass)
  out ||= .StructuredUtteranceCanonical~field("CONFIDENCE", confidence)
  return out

::class StructuredUtteranceAnalyzer public
::method effectiveUse class
  use arg actKindArg, relationRoleArg
  actKind = .StructuredUtteranceCanonical~token(actKindArg)
  role = .StructuredUtteranceCanonical~token(relationRoleArg)
  if actKind = .StructuredUtteranceConstant~PURPOSE_SALESPROP then do
    if self~isCommercialRelation(role) then return .StructuredUtteranceConstant~EFFECTIVE_USE_COMMERCIAL_PERSUASION
  end
  if actKind = .StructuredUtteranceConstant~PURPOSE_WARNLAW | actKind = .StructuredUtteranceConstant~PURPOSE_REFUSAL then do
    if role = .StructuredUtteranceConstant~USE_SAFETY_REASON | role = .StructuredUtteranceConstant~USE_EVIDENCE | role = .StructuredUtteranceConstant~USE_JUSTIFICATION then
      return .StructuredUtteranceConstant~EFFECTIVE_USE_SAFETY_WARNING
  end
  if actKind = .StructuredUtteranceConstant~PURPOSE_SERVICE_RESOLUTION then
    return .StructuredUtteranceConstant~EFFECTIVE_USE_SERVICE_RESOLUTION
  if actKind = .StructuredUtteranceConstant~PURPOSE_INFORMATION & (role = .StructuredUtteranceConstant~USE_EMPATHETIC_CONTEXT | role = .StructuredUtteranceConstant~USE_SUPPORTIVE_CONTEXT) then
    return .StructuredUtteranceConstant~EFFECTIVE_USE_EMPATHETIC_ACK
  if actKind = .StructuredUtteranceConstant~PURPOSE_INFORMATION then return .StructuredUtteranceConstant~EFFECTIVE_USE_INFORMATIONAL
  return .StructuredUtteranceConstant~EFFECTIVE_USE_UNKNOWN
::method isCommercialRelation class
  use arg roleArg
  role = .StructuredUtteranceCanonical~token(roleArg)
  return role = .StructuredUtteranceConstant~USE_JUSTIFICATION | -
         role = .StructuredUtteranceConstant~USE_COMMERCIAL_REASON | -
         role = .StructuredUtteranceConstant~USE_PERSONALISATION | -
         role = .StructuredUtteranceConstant~USE_TARGET_SELECTION | -
         role = .StructuredUtteranceConstant~USE_RISK_AVOIDANCE
::method analyze class
  use arg utterance
  findings = .array~new
  if utterance == .nil | \utterance~sealed then return findings
  seq = 0
  do useEdge over utterance~informationUses
    segment = utterance~segmentById(useEdge~segmentId)
    act = utterance~actById(useEdge~targetActId)
    if segment == .nil | act == .nil then iterate
    lineage = utterance~lineageEdgeById(useEdge~segmentId, useEdge~lineageEdgeId)
    if lineage == .nil then iterate
    effective = self~effectiveUse(act~kind, useEdge~relationRole)
    if lineage~sourcePrivacyClass = .StructuredUtteranceConstant~PRIVACY_CUSTOMER_SENSITIVE & -
       effective = .StructuredUtteranceConstant~EFFECTIVE_USE_COMMERCIAL_PERSUASION then do
      seq += 1
      findings~append(.UtteranceUseFinding~new(utterance~utteranceId || "-use-" || seq, -
        .StructuredUtteranceConstant~FIND_SENSITIVE_COMMERCIAL_REPURPOSING, lineage~sourceRef, -
        segment~segmentId, act~actId, useEdge~relationRole, useEdge~declaredUse, effective, lineage~sourcePrivacyClass, min(useEdge~confidence, lineage~confidence)))
    end
    declared = useEdge~declaredUse
    if declared <> "" & effective <> .StructuredUtteranceConstant~EFFECTIVE_USE_UNKNOWN then do
      if self~declaredConflicts(declared, effective) then do
        seq += 1
        findings~append(.UtteranceUseFinding~new(utterance~utteranceId || "-use-" || seq, -
          .StructuredUtteranceConstant~FIND_DECLARED_USE_MISMATCH, lineage~sourceRef, -
          segment~segmentId, act~actId, useEdge~relationRole, declared, effective, lineage~sourcePrivacyClass, min(useEdge~confidence, lineage~confidence)))
      end
    end
  end
  return findings
::method declaredConflicts class
  use arg declaredArg, effectiveArg
  declared = .StructuredUtteranceCanonical~token(declaredArg)
  effective = .StructuredUtteranceCanonical~token(effectiveArg)
  if effective = .StructuredUtteranceConstant~EFFECTIVE_USE_COMMERCIAL_PERSUASION then
    return declared \= .StructuredUtteranceConstant~DECLARED_USE_COMMERCIAL_PERSUASION & declared \= .StructuredUtteranceConstant~DECLARED_USE_SALES_JUSTIFICATION
  if effective = .StructuredUtteranceConstant~EFFECTIVE_USE_SAFETY_WARNING then return declared \= .StructuredUtteranceConstant~DECLARED_USE_SAFETY_WARNING
  if effective = .StructuredUtteranceConstant~EFFECTIVE_USE_EMPATHETIC_ACK then return declared \= .StructuredUtteranceConstant~DECLARED_USE_EMPATHETIC_ACK & declared \= .StructuredUtteranceConstant~DECLARED_USE_SUPPORTIVE_CONTEXT
  if effective = .StructuredUtteranceConstant~EFFECTIVE_USE_SERVICE_RESOLUTION then return declared \= .StructuredUtteranceConstant~DECLARED_USE_SERVICE_RESOLUTION
  return .false

::class BrandExperienceContext public
::attribute sealed get
::method init
  expose domains functions opportunities sealed
  domains = .array~new
  functions = .array~new
  opportunities = .array~new
  sealed = .false
::method addDomain
  expose domains sealed
  use arg value
  if sealed then return .false
  t = .StructuredUtteranceCanonical~token(value)
  if t = "" then return .false
  if \.StructuredUtteranceCanonical~containsToken(domains, t) then domains~append(t)
  return .true
::method addFunction
  expose functions sealed
  use arg value
  if sealed then return .false
  t = .StructuredUtteranceCanonical~token(value)
  if t = "" then return .false
  if \.StructuredUtteranceCanonical~containsToken(functions, t) then functions~append(t)
  return .true
::method addOpportunity
  expose opportunities sealed
  use arg value
  if sealed then return .false
  t = .StructuredUtteranceCanonical~token(value)
  if t = "" then return .false
  if \.StructuredUtteranceCanonical~containsToken(opportunities, t) then opportunities~append(t)
  return .true
::method seal
  expose sealed
  sealed = .true
  return self
::method domains
  expose domains
  return .StructuredUtteranceCanonical~copyArray(domains)
::method functions
  expose functions
  return .StructuredUtteranceCanonical~copyArray(functions)
::method opportunities
  expose opportunities
  return .StructuredUtteranceCanonical~copyArray(opportunities)
::method isPromotionalWork
  expose functions
  return .StructuredUtteranceCanonical~containsToken(functions, .StructuredUtteranceConstant~BRAND_PROMOTIONAL_WORK)
::method isReputationalWork
  expose functions
  return .StructuredUtteranceCanonical~containsToken(functions, .StructuredUtteranceConstant~BRAND_REPUTATIONAL_WORK)
::method isCommercialRelationshipWork
  expose functions
  return .StructuredUtteranceCanonical~containsToken(functions, .StructuredUtteranceConstant~BRAND_COMMERCIAL_RELATIONSHIP_WORK)
::method serviceAsSales class
  c = self~new
  c~addDomain(.StructuredUtteranceConstant~DOMAIN_SUPPORT)
  c~addFunction(.StructuredUtteranceConstant~BRAND_ENGAGEMENT)
  c~addFunction(.StructuredUtteranceConstant~BRAND_PROMOTIONAL_WORK)
  c~addFunction(.StructuredUtteranceConstant~BRAND_REPUTATIONAL_WORK)
  c~addFunction(.StructuredUtteranceConstant~BRAND_COMMERCIAL_RELATIONSHIP_WORK)
  c~addOpportunity(.StructuredUtteranceConstant~OPP_TRUST_MAINTENANCE)
  c~addOpportunity(.StructuredUtteranceConstant~OPP_RETENTION)
  return c
::method deliveryAsSales class
  c = self~new
  c~addDomain(.StructuredUtteranceConstant~DOMAIN_DELIVERY)
  c~addFunction(.StructuredUtteranceConstant~BRAND_ENGAGEMENT)
  c~addFunction(.StructuredUtteranceConstant~BRAND_PROMOTIONAL_WORK)
  c~addFunction(.StructuredUtteranceConstant~BRAND_REPUTATIONAL_WORK)
  c~addFunction(.StructuredUtteranceConstant~BRAND_COMMERCIAL_RELATIONSHIP_WORK)
  c~addOpportunity(.StructuredUtteranceConstant~OPP_TRUST_MAINTENANCE)
  c~addOpportunity(.StructuredUtteranceConstant~OPP_RETENTION)
  return c
::method canonicalText
  expose domains functions opportunities
  return .StructuredUtteranceCanonical~join("DOMAIN", domains) || -
         .StructuredUtteranceCanonical~join("FUNCTION", functions) || -
         .StructuredUtteranceCanonical~join("OPPORTUNITY", opportunities)

::class StructuredUtterance subclass AlchemyObject public
::attribute utteranceId get
::attribute actorKind get
::attribute surface get
::attribute inReplyTo get
::attribute createdAt get
::attribute brandContext get
::attribute sealed get
::method init
  expose utteranceId actorKind surface inReplyTo createdAt brandContext segments speechActs correlations contextTags acts informationUses generationIntents sealed
  use arg utteranceIdArg, actorKindArg = "AGENT", surfaceArg = "CHAT", inReplyToArg = "", brandContextArg = .nil, createdAtArg = .nil
  meta = .directory~new
  meta["purpose"] = "Pre-flattening structured utterance and generation-intent evidence"
  meta["package_version"] = .StructuredUtteranceBuild~VERSION
  meta["api_version"] = .StructuredUtteranceBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerStateVariable("utteranceId", "INTERNAL", "stable structured utterance identifier")
  self~registerStateVariable("actorKind", "INTERNAL", "controlled actor kind")
  self~registerStateVariable("surface", "INTERNAL", "controlled interaction surface")
  self~registerStateVariable("sealed", "INTERNAL", "immutability state")
  self~registerMethodContract("VALIDATE", "validate structural integrity without asserting business correctness", .array~new, "STRUCTUREDUTTERANCERESULT", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerMethodContract("SEAL", "validate and freeze the structured utterance", .array~new, "STRUCTUREDUTTERANCERESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("CANONICALTEXT", "canonical internal evidence including customer-derived content", .array~new, "STRING", .false, "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("ANALYSISFINDINGS", "derive purpose/lineage crossover candidates from sealed structure", .array~new, "ARRAY", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE.SEAL.BEFORE", "before structural seal", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE.SEAL.AFTER", "after successful structural seal", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE.SEAL.FAIL", "structural seal rejected", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "0.4.3", .true)
  utteranceId = utteranceIdArg~string
  actorKind = .StructuredUtteranceCanonical~token(actorKindArg)
  surface = .StructuredUtteranceCanonical~token(surfaceArg)
  inReplyTo = inReplyToArg~string
  if createdAtArg == .nil then createdAt = .DateTime~new; else createdAt = createdAtArg
  if brandContextArg == .nil then brandContext = .BrandExperienceContext~new; else brandContext = brandContextArg
  if utteranceId = "" | actorKind = "" | surface = "" then raise syntax 88.973 array("StructuredUtterance requires id, actorKind, and surface")
  segments = .array~new
  speechActs = .array~new
  correlations = .array~new
  contextTags = .array~new
  acts = .array~new
  informationUses = .array~new
  generationIntents = .array~new
  sealed = .false
::method addSegment
  expose segments sealed
  use arg segment
  if sealed | segment == .nil then return .false
  segments~append(segment)
  return .true
::method addSpeechAct
  expose speechActs sealed
  use arg value
  if sealed then return .false
  t = .StructuredUtteranceCanonical~token(value)
  if t = "" then return .false
  if \.StructuredUtteranceCanonical~containsToken(speechActs, t) then speechActs~append(t)
  return .true
::method addCorrelation
  expose correlations sealed
  use arg value
  if sealed then return .false
  s = value~string
  if s = "" then return .false
  if \.StructuredUtteranceCanonical~containsToken(correlations, s) then correlations~append(s)
  return .true
::method addContextTag
  expose contextTags sealed
  use arg value
  if sealed then return .false
  t = .StructuredUtteranceCanonical~token(value)
  if t = "" then return .false
  if \.StructuredUtteranceCanonical~containsToken(contextTags, t) then contextTags~append(t)
  return .true
::method addAct
  expose acts sealed
  use arg act
  if sealed | act == .nil then return .false
  acts~append(act)
  return .true
::method addInformationUse
  expose informationUses sealed
  use arg edge
  if sealed | edge == .nil then return .false
  informationUses~append(edge)
  return .true
::method addGenerationIntent
  expose generationIntents sealed
  use arg intent
  if sealed | intent == .nil then return .false
  generationIntents~append(intent)
  return .true
::method acts
  expose acts
  return .StructuredUtteranceCanonical~copyArray(acts)
::method informationUses
  expose informationUses
  return .StructuredUtteranceCanonical~copyArray(informationUses)
::method generationIntents
  expose generationIntents
  return .StructuredUtteranceCanonical~copyArray(generationIntents)
::method segmentById
  expose segments
  use arg idArg
  id = idArg~string
  do segment over segments; if segment~segmentId = id then return segment; end
  return .nil
::method actById
  expose acts
  use arg idArg
  id = idArg~string
  do act over acts; if act~actId = id then return act; end
  return .nil
::method informationUseById
  expose informationUses
  use arg idArg
  id = idArg~string
  do edge over informationUses; if edge~useEdgeId = id then return edge; end
  return .nil
::method lineageEdgeById
  use arg segmentIdArg, edgeIdArg
  segment = self~segmentById(segmentIdArg)
  if segment == .nil then return .nil
  id = edgeIdArg~string
  do edge over segment~lineage; if edge~edgeId = id then return edge; end
  return .nil
::method analysisFindings
  return .StructuredUtteranceAnalyzer~analyze(self)
::method segments
  expose segments
  return .StructuredUtteranceCanonical~copyArray(segments)
::method speechActs
  expose speechActs
  return .StructuredUtteranceCanonical~copyArray(speechActs)
::method correlations
  expose correlations
  return .StructuredUtteranceCanonical~copyArray(correlations)
::method contextTags
  expose contextTags
  return .StructuredUtteranceCanonical~copyArray(contextTags)
::method hasPurpose
  expose segments
  use arg purposeArg
  p = .StructuredUtteranceCanonical~token(purposeArg)
  do segment over segments
    if segment~primaryPurpose = p then return .true
  end
  return .false
::method hasExplicitSalesProposition
  return self~hasPurpose(.StructuredUtteranceConstant~PURPOSE_SALESPROP)
::method pointId
  expose utteranceId
  return "STRUCTURED_UTTERANCE:" || utteranceId
::method validate
  expose utteranceId segments acts informationUses generationIntents
  if segments~items = 0 then return .StructuredUtteranceResult~failure("UTTERANCE_NO_SEGMENTS", utteranceId)
  segmentIds = .directory~new
  do segment over segments
    if segmentIds~hasIndex(segment~segmentId) then return .StructuredUtteranceResult~failure("UTTERANCE_DUPLICATE_SEGMENT", segment~segmentId)
    segmentIds[segment~segmentId] = .true
    if \segment~sealed then return .StructuredUtteranceResult~failure("UTTERANCE_SEGMENT_NOT_SEALED", segment~segmentId)
    vr = segment~validate
    if \vr~ok then return vr
  end
  actIds = .directory~new
  do act over acts
    if actIds~hasIndex(act~actId) then return .StructuredUtteranceResult~failure("UTTERANCE_DUPLICATE_ACT", act~actId)
    actIds[act~actId] = .true
    if \act~sealed then return .StructuredUtteranceResult~failure("UTTERANCE_ACT_NOT_SEALED", act~actId)
    ar = act~validate
    if \ar~ok then return ar
    do sid over act~segmentIds
      if \segmentIds~hasIndex(sid) then return .StructuredUtteranceResult~failure("UTTERANCE_ACT_SEGMENT_MISSING", act~actId || ":" || sid)
    end
  end
  useIds = .directory~new
  do ue over informationUses
    if useIds~hasIndex(ue~useEdgeId) then return .StructuredUtteranceResult~failure("UTTERANCE_DUPLICATE_INFORMATION_USE", ue~useEdgeId)
    useIds[ue~useEdgeId] = .true
    if \ue~sealed then return .StructuredUtteranceResult~failure("UTTERANCE_INFORMATION_USE_NOT_SEALED", ue~useEdgeId)
    if \segmentIds~hasIndex(ue~segmentId) then return .StructuredUtteranceResult~failure("UTTERANCE_INFORMATION_USE_SEGMENT_MISSING", ue~useEdgeId)
    if \actIds~hasIndex(ue~targetActId) then return .StructuredUtteranceResult~failure("UTTERANCE_INFORMATION_USE_ACT_MISSING", ue~useEdgeId)
    if self~lineageEdgeById(ue~segmentId, ue~lineageEdgeId) == .nil then return .StructuredUtteranceResult~failure("UTTERANCE_INFORMATION_USE_LINEAGE_MISSING", ue~useEdgeId)
  end
  intentIds = .directory~new
  do intent over generationIntents
    if intentIds~hasIndex(intent~intentId) then return .StructuredUtteranceResult~failure("UTTERANCE_DUPLICATE_INTENT", intent~intentId)
    intentIds[intent~intentId] = .true
    if \intent~sealed then return .StructuredUtteranceResult~failure("UTTERANCE_INTENT_NOT_SEALED", intent~intentId)
    if \actIds~hasIndex(intent~targetActId) then return .StructuredUtteranceResult~failure("UTTERANCE_INTENT_ACT_MISSING", intent~intentId)
    do uid over intent~informationUseIds
      if \useIds~hasIndex(uid) then return .StructuredUtteranceResult~failure("UTTERANCE_INTENT_USE_MISSING", intent~intentId || ":" || uid)
    end
  end
  return .StructuredUtteranceResult~success(self)
::method seal
  expose sealed segments acts informationUses generationIntents utteranceId brandContext
  ev = .directory~new
  ev["utterance_id"] = utteranceId
  ev["segments"] = segments~items
  ev["acts"] = acts~items
  ev["information_uses"] = informationUses~items
  ev["generation_intents"] = generationIntents~items
  self~alchemyInstrument("STRUCTURED_UTTERANCE.SEAL.BEFORE", ev)
  r = self~validate
  if \r~ok then do
    failEv = .directory~new
    failEv["utterance_id"] = utteranceId
    failEv["code"] = r~code
    self~alchemyInstrument("STRUCTURED_UTTERANCE.SEAL.FAIL", failEv)
    return r
  end
  brandContext~seal
  sealed = .true
  self~alchemyInstrument("STRUCTURED_UTTERANCE.SEAL.AFTER", ev)
  return .StructuredUtteranceResult~success(self)
::method canonicalText
  expose utteranceId actorKind surface inReplyTo createdAt brandContext segments speechActs correlations contextTags acts informationUses generationIntents sealed
  if \sealed then raise syntax 93.972 additional("StructuredUtterance must be sealed before canonicalisation")
  out = .StructuredUtteranceCanonical~field("UTTERANCE", utteranceId)
  out ||= .StructuredUtteranceCanonical~field("ACTOR", actorKind)
  out ||= .StructuredUtteranceCanonical~field("SURFACE", surface)
  out ||= .StructuredUtteranceCanonical~field("IN_REPLY_TO", inReplyTo)
  out ||= .StructuredUtteranceCanonical~field("CREATED_AT", createdAt)
  out ||= .StructuredUtteranceCanonical~field("BRAND", brandContext~canonicalText)
  out ||= .StructuredUtteranceCanonical~join("SPEECH_ACT", speechActs)
  out ||= .StructuredUtteranceCanonical~join("CORRELATION", correlations)
  out ||= .StructuredUtteranceCanonical~join("CONTEXT", contextTags)
  actTexts = .array~new
  do act over acts; actTexts~append(act~canonicalText); end
  out ||= .StructuredUtteranceCanonical~join("ACT", actTexts)
  useTexts = .array~new
  do ue over informationUses; useTexts~append(ue~canonicalText); end
  out ||= .StructuredUtteranceCanonical~join("INFORMATION_USE", useTexts)
  intentTexts = .array~new
  do intent over generationIntents; intentTexts~append(intent~canonicalText); end
  out ||= .StructuredUtteranceCanonical~join("GENERATION_INTENT", intentTexts)
  segmentTexts = .array~new
  do segment over segments; segmentTexts~append(segment~canonicalText); end
  out ||= .StructuredUtteranceCanonical~join("SEGMENT", segmentTexts)
  return out

::class UtteranceProjectionPolicy public
::attribute policyId get
::attribute mode get
::method init
  expose policyId mode
  use arg policyIdArg = "DEIDENTIFIED_ANALYTIC", modeArg = "DEIDENTIFIED_ANALYTIC"
  policyId = policyIdArg~string
  mode = .StructuredUtteranceCanonical~token(modeArg)
::method full class
  return self~new("FULL_INTERNAL", "FULL_INTERNAL")
::method deidentified class
  return self~new("DEIDENTIFIED_ANALYTIC", "DEIDENTIFIED_ANALYTIC")
::method placeholderFor
  use arg segment
  select
    when segment~dataRole = .StructuredUtteranceConstant~DATA_CUSTNAME then return "[CUSTOMER_RELATED_PERSON]"
    when segment~dataRole = .StructuredUtteranceConstant~DATA_CUSTREF then return "[CUSTOMER_REFERENCE]"
    when segment~dataRole = .StructuredUtteranceConstant~DATA_CUSTSENSITIVE then return "[CUSTOMER_SENSITIVE_INFORMATION]"
    when segment~dataRole = .StructuredUtteranceConstant~DATA_CUSTDATA then return "[CUSTOMER_DATA]"
    when segment~privacyClass = .StructuredUtteranceConstant~PRIVACY_UNKNOWN then return "[UNCLASSIFIED_REDACTED]"
    otherwise return "[REDACTED]"
  end
::method projectText
  expose mode
  use arg segment
  if mode = "FULL_INTERNAL" then return segment~text
  if segment~retentionClass = .StructuredUtteranceConstant~DROP then return self~placeholderFor(segment)
  if segment~privacyClass = .StructuredUtteranceConstant~PRIVACY_UNKNOWN then return self~placeholderFor(segment)
  if segment~retentionClass = .StructuredUtteranceConstant~ABSTRACT_ONLY then do
    if segment~abstractText <> "" then return segment~abstractText
    return self~placeholderFor(segment)
  end
  p = segment~privacyClass
  if p = .StructuredUtteranceConstant~PRIVACY_PUBLIC | p = .StructuredUtteranceConstant~PRIVACY_ORGANISATION | p = .StructuredUtteranceConstant~PRIVACY_DERIVED_NONCUSTOMER then return segment~text
  if segment~abstractText <> "" then return segment~abstractText
  return self~placeholderFor(segment)

::class StructuredUtteranceRenderer public
::method renderDelivery class
  use arg utterance
  if utterance == .nil | \utterance~sealed then return .StructuredUtteranceResult~failure("UTTERANCE_NOT_SEALED")
  out = ""
  do segment over utterance~segments
    out ||= segment~separatorBefore || segment~text
  end
  return .StructuredUtteranceResult~success(out)
::method renderDeidentified class
  use arg utterance, policy = .nil
  if policy == .nil then policy = .UtteranceProjectionPolicy~deidentified
  if utterance == .nil | \utterance~sealed then return .StructuredUtteranceResult~failure("UTTERANCE_NOT_SEALED")
  out = ""
  do segment over utterance~segments
    out ||= segment~separatorBefore || policy~projectText(segment)
  end
  return .StructuredUtteranceResult~success(out)
::method renderTagged class
  use arg utterance, policy = .nil
  if policy == .nil then policy = .UtteranceProjectionPolicy~deidentified
  if utterance == .nil | \utterance~sealed then return .StructuredUtteranceResult~failure("UTTERANCE_NOT_SEALED")
  out = ""
  currentPurpose = ""
  do segment over utterance~segments
    purpose = segment~primaryPurpose
    if purpose \= currentPurpose then do
      if currentPurpose <> "" then out ||= "<</" || currentPurpose || ">>"
      out ||= segment~separatorBefore
      out ||= "<<" || purpose || ">>"
      currentPurpose = purpose
    end
    else out ||= segment~separatorBefore
    text = policy~projectText(segment)
    if segment~dataRole \= .StructuredUtteranceConstant~DATA_NONE then
      out ||= "<<" || segment~dataRole || ">>" || text || "<</" || segment~dataRole || ">>"
    else out ||= text
  end
  if currentPurpose <> "" then out ||= "<</" || currentPurpose || ">>"
  return .StructuredUtteranceResult~success(out)

::class StructuredUtterancePoint public
::attribute pointId get
::attribute utteranceId get
::attribute pointKind get
::attribute token get
::attribute segmentId get
::method init
  expose pointId utteranceId pointKind token segmentId
  use arg utteranceIdArg, pointKindArg, tokenArg = "", segmentIdArg = ""
  utteranceId = utteranceIdArg~string
  pointKind = .StructuredUtteranceCanonical~token(pointKindArg)
  token = .StructuredUtteranceCanonical~token(tokenArg)
  segmentId = segmentIdArg~string
  pointId = "STRUCTURED_UTTERANCE:" || utteranceId
  if segmentId <> "" then pointId ||= ":SEGMENT:" || segmentId
  if pointKind <> "UTTERANCE" then pointId ||= ":" || pointKind
  if token <> "" then pointId ||= ":" || token

::class StructuredUtteranceLibrary public
::method init
  expose utterances order
  utterances = .directory~new
  order = .array~new
::method capture
  expose utterances order
  use arg utterance
  if utterance == .nil then return .StructuredUtteranceResult~failure("UTTERANCE_REQUIRED")
  if \utterance~sealed then return .StructuredUtteranceResult~failure("UTTERANCE_NOT_SEALED", utterance~utteranceId)
  id = utterance~utteranceId
  if utterances~hasIndex(id) then return .StructuredUtteranceResult~failure("UTTERANCE_DUPLICATE", id)
  utterances[id] = utterance
  order~append(id)
  return .StructuredUtteranceResult~success(.StructuredUtterancePoint~new(id, "UTTERANCE"))
::method utterance
  expose utterances
  use arg utteranceId
  id = utteranceId~string
  if utterances~hasIndex(id) then return utterances[id]
  return .nil
::method pointsFor
  use arg utteranceId
  u = self~utterance(utteranceId)
  out = .array~new
  if u == .nil then return out
  out~append(.StructuredUtterancePoint~new(u~utteranceId, "UTTERANCE"))
  do segment over u~segments
    out~append(.StructuredUtterancePoint~new(u~utteranceId, "PURPOSE", segment~primaryPurpose, segment~segmentId))
    if segment~dataRole \= .StructuredUtteranceConstant~DATA_NONE then out~append(.StructuredUtterancePoint~new(u~utteranceId, "DATA", segment~dataRole, segment~segmentId))
    do role over segment~roles
      out~append(.StructuredUtterancePoint~new(u~utteranceId, "ROLE", role, segment~segmentId))
    end
  end
  do act over u~acts
    out~append(.StructuredUtterancePoint~new(u~utteranceId, "ACT", act~kind, act~actId))
  end
  do ue over u~informationUses
    out~append(.StructuredUtterancePoint~new(u~utteranceId, "INFORMATION_USE", ue~relationRole, ue~segmentId))
  end
  do intent over u~generationIntents
    out~append(.StructuredUtterancePoint~new(u~utteranceId, "GENERATION_INTENT", intent~intendedAct, intent~targetActId))
  end
  do finding over u~analysisFindings
    out~append(.StructuredUtterancePoint~new(u~utteranceId, "FINDING", finding~code, finding~segmentId))
  end
  do domain over u~brandContext~domains
    out~append(.StructuredUtterancePoint~new(u~utteranceId, "BRAND_DOMAIN", domain))
  end
  do f over u~brandContext~functions
    out~append(.StructuredUtterancePoint~new(u~utteranceId, "BRAND_FUNCTION", f))
  end
  do opp over u~brandContext~opportunities
    out~append(.StructuredUtterancePoint~new(u~utteranceId, "BRAND_OPPORTUNITY", opp))
  end
  return out
::method pointsMatching
  use arg utteranceId, pointKindArg, tokenArg
  kind = .StructuredUtteranceCanonical~token(pointKindArg)
  token = .StructuredUtteranceCanonical~token(tokenArg)
  out = .array~new
  do p over self~pointsFor(utteranceId)
    if p~pointKind = kind & p~token = token then out~append(p)
  end
  return out
::method allUtterances
  expose utterances order
  out = .array~new
  do id over order; out~append(utterances[id]); end
  return out

::requires 'AlchemyObject.cls'
