/*
 * Interaction Event v0.3
 *
 * Provenance-preserving rich interaction-event model and capture library.
 * Access-point instrumentation is intentionally external.  This package owns
 * event shape, evidence-bearing assessments, privacy-aware content elements,
 * event links, projections, and append-only capture/query behaviour.
 */

::class InteractionEventBuild public
::constant VERSION "0.3"
::constant API_VERSION "interaction.event/0.3"
::constant PRODUCT "ooRexx Interaction Event"

::class InteractionAlchemySupport public
::method metadata class
  use arg purposeArg
  d = .directory~new
  d["purpose"] = purposeArg~string
  d["package_version"] = .InteractionEventBuild~VERSION
  d["api_version"] = .InteractionEventBuild~API_VERSION
  d["component"] = "INTERACTION_EVENT"
  return d

::class InteractionConstant public
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

::constant ORIGIN_CUSTOMER "CUSTOMER_INPUT"
::constant ORIGIN_AGENT "AGENT_OUTPUT"
::constant ORIGIN_MODEL "MODEL_DERIVED"
::constant ORIGIN_TELEMETRY "TELEMETRY"
::constant ORIGIN_SYSTEM "SYSTEM"

::constant LINK_PRECEDES "PRECEDES"
::constant LINK_RESPONDS_TO "RESPONDS_TO"
::constant LINK_EVIDENCE_FOR "EVIDENCE_FOR"
::constant LINK_CANDIDATE_TRIGGER "CANDIDATE_TRIGGER"
::constant LINK_STEP_OF "STEP_OF"
::constant LINK_OUTCOME_OF "OUTCOME_OF"
::constant LINK_RECOVERY_FROM "RECOVERY_FROM"

::constant CAUSAL_NONE "NONE"
::constant CAUSAL_ASSOCIATED "ASSOCIATED"
::constant CAUSAL_CANDIDATE "CANDIDATE_NOT_PROVEN"
::constant CAUSAL_ESTABLISHED "ESTABLISHED_BY_EXTERNAL_AUTHORITY"

::constant ASSESS_SENTIMENT "CUSTOMER_SENTIMENT"
::constant ASSESS_STYLE "COMMUNICATION_STYLE"
::constant ASSESS_ENGAGEMENT "ENGAGEMENT_STATE"
::constant ASSESS_EFFECT "CANDIDATE_EFFECT"
::constant ASSESS_COUNTERFACTUAL "COUNTERFACTUAL"

::class InteractionResult public
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

::class InteractionCanonical public
::method clamp class
  use arg value, low = 0, high = 100
  n = value + 0
  if n < low then return low
  if n > high then return high
  return n
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
  out = .table~new
  if source == .nil then return out
  do key over source
    out[key] = source[key]
  end
  return out
::method containsString class
  use arg source, wanted
  wanted = wanted~string~upper
  if source == .nil then return .false
  do item over source
    if item~string~upper == wanted then return .true
  end
  return .false
::method field class
  use arg tag, value = ""
  if value == .nil then rendered = "<NIL>"
  else rendered = value~string
  return tag~string || ":" || rendered~length || ":" || rendered
::method join class
  use arg tag, source
  values = .array~new
  if source \== .nil then do item over source; values~append(item~string); end
  values~sort
  text = self~field(tag || "_COUNT", values~items)
  do value over values
    text ||= self~field(tag, value)
  end
  return text
::method token class
  use arg value
  s = value~string~upper~strip
  if s = "" then return ""
  if verify(s, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-/:") <> 0 then return ""
  return s
::method safeScalar class
  use arg value
  if datatype(value, "N") then return .true
  return self~token(value) <> ""

::class InteractionReference public
::attribute refKind get
::attribute value get
::attribute abstractValue get
::attribute privacyClass get
::attribute originKind get
::method init
  expose refKind value abstractValue privacyClass originKind
  use arg refKindArg, valueArg, privacyClassArg = "UNKNOWN", abstractValueArg = "", originKindArg = "SYSTEM"
  refKind = .InteractionCanonical~token(refKindArg)
  if refKind = "" then raise syntax 88.901 array("InteractionReference refKind must be a token")
  value = valueArg~string
  privacyClass = .InteractionCanonical~token(privacyClassArg)
  if privacyClass = "" then privacyClass = .InteractionConstant~PRIVACY_UNKNOWN
  abstractValue = abstractValueArg~string
  originKind = .InteractionCanonical~token(originKindArg)
  if originKind = "" then originKind = .InteractionConstant~ORIGIN_SYSTEM
::method canonicalText
  expose refKind value abstractValue privacyClass originKind
  return .InteractionCanonical~field("REF_KIND", refKind) || -
         .InteractionCanonical~field("VALUE", value) || -
         .InteractionCanonical~field("ABSTRACT", abstractValue) || -
         .InteractionCanonical~field("PRIVACY", privacyClass) || -
         .InteractionCanonical~field("ORIGIN", originKind)

::class InteractionContentElement subclass AlchemyObject public
::attribute elementId get
::attribute semanticType get
::attribute value get
::attribute abstractValue get
::attribute privacyClass get
::attribute retentionClass get
::attribute originKind get
::attribute sourceRef get
::attribute sourceSpan get
::attribute confidence get
::method init
  expose elementId semanticType value abstractValue privacyClass retentionClass originKind sourceRef sourceSpan confidence metadata
  use arg elementIdArg, semanticTypeArg, valueArg = "", privacyClassArg = "UNKNOWN", abstractValueArg = "", retentionClassArg = "RETAIN", originKindArg = "SYSTEM", sourceRefArg = "", sourceSpanArg = "", confidenceArg = 100, metadataArg = .nil, alchemySealerArg = .nil, alchemyAuthorityArg = .nil
  elementId = elementIdArg~string
  if elementId = "" then raise syntax 88.902 array("InteractionContentElement elementId must not be empty")
  semanticType = .InteractionCanonical~token(semanticTypeArg)
  if semanticType = "" then raise syntax 88.903 array("InteractionContentElement semanticType must be a token")
  value = valueArg~string
  privacyClass = .InteractionCanonical~token(privacyClassArg)
  if privacyClass = "" then privacyClass = .InteractionConstant~PRIVACY_UNKNOWN
  abstractValue = abstractValueArg~string
  retentionClass = .InteractionCanonical~token(retentionClassArg)
  if retentionClass = "" then retentionClass = .InteractionConstant~RETAIN
  originKind = .InteractionCanonical~token(originKindArg)
  if originKind = "" then originKind = .InteractionConstant~ORIGIN_SYSTEM
  sourceRef = sourceRefArg~string
  sourceSpan = sourceSpanArg~string
  confidence = .InteractionCanonical~clamp(confidenceArg)
  if metadataArg == .nil then metadata = .table~new
  else metadata = .InteractionCanonical~copyTable(metadataArg)
  self~initAlchemy(.InteractionAlchemySupport~metadata("privacy-aware interaction content element"), alchemySealerArg, alchemyAuthorityArg)
  self~registerStateVariable("elementId", "CUSTOMER", "stable content-element identifier")
  self~registerStateVariable("semanticType", "CUSTOMER", "semantic classification token")
  self~registerStateVariable("privacyClass", "INTERNAL", "privacy classification; never inferred safe by introspection")
  self~registerStateVariable("retentionClass", "INTERNAL", "retention/projection rule")
  self~registerStateVariable("originKind", "INTERNAL", "information provenance category")
  self~registerStateVariable("sourceRef", "SECRET", "source lineage reference may identify customer material")
  self~registerStateVariable("sourceSpan", "SECRET", "source span may expose customer text position")
  self~registerStateVariable("value", "SECRET", "raw content is never exposed by generic customer introspection")
  self~registerStateVariable("abstractValue", "INTERNAL", "candidate abstraction remains policy-controlled")
  self~registerStateVariable("confidence", "CUSTOMER", "classification confidence")
  self~registerMethodContract("CANONICALTEXT", "canonical evidence representation", .array~new, "STRING", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method metadata
  expose metadata
  return .InteractionCanonical~copyTable(metadata)
::method canonicalText
  expose elementId semanticType value abstractValue privacyClass retentionClass originKind sourceRef sourceSpan confidence metadata
  text = .InteractionCanonical~field("ELEMENT", elementId)
  text ||= .InteractionCanonical~field("TYPE", semanticType)
  text ||= .InteractionCanonical~field("VALUE", value)
  text ||= .InteractionCanonical~field("ABSTRACT", abstractValue)
  text ||= .InteractionCanonical~field("PRIVACY", privacyClass)
  text ||= .InteractionCanonical~field("RETENTION", retentionClass)
  text ||= .InteractionCanonical~field("ORIGIN", originKind)
  text ||= .InteractionCanonical~field("SOURCE_REF", sourceRef)
  text ||= .InteractionCanonical~field("SOURCE_SPAN", sourceSpan)
  text ||= .InteractionCanonical~field("CONFIDENCE", confidence)
  pairs = .array~new
  do key over metadata
    pairs~append(key~string || "=" || metadata[key]~string)
  end
  text ||= .InteractionCanonical~join("META", pairs)
  return text

::class InteractionEvidenceAnchor public
::attribute sourceId get
::attribute sourceKind get
::attribute locator get
::attribute observedAt get
::attribute confidence get
::method init
  expose sourceId sourceKind locator observedAt confidence metadata
  use arg sourceIdArg, sourceKindArg, locatorArg = "", observedAtArg = .nil, confidenceArg = 100, metadataArg = .nil
  sourceId = sourceIdArg~string
  sourceKind = .InteractionCanonical~token(sourceKindArg)
  if sourceKind = "" then raise syntax 88.904 array("InteractionEvidenceAnchor sourceKind must be a token")
  locator = locatorArg~string
  if observedAtArg == .nil then observedAt = .DateTime~new
  else observedAt = observedAtArg
  confidence = .InteractionCanonical~clamp(confidenceArg)
  if metadataArg == .nil then metadata = .table~new
  else metadata = .InteractionCanonical~copyTable(metadataArg)
::method metadata
  expose metadata
  return .InteractionCanonical~copyTable(metadata)
::method canonicalText
  expose sourceId sourceKind locator observedAt confidence metadata
  text = .InteractionCanonical~field("SOURCE_ID", sourceId)
  text ||= .InteractionCanonical~field("SOURCE_KIND", sourceKind)
  text ||= .InteractionCanonical~field("LOCATOR", locator)
  text ||= .InteractionCanonical~field("OBSERVED_AT", observedAt)
  text ||= .InteractionCanonical~field("CONFIDENCE", confidence)
  pairs = .array~new
  do key over metadata
    pairs~append(key~string || "=" || metadata[key]~string)
  end
  text ||= .InteractionCanonical~join("META", pairs)
  return text

::class InteractionAssessment subclass AlchemyObject public
::attribute assessmentId get
::attribute eventId get
::attribute assessmentType get
::attribute value get
::attribute assessorKind get
::attribute assessorId get
::attribute modelId get
::attribute confidence get
::attribute createdAt get
::attribute sealed get
::method init
  expose assessmentId eventId assessmentType value assessorKind assessorId modelId confidence createdAt dimensions evidenceRefs detailElements sealed
  use arg assessmentIdArg, eventIdArg, assessmentTypeArg, valueArg, assessorKindArg = "MODEL", assessorIdArg = "", modelIdArg = "", confidenceArg = 50, createdAtArg = .nil, alchemySealerArg = .nil, alchemyAuthorityArg = .nil
  assessmentId = assessmentIdArg~string
  eventId = eventIdArg~string
  assessmentType = .InteractionCanonical~token(assessmentTypeArg)
  value = .InteractionCanonical~token(valueArg)
  assessorKind = .InteractionCanonical~token(assessorKindArg)
  assessorId = assessorIdArg~string
  modelId = modelIdArg~string
  confidence = .InteractionCanonical~clamp(confidenceArg)
  if createdAtArg == .nil then createdAt = .DateTime~new
  else createdAt = createdAtArg
  if assessmentId = "" | eventId = "" | assessmentType = "" | value = "" then raise syntax 88.905 array("InteractionAssessment requires id, event, token type, and token value")
  if assessorKind = "" then assessorKind = "MODEL"
  dimensions = .table~new
  evidenceRefs = .array~new
  detailElements = .array~new
  sealed = .false
  self~initAlchemy(.InteractionAlchemySupport~metadata("immutable-by-seal assessed interpretation of an interaction event"), alchemySealerArg, alchemyAuthorityArg)
  self~registerStateVariable("assessmentId", "CUSTOMER", "assessment identifier")
  self~registerStateVariable("eventId", "INTERNAL", "event linkage identifier")
  self~registerStateVariable("assessmentType", "CUSTOMER", "assessment taxonomy dimension")
  self~registerStateVariable("value", "CUSTOMER", "controlled assessment value; assessment is not fact")
  self~registerStateVariable("assessorKind", "CUSTOMER", "assessor authority class")
  self~registerStateVariable("assessorId", "INTERNAL", "assessor identity")
  self~registerStateVariable("modelId", "INTERNAL", "model/classifier provenance")
  self~registerStateVariable("confidence", "CUSTOMER", "assessment confidence")
  self~registerStateVariable("createdAt", "CUSTOMER", "assessment time")
  self~registerStateVariable("dimensions", "INTERNAL", "controlled scalar dimensions")
  self~registerStateVariable("evidenceRefs", "INTERNAL", "supporting evidence point references")
  self~registerStateVariable("detailElements", "SECRET", "privacy-bearing explanatory detail elements")
  self~registerStateVariable("sealed", "CUSTOMER", "assessment seal state")
  self~registerInstrumentationPoint("INTERACTION.ASSESSMENT.SEALED", "assessment became immutable for evidence use", .true, "ALL", "INTERNAL")
  self~registerMethodContract("ADDDIMENSION", "add controlled scalar assessment dimension", .array~of("NAME","VALUE"), "BOOLEAN", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("SEAL", "seal assessment against further mutation", .array~new, "INTERACTIONASSESSMENT", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("CANONICALTEXT", "canonical sealed assessment evidence", .array~new, "STRING", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method addDimension
  expose dimensions sealed
  use arg nameArg, valueArg
  if sealed then return .false
  name = .InteractionCanonical~token(nameArg)
  if name = "" then return .false
  if \.InteractionCanonical~safeScalar(valueArg) then return .false
  dimensions[name] = valueArg
  return .true
::method addEvidenceRef
  expose evidenceRefs sealed
  use arg value
  if sealed then return .false
  if value~string = "" then return .false
  evidenceRefs~append(value~string)
  return .true
::method addDetailElement
  expose detailElements sealed
  use arg element
  if sealed | element == .nil then return .false
  detailElements~append(element)
  return .true
::method dimensions
  expose dimensions
  return .InteractionCanonical~copyTable(dimensions)
::method evidenceRefs
  expose evidenceRefs
  return .InteractionCanonical~copyArray(evidenceRefs)
::method detailElements
  expose detailElements
  return .InteractionCanonical~copyArray(detailElements)
::method seal
  expose sealed
  sealed = .true
  self~alchemyTouch("ASSESSMENT_SEAL")
  self~alchemyInstrument("INTERACTION.ASSESSMENT.SEALED", self~assessmentId)
  return self
::method canonicalText
  expose assessmentId eventId assessmentType value assessorKind assessorId modelId confidence createdAt dimensions evidenceRefs detailElements sealed
  if \sealed then raise syntax 93.901 additional("InteractionAssessment must be sealed before canonicalisation")
  text = .InteractionCanonical~field("ASSESSMENT", assessmentId)
  text ||= .InteractionCanonical~field("EVENT", eventId)
  text ||= .InteractionCanonical~field("TYPE", assessmentType)
  text ||= .InteractionCanonical~field("VALUE", value)
  text ||= .InteractionCanonical~field("ASSESSOR_KIND", assessorKind)
  text ||= .InteractionCanonical~field("ASSESSOR_ID", assessorId)
  text ||= .InteractionCanonical~field("MODEL_ID", modelId)
  text ||= .InteractionCanonical~field("CONFIDENCE", confidence)
  text ||= .InteractionCanonical~field("CREATED_AT", createdAt)
  pairs = .array~new
  do key over dimensions
    pairs~append(key~string || "=" || dimensions[key]~string)
  end
  text ||= .InteractionCanonical~join("DIM", pairs)
  text ||= .InteractionCanonical~join("EVIDENCE_REF", evidenceRefs)
  detailTexts = .array~new
  do element over detailElements
    detailTexts~append(element~canonicalText)
  end
  text ||= .InteractionCanonical~join("DETAIL", detailTexts)
  return text


/* Native pre-flattening evidence objects.
 *
 * These are deliberately controlled token/scalar records, not prose bags.
 * Structured Utterance can therefore hand information-use, generation-intent
 * and derived-finding residue to downstream evidence consumers without
 * smuggling customer wording into an apparently safe metadata field.
 */
::class InteractionInformationUseEvidence subclass AlchemyObject public
::attribute useEdgeId get
::attribute segmentId get
::attribute sourceRef get
::attribute sourceLineageKind get
::attribute sourcePrivacyClass get
::attribute targetActId get
::attribute targetActKind get
::attribute relationRole get
::attribute declaredUse get
::attribute effectiveUse get
::attribute authorityKind get
::attribute authorityId get
::attribute confidence get
::attribute sealed get
::method init
  expose useEdgeId segmentId sourceRef sourceLineageKind sourcePrivacyClass targetActId targetActKind relationRole declaredUse effectiveUse authorityKind authorityId confidence sealed
  use arg useEdgeIdArg, segmentIdArg, sourceRefArg = "", sourceLineageKindArg = "", sourcePrivacyClassArg = "UNKNOWN", targetActIdArg = "", targetActKindArg = "", relationRoleArg = "", declaredUseArg = "", effectiveUseArg = "", authorityKindArg = "", authorityIdArg = "", confidenceArg = 100, alchemySealerArg = .nil, alchemyAuthorityArg = .nil
  useEdgeId = .InteractionCanonical~token(useEdgeIdArg)
  segmentId = .InteractionCanonical~token(segmentIdArg)
  sourceRef = self~optionalToken(sourceRefArg, "sourceRef")
  sourceLineageKind = self~optionalToken(sourceLineageKindArg, "sourceLineageKind")
  sourcePrivacyClass = .InteractionCanonical~token(sourcePrivacyClassArg)
  targetActId = self~optionalToken(targetActIdArg, "targetActId")
  targetActKind = self~optionalToken(targetActKindArg, "targetActKind")
  relationRole = self~optionalToken(relationRoleArg, "relationRole")
  declaredUse = self~optionalToken(declaredUseArg, "declaredUse")
  effectiveUse = self~optionalToken(effectiveUseArg, "effectiveUse")
  authorityKind = self~optionalToken(authorityKindArg, "authorityKind")
  authorityId = self~optionalToken(authorityIdArg, "authorityId")
  if useEdgeId = "" | segmentId = "" then raise syntax 88.920 array("InteractionInformationUseEvidence requires token useEdgeId and segmentId")
  if sourcePrivacyClass = "" then sourcePrivacyClass = .InteractionConstant~PRIVACY_UNKNOWN
  confidence = .InteractionCanonical~clamp(confidenceArg)
  sealed = .false
  self~initAlchemy(.InteractionAlchemySupport~metadata("native structured information-use evidence"), alchemySealerArg, alchemyAuthorityArg)
  self~registerStateVariable("useEdgeId", "CUSTOMER", "stable information-use evidence identifier")
  self~registerStateVariable("segmentId", "INTERNAL", "structured segment identifier")
  self~registerStateVariable("sourceRef", "SECRET", "source lineage reference may identify customer material")
  self~registerStateVariable("sourceLineageKind", "CUSTOMER", "controlled lineage category")
  self~registerStateVariable("sourcePrivacyClass", "CUSTOMER", "privacy floor of source information")
  self~registerStateVariable("targetActId", "INTERNAL", "target communicative-act identifier")
  self~registerStateVariable("targetActKind", "CUSTOMER", "controlled target act kind")
  self~registerStateVariable("relationRole", "CUSTOMER", "controlled use relation")
  self~registerStateVariable("declaredUse", "CUSTOMER", "producer-declared information use")
  self~registerStateVariable("effectiveUse", "CUSTOMER", "derived effective information use")
  self~registerStateVariable("authorityKind", "INTERNAL", "asserting authority category")
  self~registerStateVariable("authorityId", "INTERNAL", "asserting authority identifier")
  self~registerStateVariable("confidence", "CUSTOMER", "evidence confidence")
  self~registerStateVariable("sealed", "CUSTOMER", "evidence immutability state")
  self~registerMethodContract("CANONICALTEXT", "canonical information-use evidence", .array~new, "STRING", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method optionalToken private
  use arg value, fieldName
  s = value~string~strip
  if s = "" then return ""
  t = .InteractionCanonical~token(s)
  if t = "" then raise syntax 88.921 array("InteractionInformationUseEvidence " || fieldName || " must be an opaque token, not prose")
  return t
::method pointId
  expose useEdgeId
  return "INTERACTION_INFORMATION_USE:" || useEdgeId
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose useEdgeId segmentId sourceRef sourceLineageKind sourcePrivacyClass targetActId targetActKind relationRole declaredUse effectiveUse authorityKind authorityId confidence
  text = .InteractionCanonical~field("USE_EDGE", useEdgeId)
  text ||= .InteractionCanonical~field("SEGMENT", segmentId)
  text ||= .InteractionCanonical~field("SOURCE_REF", sourceRef)
  text ||= .InteractionCanonical~field("SOURCE_LINEAGE", sourceLineageKind)
  text ||= .InteractionCanonical~field("SOURCE_PRIVACY", sourcePrivacyClass)
  text ||= .InteractionCanonical~field("TARGET_ACT", targetActId)
  text ||= .InteractionCanonical~field("TARGET_ACT_KIND", targetActKind)
  text ||= .InteractionCanonical~field("RELATION_ROLE", relationRole)
  text ||= .InteractionCanonical~field("DECLARED_USE", declaredUse)
  text ||= .InteractionCanonical~field("EFFECTIVE_USE", effectiveUse)
  text ||= .InteractionCanonical~field("AUTHORITY_KIND", authorityKind)
  text ||= .InteractionCanonical~field("AUTHORITY_ID", authorityId)
  text ||= .InteractionCanonical~field("CONFIDENCE", confidence)
  return text

::class InteractionGenerationIntentEvidence subclass AlchemyObject public
::attribute intentId get
::attribute targetActId get
::attribute intendedAct get
::attribute intendedRegister get
::attribute intendedOutcome get
::attribute authorityKind get
::attribute authorityId get
::attribute sourcePointRef get
::attribute confidence get
::attribute sealed get
::method init
  expose intentId targetActId intendedAct intendedRegister intendedOutcome authorityKind authorityId sourcePointRef confidence informationUseRefs sealed
  use arg intentIdArg, targetActIdArg, intendedActArg, intendedRegisterArg = "", intendedOutcomeArg = "", authorityKindArg = "", authorityIdArg = "", sourcePointRefArg = "", confidenceArg = 100, alchemySealerArg = .nil, alchemyAuthorityArg = .nil
  intentId = .InteractionCanonical~token(intentIdArg)
  targetActId = .InteractionCanonical~token(targetActIdArg)
  intendedAct = .InteractionCanonical~token(intendedActArg)
  intendedRegister = self~optionalToken(intendedRegisterArg, "intendedRegister")
  intendedOutcome = self~optionalToken(intendedOutcomeArg, "intendedOutcome")
  authorityKind = self~optionalToken(authorityKindArg, "authorityKind")
  authorityId = self~optionalToken(authorityIdArg, "authorityId")
  sourcePointRef = self~optionalToken(sourcePointRefArg, "sourcePointRef")
  if intentId = "" | targetActId = "" | intendedAct = "" then raise syntax 88.922 array("InteractionGenerationIntentEvidence requires token intentId, targetActId and intendedAct")
  confidence = .InteractionCanonical~clamp(confidenceArg)
  informationUseRefs = .array~new
  sealed = .false
  self~initAlchemy(.InteractionAlchemySupport~metadata("native structured generation-intent evidence"), alchemySealerArg, alchemyAuthorityArg)
  self~registerStateVariable("intentId", "CUSTOMER", "stable generation-intent evidence identifier")
  self~registerStateVariable("targetActId", "INTERNAL", "target communicative-act identifier")
  self~registerStateVariable("intendedAct", "CUSTOMER", "controlled intended act")
  self~registerStateVariable("intendedRegister", "CUSTOMER", "controlled intended register")
  self~registerStateVariable("intendedOutcome", "CUSTOMER", "controlled intended outcome")
  self~registerStateVariable("authorityKind", "INTERNAL", "asserting authority category")
  self~registerStateVariable("authorityId", "INTERNAL", "asserting authority identifier")
  self~registerStateVariable("sourcePointRef", "INTERNAL", "opaque source evidence point")
  self~registerStateVariable("informationUseRefs", "INTERNAL", "native information-use evidence references")
  self~registerStateVariable("confidence", "CUSTOMER", "evidence confidence")
  self~registerStateVariable("sealed", "CUSTOMER", "evidence immutability state")
  self~registerMethodContract("ADDINFORMATIONUSEREF", "attach opaque information-use reference before sealing", .array~of("REFERENCE"), "BOOLEAN", .false, "AUTO", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("CANONICALTEXT", "canonical generation-intent evidence", .array~new, "STRING", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method optionalToken private
  use arg value, fieldName
  s = value~string~strip
  if s = "" then return ""
  t = .InteractionCanonical~token(s)
  if t = "" then raise syntax 88.923 array("InteractionGenerationIntentEvidence " || fieldName || " must be an opaque token, not prose")
  return t
::method addInformationUseRef
  expose informationUseRefs sealed
  use arg reference
  if sealed then return .false
  t = .InteractionCanonical~token(reference)
  if t = "" then return .false
  if \.InteractionCanonical~containsString(informationUseRefs, t) then informationUseRefs~append(t)
  return .true
::method informationUseRefs
  expose informationUseRefs
  return .InteractionCanonical~copyArray(informationUseRefs)
::method pointId
  expose intentId
  return "INTERACTION_GENERATION_INTENT:" || intentId
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose intentId targetActId intendedAct intendedRegister intendedOutcome authorityKind authorityId sourcePointRef confidence informationUseRefs
  text = .InteractionCanonical~field("INTENT", intentId)
  text ||= .InteractionCanonical~field("TARGET_ACT", targetActId)
  text ||= .InteractionCanonical~field("INTENDED_ACT", intendedAct)
  text ||= .InteractionCanonical~field("INTENDED_REGISTER", intendedRegister)
  text ||= .InteractionCanonical~field("INTENDED_OUTCOME", intendedOutcome)
  text ||= .InteractionCanonical~field("AUTHORITY_KIND", authorityKind)
  text ||= .InteractionCanonical~field("AUTHORITY_ID", authorityId)
  text ||= .InteractionCanonical~field("SOURCE_POINT", sourcePointRef)
  text ||= .InteractionCanonical~field("CONFIDENCE", confidence)
  text ||= .InteractionCanonical~join("INFORMATION_USE_REF", informationUseRefs)
  return text

::class InteractionDerivedFinding subclass AlchemyObject public
::attribute findingId get
::attribute code get
::attribute sourceKind get
::attribute sourceId get
::attribute confidence get
::attribute sealed get
::method init
  expose findingId code sourceKind sourceId confidence evidenceRefs sealed
  use arg findingIdArg, codeArg, sourceKindArg = "", sourceIdArg = "", confidenceArg = 100, alchemySealerArg = .nil, alchemyAuthorityArg = .nil
  findingId = .InteractionCanonical~token(findingIdArg)
  code = .InteractionCanonical~token(codeArg)
  sourceKind = self~optionalToken(sourceKindArg, "sourceKind")
  sourceId = self~optionalToken(sourceIdArg, "sourceId")
  if findingId = "" | code = "" then raise syntax 88.924 array("InteractionDerivedFinding requires token findingId and code")
  confidence = .InteractionCanonical~clamp(confidenceArg)
  evidenceRefs = .array~new
  sealed = .false
  self~initAlchemy(.InteractionAlchemySupport~metadata("native derived interaction finding"), alchemySealerArg, alchemyAuthorityArg)
  self~registerStateVariable("findingId", "CUSTOMER", "stable derived-finding identifier")
  self~registerStateVariable("code", "CUSTOMER", "controlled finding code")
  self~registerStateVariable("sourceKind", "CUSTOMER", "controlled source analyzer category")
  self~registerStateVariable("sourceId", "INTERNAL", "source analyzer identifier")
  self~registerStateVariable("evidenceRefs", "INTERNAL", "opaque evidence references")
  self~registerStateVariable("confidence", "CUSTOMER", "finding confidence")
  self~registerStateVariable("sealed", "CUSTOMER", "evidence immutability state")
  self~registerMethodContract("ADDEVIDENCEREF", "attach opaque evidence reference before sealing", .array~of("REFERENCE"), "BOOLEAN", .false, "AUTO", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("CANONICALTEXT", "canonical derived finding evidence", .array~new, "STRING", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method optionalToken private
  use arg value, fieldName
  s = value~string~strip
  if s = "" then return ""
  t = .InteractionCanonical~token(s)
  if t = "" then raise syntax 88.925 array("InteractionDerivedFinding " || fieldName || " must be an opaque token, not prose")
  return t
::method addEvidenceRef
  expose evidenceRefs sealed
  use arg reference
  if sealed then return .false
  t = .InteractionCanonical~token(reference)
  if t = "" then return .false
  if \.InteractionCanonical~containsString(evidenceRefs, t) then evidenceRefs~append(t)
  return .true
::method evidenceRefs
  expose evidenceRefs
  return .InteractionCanonical~copyArray(evidenceRefs)
::method pointId
  expose findingId
  return "INTERACTION_DERIVED_FINDING:" || findingId
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose findingId code sourceKind sourceId confidence evidenceRefs
  text = .InteractionCanonical~field("FINDING", findingId)
  text ||= .InteractionCanonical~field("CODE", code)
  text ||= .InteractionCanonical~field("SOURCE_KIND", sourceKind)
  text ||= .InteractionCanonical~field("SOURCE_ID", sourceId)
  text ||= .InteractionCanonical~field("CONFIDENCE", confidence)
  text ||= .InteractionCanonical~join("EVIDENCE_REF", evidenceRefs)
  return text

::class InteractionEvent subclass AlchemyObject public
::attribute eventId get
::attribute eventKind get
::attribute actorRef get
::attribute subjectRef get
::attribute surface get
::attribute accessPointId get
::attribute direction get
::attribute occurredAt get
::attribute observedAt get
::attribute sealed get
::method init
  expose eventId eventKind actorRef subjectRef surface accessPointId direction occurredAt observedAt content evidence tags correlations informationUses generationIntents derivedFindings sealed
  use arg eventIdArg, eventKindArg, actorRefArg = .nil, surfaceArg = "", accessPointIdArg = "", directionArg = "", occurredAtArg = .nil, observedAtArg = .nil, subjectRefArg = .nil, alchemySealerArg = .nil, alchemyAuthorityArg = .nil
  eventId = eventIdArg~string
  eventKind = .InteractionCanonical~token(eventKindArg)
  if eventId = "" | eventKind = "" then raise syntax 88.906 array("InteractionEvent requires eventId and token eventKind")
  actorRef = actorRefArg
  subjectRef = subjectRefArg
  surface = .InteractionCanonical~token(surfaceArg)
  accessPointId = accessPointIdArg~string
  direction = .InteractionCanonical~token(directionArg)
  if occurredAtArg == .nil then occurredAt = .DateTime~new
  else occurredAt = occurredAtArg
  if observedAtArg == .nil then observedAt = occurredAt
  else observedAt = observedAtArg
  content = .array~new
  evidence = .array~new
  tags = .array~new
  correlations = .array~new
  informationUses = .array~new
  generationIntents = .array~new
  derivedFindings = .array~new
  sealed = .false
  self~initAlchemy(.InteractionAlchemySupport~metadata("provenance-preserving rich interaction event"), alchemySealerArg, alchemyAuthorityArg)
  self~registerStateVariable("eventId", "CUSTOMER", "stable event identifier")
  self~registerStateVariable("eventKind", "CUSTOMER", "controlled event kind")
  self~registerStateVariable("actorRef", "SECRET", "actor reference can contain customer-specific material")
  self~registerStateVariable("subjectRef", "SECRET", "subject reference can contain customer-specific material")
  self~registerStateVariable("surface", "CUSTOMER", "interaction surface token")
  self~registerStateVariable("accessPointId", "INTERNAL", "externally owned access-point identifier")
  self~registerStateVariable("direction", "CUSTOMER", "interaction direction")
  self~registerStateVariable("occurredAt", "CUSTOMER", "event occurrence time")
  self~registerStateVariable("observedAt", "CUSTOMER", "observation time")
  self~registerStateVariable("content", "SECRET", "raw/privacy-bearing content elements")
  self~registerStateVariable("evidence", "INTERNAL", "evidence anchors")
  self~registerStateVariable("tags", "CUSTOMER", "controlled event tags")
  self~registerStateVariable("correlations", "INTERNAL", "journey/correlation identifiers")
  self~registerStateVariable("informationUses", "INTERNAL", "native controlled information-use evidence")
  self~registerStateVariable("generationIntents", "INTERNAL", "native controlled generation-intent evidence")
  self~registerStateVariable("derivedFindings", "INTERNAL", "native controlled derived findings")
  self~registerStateVariable("sealed", "CUSTOMER", "event seal state")
  self~registerInstrumentationPoint("INTERACTION.EVENT.CONTENT_ADDED", "privacy-bearing content element attached", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("INTERACTION.EVENT.SEALED", "event became immutable for capture", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("INTERACTION.EVENT.STRUCTURED_EVIDENCE_ADDED", "native pre-flattening evidence attached", .true, "ALL", "INTERNAL")
  self~registerMethodContract("ADDCONTENT", "attach content element before sealing", .array~of("ELEMENT"), "BOOLEAN", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("ADDTAG", "attach controlled semantic tag before sealing", .array~of("TAG"), "BOOLEAN", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("ADDINFORMATIONUSE", "attach native information-use evidence before sealing", .array~of("EVIDENCE"), "BOOLEAN", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("ADDGENERATIONINTENT", "attach native generation-intent evidence before sealing", .array~of("EVIDENCE"), "BOOLEAN", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("ADDDERIVEDFINDING", "attach native derived finding before sealing", .array~of("FINDING"), "BOOLEAN", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("SEAL", "seal event against further mutation", .array~new, "INTERACTIONEVENT", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("CANONICALTEXT", "canonical sealed event evidence", .array~new, "STRING", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method addContent
  expose content sealed
  use arg element
  if sealed | element == .nil then return .false
  content~append(element)
  if element~hasMethod("ALCHEMYOBJECTID") then self~recordRelationship("CONTAINS", element, "interaction content element", "INTERNAL")
  self~alchemyTouch("EVENT_ADD_CONTENT")
  self~alchemyInstrument("INTERACTION.EVENT.CONTENT_ADDED", element~elementId)
  return .true
::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed | anchor == .nil then return .false
  evidence~append(anchor)
  return .true
::method addTag
  expose tags sealed
  use arg value
  if sealed then return .false
  token = .InteractionCanonical~token(value)
  if token = "" then return .false
  if \.InteractionCanonical~containsString(tags, token) then tags~append(token)
  return .true
::method addCorrelation
  expose correlations sealed
  use arg value
  if sealed then return .false
  id = value~string
  if id = "" then return .false
  if \.InteractionCanonical~containsString(correlations, id) then correlations~append(id)
  return .true
::method addInformationUse
  expose informationUses sealed
  use arg item
  if sealed | item == .nil then return .false
  if item~class \== .InteractionInformationUseEvidence then return .false
  do existing over informationUses
    if existing~useEdgeId = item~useEdgeId then return .false
  end
  item~seal
  informationUses~append(item)
  self~recordRelationship("USES", item, "native structured information-use evidence", "INTERNAL")
  self~alchemyTouch("EVENT_ADD_INFORMATION_USE")
  self~alchemyInstrument("INTERACTION.EVENT.STRUCTURED_EVIDENCE_ADDED", item~pointId)
  return .true
::method addGenerationIntent
  expose generationIntents sealed
  use arg item
  if sealed | item == .nil then return .false
  if item~class \== .InteractionGenerationIntentEvidence then return .false
  do existing over generationIntents
    if existing~intentId = item~intentId then return .false
  end
  item~seal
  generationIntents~append(item)
  self~recordRelationship("USES", item, "native structured generation-intent evidence", "INTERNAL")
  self~alchemyTouch("EVENT_ADD_GENERATION_INTENT")
  self~alchemyInstrument("INTERACTION.EVENT.STRUCTURED_EVIDENCE_ADDED", item~pointId)
  return .true
::method addDerivedFinding
  expose derivedFindings sealed
  use arg item
  if sealed | item == .nil then return .false
  if item~class \== .InteractionDerivedFinding then return .false
  do existing over derivedFindings
    if existing~findingId = item~findingId then return .false
  end
  item~seal
  derivedFindings~append(item)
  self~recordRelationship("USES", item, "native structured derived finding", "INTERNAL")
  self~alchemyTouch("EVENT_ADD_DERIVED_FINDING")
  self~alchemyInstrument("INTERACTION.EVENT.STRUCTURED_EVIDENCE_ADDED", item~pointId)
  return .true
::method informationUses
  expose informationUses
  return .InteractionCanonical~copyArray(informationUses)
::method generationIntents
  expose generationIntents
  return .InteractionCanonical~copyArray(generationIntents)
::method derivedFindings
  expose derivedFindings
  return .InteractionCanonical~copyArray(derivedFindings)
::method content
  expose content
  return .InteractionCanonical~copyArray(content)
::method evidence
  expose evidence
  return .InteractionCanonical~copyArray(evidence)
::method tags
  expose tags
  return .InteractionCanonical~copyArray(tags)
::method correlations
  expose correlations
  return .InteractionCanonical~copyArray(correlations)
::method hasCorrelation
  expose correlations
  use arg value
  return .InteractionCanonical~containsString(correlations, value)
::method pointId
  expose eventId
  return "INTERACTION_EVENT:" || eventId
::method seal
  expose sealed
  sealed = .true
  self~alchemyTouch("EVENT_SEAL")
  self~alchemyInstrument("INTERACTION.EVENT.SEALED", self~eventId)
  return self
::method canonicalText
  expose eventId eventKind actorRef subjectRef surface accessPointId direction occurredAt observedAt content evidence tags correlations informationUses generationIntents derivedFindings sealed
  if \sealed then raise syntax 93.902 additional("InteractionEvent must be sealed before canonicalisation")
  text = .InteractionCanonical~field("EVENT_ID", eventId)
  text ||= .InteractionCanonical~field("EVENT_KIND", eventKind)
  if actorRef == .nil then actorText = "NONE"; else actorText = actorRef~canonicalText
  if subjectRef == .nil then subjectText = "NONE"; else subjectText = subjectRef~canonicalText
  text ||= .InteractionCanonical~field("ACTOR", actorText)
  text ||= .InteractionCanonical~field("SUBJECT", subjectText)
  text ||= .InteractionCanonical~field("SURFACE", surface)
  text ||= .InteractionCanonical~field("ACCESS_POINT", accessPointId)
  text ||= .InteractionCanonical~field("DIRECTION", direction)
  text ||= .InteractionCanonical~field("OCCURRED_AT", occurredAt)
  text ||= .InteractionCanonical~field("OBSERVED_AT", observedAt)
  contentTexts = .array~new
  do element over content
    contentTexts~append(element~canonicalText)
  end
  evidenceTexts = .array~new
  do anchor over evidence
    evidenceTexts~append(anchor~canonicalText)
  end
  text ||= .InteractionCanonical~join("CONTENT", contentTexts)
  text ||= .InteractionCanonical~join("EVIDENCE", evidenceTexts)
  text ||= .InteractionCanonical~join("TAG", tags)
  text ||= .InteractionCanonical~join("CORRELATION", correlations)
  useTexts = .array~new
  do item over informationUses; useTexts~append(item~canonicalText); end
  intentTexts = .array~new
  do item over generationIntents; intentTexts~append(item~canonicalText); end
  findingTexts = .array~new
  do item over derivedFindings; findingTexts~append(item~canonicalText); end
  text ||= .InteractionCanonical~join("INFORMATION_USE", useTexts)
  text ||= .InteractionCanonical~join("GENERATION_INTENT", intentTexts)
  text ||= .InteractionCanonical~join("DERIVED_FINDING", findingTexts)
  return text

::class InteractionEventPoint public
::attribute pointId get
::attribute eventId get
::attribute eventKind get
::attribute accessPointId get
::method init
  expose pointId eventId eventKind accessPointId correlations
  use arg event
  if event == .nil then raise syntax 88.907 array("InteractionEventPoint requires event")
  pointId = event~pointId
  eventId = event~eventId
  eventKind = event~eventKind
  accessPointId = event~accessPointId
  correlations = event~correlations
::method correlations
  expose correlations
  return .InteractionCanonical~copyArray(correlations)

::class InteractionLink subclass AlchemyObject public
::attribute linkId get
::attribute fromEventId get
::attribute toEventId get
::attribute linkKind get
::attribute confidence get
::attribute causalStatus get
::attribute createdBy get
::attribute createdAt get
::method init
  expose linkId fromEventId toEventId linkKind confidence causalStatus createdBy createdAt evidenceRefs
  use arg linkIdArg, fromEventIdArg, toEventIdArg, linkKindArg, confidenceArg = 100, causalStatusArg = "NONE", createdByArg = "", createdAtArg = .nil, evidenceRefsArg = .nil, alchemySealerArg = .nil, alchemyAuthorityArg = .nil
  linkId = linkIdArg~string
  fromEventId = fromEventIdArg~string
  toEventId = toEventIdArg~string
  linkKind = .InteractionCanonical~token(linkKindArg)
  causalStatus = .InteractionCanonical~token(causalStatusArg)
  createdBy = createdByArg~string
  confidence = .InteractionCanonical~clamp(confidenceArg)
  if createdAtArg == .nil then createdAt = .DateTime~new
  else createdAt = createdAtArg
  if linkId = "" | fromEventId = "" | toEventId = "" | linkKind = "" then raise syntax 88.908 array("InteractionLink requires ids and token linkKind")
  if causalStatus = "" then causalStatus = .InteractionConstant~CAUSAL_NONE
  if evidenceRefsArg == .nil then evidenceRefs = .array~new
  else evidenceRefs = .InteractionCanonical~copyArray(evidenceRefsArg)
  self~initAlchemy(.InteractionAlchemySupport~metadata("explicit event relationship and causal-status evidence"), alchemySealerArg, alchemyAuthorityArg)
  self~registerStateVariable("linkId", "CUSTOMER", "link identifier")
  self~registerStateVariable("fromEventId", "INTERNAL", "source event identifier")
  self~registerStateVariable("toEventId", "INTERNAL", "target event identifier")
  self~registerStateVariable("linkKind", "CUSTOMER", "relationship kind")
  self~registerStateVariable("confidence", "CUSTOMER", "relationship confidence")
  self~registerStateVariable("causalStatus", "CUSTOMER", "explicit causal epistemic status")
  self~registerStateVariable("createdBy", "INTERNAL", "asserting authority/assessor identity")
  self~registerStateVariable("createdAt", "CUSTOMER", "link creation time")
  self~registerStateVariable("evidenceRefs", "INTERNAL", "supporting evidence references")
  self~registerMethodContract("CANONICALTEXT", "canonical event-link evidence", .array~new, "STRING", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method evidenceRefs
  expose evidenceRefs
  return .InteractionCanonical~copyArray(evidenceRefs)
::method canonicalText
  expose linkId fromEventId toEventId linkKind confidence causalStatus createdBy createdAt evidenceRefs
  text = .InteractionCanonical~field("LINK", linkId)
  text ||= .InteractionCanonical~field("FROM", fromEventId)
  text ||= .InteractionCanonical~field("TO", toEventId)
  text ||= .InteractionCanonical~field("KIND", linkKind)
  text ||= .InteractionCanonical~field("CONFIDENCE", confidence)
  text ||= .InteractionCanonical~field("CAUSAL_STATUS", causalStatus)
  text ||= .InteractionCanonical~field("CREATED_BY", createdBy)
  text ||= .InteractionCanonical~field("CREATED_AT", createdAt)
  text ||= .InteractionCanonical~join("EVIDENCE_REF", evidenceRefs)
  return text

::class InteractionProjectionPolicy public
::attribute policyId get
::attribute mode get
::method init
  expose policyId mode
  use arg policyIdArg = "DEIDENTIFIED_ANALYTIC", modeArg = "DEIDENTIFIED_ANALYTIC"
  policyId = policyIdArg~string
  mode = .InteractionCanonical~token(modeArg)
::method full class
  return self~new("FULL_INTERNAL", "FULL_INTERNAL")
::method deidentified class
  return self~new("DEIDENTIFIED_ANALYTIC", "DEIDENTIFIED_ANALYTIC")
::method projectReference
  expose mode
  use arg reference
  if reference == .nil then return .nil
  if mode = "FULL_INTERNAL" then return .InteractionProjectedReference~new(reference~refKind, reference~value, reference~privacyClass, "RAW")
  pc = reference~privacyClass
  if pc = .InteractionConstant~PRIVACY_PUBLIC | pc = .InteractionConstant~PRIVACY_ORGANISATION | pc = .InteractionConstant~PRIVACY_DERIVED_NONCUSTOMER then
    return .InteractionProjectedReference~new(reference~refKind, reference~value, pc, "RAW")
  if pc = .InteractionConstant~PRIVACY_UNKNOWN then return .nil
  if reference~abstractValue <> "" then return .InteractionProjectedReference~new(reference~refKind, reference~abstractValue, pc, "ABSTRACTED")
  return .nil
::method projectElement
  expose mode
  use arg element
  if element == .nil then return .nil
  if element~retentionClass = .InteractionConstant~DROP then return .nil
  if mode = "FULL_INTERNAL" then
    return .InteractionProjectedElement~new(element~elementId, element~semanticType, element~value, element~privacyClass, "RAW", element~originKind, element~confidence)
  pc = element~privacyClass
  if pc = .InteractionConstant~PRIVACY_UNKNOWN then return .nil
  if element~retentionClass = .InteractionConstant~ABSTRACT_ONLY then do
    if element~abstractValue = "" then return .nil
    return .InteractionProjectedElement~new(element~elementId, element~semanticType, element~abstractValue, pc, "ABSTRACTED", element~originKind, element~confidence)
  end
  if pc = .InteractionConstant~PRIVACY_PUBLIC | pc = .InteractionConstant~PRIVACY_ORGANISATION | pc = .InteractionConstant~PRIVACY_DERIVED_NONCUSTOMER then
    return .InteractionProjectedElement~new(element~elementId, element~semanticType, element~value, pc, "RAW", element~originKind, element~confidence)
  if element~abstractValue <> "" then
    return .InteractionProjectedElement~new(element~elementId, element~semanticType, element~abstractValue, pc, "ABSTRACTED", element~originKind, element~confidence)
  return .nil

::class InteractionProjectedReference public
::attribute refKind get
::attribute value get
::attribute sourcePrivacyClass get
::attribute projectionKind get
::method init
  expose refKind value sourcePrivacyClass projectionKind
  use arg refKindArg, valueArg, sourcePrivacyClassArg, projectionKindArg
  refKind = refKindArg
  value = valueArg
  sourcePrivacyClass = sourcePrivacyClassArg
  projectionKind = projectionKindArg

::class InteractionProjectedElement public
::attribute elementId get
::attribute semanticType get
::attribute value get
::attribute sourcePrivacyClass get
::attribute projectionKind get
::attribute originKind get
::attribute confidence get
::method init
  expose elementId semanticType value sourcePrivacyClass projectionKind originKind confidence
  use arg elementIdArg, semanticTypeArg, valueArg, sourcePrivacyClassArg, projectionKindArg, originKindArg, confidenceArg
  elementId = elementIdArg
  semanticType = semanticTypeArg
  value = valueArg
  sourcePrivacyClass = sourcePrivacyClassArg
  projectionKind = projectionKindArg
  originKind = originKindArg
  confidence = confidenceArg

::class InteractionProjectedAssessment public
::attribute assessmentId get
::attribute eventId get
::attribute assessmentType get
::attribute value get
::attribute assessorKind get
::attribute assessorId get
::attribute modelId get
::attribute confidence get
::method init
  expose assessmentId eventId assessmentType value assessorKind assessorId modelId confidence dimensions details
  use arg assessment, projectedDetails
  assessmentId = assessment~assessmentId
  eventId = assessment~eventId
  assessmentType = assessment~assessmentType
  value = assessment~value
  assessorKind = assessment~assessorKind
  assessorId = assessment~assessorId
  modelId = assessment~modelId
  confidence = assessment~confidence
  dimensions = assessment~dimensions
  if projectedDetails == .nil then details = .array~new
  else details = projectedDetails
::method dimensions
  expose dimensions
  return .InteractionCanonical~copyTable(dimensions)
::method details
  expose details
  return .InteractionCanonical~copyArray(details)


::class InteractionProjectedInformationUseEvidence public
::attribute useEdgeId get
::attribute segmentId get
::attribute sourceRef get
::attribute sourceLineageKind get
::attribute sourcePrivacyClass get
::attribute targetActId get
::attribute targetActKind get
::attribute relationRole get
::attribute declaredUse get
::attribute effectiveUse get
::attribute authorityKind get
::attribute authorityId get
::attribute confidence get
::method init
  expose useEdgeId segmentId sourceRef sourceLineageKind sourcePrivacyClass targetActId targetActKind relationRole declaredUse effectiveUse authorityKind authorityId confidence
  use arg item, projectedSourceRef = ""
  useEdgeId=item~useEdgeId; segmentId=item~segmentId; sourceRef=projectedSourceRef
  sourceLineageKind=item~sourceLineageKind; sourcePrivacyClass=item~sourcePrivacyClass
  targetActId=item~targetActId; targetActKind=item~targetActKind; relationRole=item~relationRole
  declaredUse=item~declaredUse; effectiveUse=item~effectiveUse; authorityKind=item~authorityKind
  authorityId=item~authorityId; confidence=item~confidence
::method pointId
  expose useEdgeId
  return "INTERACTION_INFORMATION_USE:" || useEdgeId

::class InteractionProjectedGenerationIntentEvidence public
::attribute intentId get
::attribute targetActId get
::attribute intendedAct get
::attribute intendedRegister get
::attribute intendedOutcome get
::attribute authorityKind get
::attribute authorityId get
::attribute sourcePointRef get
::attribute confidence get
::method init
  expose intentId targetActId intendedAct intendedRegister intendedOutcome authorityKind authorityId sourcePointRef confidence informationUseRefs
  use arg item
  intentId=item~intentId; targetActId=item~targetActId; intendedAct=item~intendedAct
  intendedRegister=item~intendedRegister; intendedOutcome=item~intendedOutcome
  authorityKind=item~authorityKind; authorityId=item~authorityId; sourcePointRef=item~sourcePointRef
  confidence=item~confidence; informationUseRefs=item~informationUseRefs
::method informationUseRefs
  expose informationUseRefs
  return .InteractionCanonical~copyArray(informationUseRefs)
::method pointId
  expose intentId
  return "INTERACTION_GENERATION_INTENT:" || intentId

::class InteractionProjectedDerivedFinding public
::attribute findingId get
::attribute code get
::attribute sourceKind get
::attribute sourceId get
::attribute confidence get
::method init
  expose findingId code sourceKind sourceId confidence evidenceRefs
  use arg item
  findingId=item~findingId; code=item~code; sourceKind=item~sourceKind; sourceId=item~sourceId
  confidence=item~confidence; evidenceRefs=item~evidenceRefs
::method evidenceRefs
  expose evidenceRefs
  return .InteractionCanonical~copyArray(evidenceRefs)
::method pointId
  expose findingId
  return "INTERACTION_DERIVED_FINDING:" || findingId

::class InteractionProjectedEvent public
::attribute eventId get
::attribute eventKind get
::attribute actorRef get
::attribute subjectRef get
::attribute surface get
::attribute accessPointId get
::attribute direction get
::attribute occurredAt get
::attribute observedAt get
::method init
  expose eventId eventKind actorRef subjectRef surface accessPointId direction occurredAt observedAt content tags correlations assessments informationUses generationIntents derivedFindings
  use arg event, projectedActor, projectedSubject, projectedContent, projectedAssessments, projectedInformationUses = .nil, projectedGenerationIntents = .nil, projectedDerivedFindings = .nil
  eventId = event~eventId
  eventKind = event~eventKind
  actorRef = projectedActor
  subjectRef = projectedSubject
  surface = event~surface
  accessPointId = event~accessPointId
  direction = event~direction
  occurredAt = event~occurredAt
  observedAt = event~observedAt
  content = projectedContent
  tags = event~tags
  correlations = event~correlations
  assessments = projectedAssessments
  if projectedInformationUses == .nil then informationUses = .array~new; else informationUses = projectedInformationUses
  if projectedGenerationIntents == .nil then generationIntents = .array~new; else generationIntents = projectedGenerationIntents
  if projectedDerivedFindings == .nil then derivedFindings = .array~new; else derivedFindings = projectedDerivedFindings
::method content
  expose content
  return .InteractionCanonical~copyArray(content)
::method tags
  expose tags
  return .InteractionCanonical~copyArray(tags)
::method correlations
  expose correlations
  return .InteractionCanonical~copyArray(correlations)
::method assessments
  expose assessments
  return .InteractionCanonical~copyArray(assessments)
::method informationUses
  expose informationUses
  return .InteractionCanonical~copyArray(informationUses)
::method generationIntents
  expose generationIntents
  return .InteractionCanonical~copyArray(generationIntents)
::method derivedFindings
  expose derivedFindings
  return .InteractionCanonical~copyArray(derivedFindings)

::class InteractionCaptureLibrary subclass AlchemyObject public
::method init
  expose events captureOrder assessmentsByEvent assessmentsById links linksFrom linksTo
  use arg alchemySealerArg = .nil, alchemyAuthorityArg = .nil
  events = .directory~new
  captureOrder = .array~new
  assessmentsByEvent = .directory~new
  assessmentsById = .directory~new
  links = .directory~new
  linksFrom = .directory~new
  linksTo = .directory~new
  self~initAlchemy(.InteractionAlchemySupport~metadata("append-only interaction evidence capture library"), alchemySealerArg, alchemyAuthorityArg)
  self~registerStateVariable("events", "INTERNAL", "captured rich interaction events")
  self~registerStateVariable("captureOrder", "INTERNAL", "append-only event order")
  self~registerStateVariable("assessmentsByEvent", "INTERNAL", "assessment lineage by event")
  self~registerStateVariable("assessmentsById", "INTERNAL", "assessment identity index")
  self~registerStateVariable("links", "INTERNAL", "event relationship evidence")
  self~registerInstrumentationPoint("INTERACTION.CAPTURE.EVENT", "sealed event accepted into capture library", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("INTERACTION.CAPTURE.ASSESSMENT", "sealed assessment attached without replacing disagreement", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("INTERACTION.CAPTURE.LINK", "event relationship accepted", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("INTERACTION.PROJECTION", "privacy projection produced", .true, "COLLAPSE", "INTERNAL")
  self~registerMethodContract("CAPTUREEVENT", "capture sealed externally-fired interaction event", .array~of("EVENT"), "INTERACTIONRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("ATTACHASSESSMENT", "attach sealed assessment while preserving disagreement", .array~of("ASSESSMENT"), "INTERACTIONRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("ADDLINK", "attach event relationship or causal candidate", .array~of("LINK"), "INTERACTIONRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("PROJECTEVENT", "produce policy-bounded privacy projection", .array~of("EVENT_ID","POLICY"), "INTERACTIONRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method captureEvent
  expose events captureOrder assessmentsByEvent linksFrom linksTo
  use arg event
  if event == .nil then return .InteractionResult~failure("EVENT_REQUIRED")
  if \event~sealed then return .InteractionResult~failure("EVENT_NOT_SEALED", event~eventId)
  id = event~eventId
  if events~hasIndex(id) then return .InteractionResult~failure("EVENT_DUPLICATE", id)
  events[id] = event
  captureOrder~append(id)
  assessmentsByEvent[id] = .array~new
  linksFrom[id] = .array~new
  linksTo[id] = .array~new
  self~recordRelationship("CAPTURES", event, "sealed interaction event", "INTERNAL")
  self~alchemyTouch("CAPTURE_EVENT")
  self~alchemyInstrument("INTERACTION.CAPTURE.EVENT", event~pointId)
  return .InteractionResult~success(.InteractionEventPoint~new(event), "captured")
::method event
  expose events
  use arg eventId
  if events~hasIndex(eventId~string) then return events[eventId~string]
  return .nil
::method pointFor
  use arg eventId
  event = self~event(eventId)
  if event == .nil then return .nil
  return .InteractionEventPoint~new(event)
::method attachAssessment
  expose events assessmentsByEvent assessmentsById
  use arg assessment
  if assessment == .nil then return .InteractionResult~failure("ASSESSMENT_REQUIRED")
  if \assessment~sealed then return .InteractionResult~failure("ASSESSMENT_NOT_SEALED", assessment~assessmentId)
  if \events~hasIndex(assessment~eventId) then return .InteractionResult~failure("ASSESSMENT_EVENT_UNKNOWN", assessment~eventId)
  if assessmentsById~hasIndex(assessment~assessmentId) then return .InteractionResult~failure("ASSESSMENT_DUPLICATE", assessment~assessmentId)
  assessmentsById[assessment~assessmentId] = assessment
  bucket = assessmentsByEvent[assessment~eventId]
  bucket~append(assessment)
  self~recordRelationship("USES", assessment, "assessment attached to captured event", "INTERNAL")
  self~alchemyTouch("ATTACH_ASSESSMENT")
  self~alchemyInstrument("INTERACTION.CAPTURE.ASSESSMENT", assessment~assessmentId)
  return .InteractionResult~success(assessment)
::method assessmentsFor
  expose assessmentsByEvent
  use arg eventId
  id = eventId~string
  if \assessmentsByEvent~hasIndex(id) then return .array~new
  return .InteractionCanonical~copyArray(assessmentsByEvent[id])
::method addLink
  expose events links linksFrom linksTo
  use arg link
  if link == .nil then return .InteractionResult~failure("LINK_REQUIRED")
  if links~hasIndex(link~linkId) then return .InteractionResult~failure("LINK_DUPLICATE", link~linkId)
  if \events~hasIndex(link~fromEventId) then return .InteractionResult~failure("LINK_SOURCE_UNKNOWN", link~fromEventId)
  if \events~hasIndex(link~toEventId) then return .InteractionResult~failure("LINK_TARGET_UNKNOWN", link~toEventId)
  links[link~linkId] = link
  linksFrom[link~fromEventId]~append(link)
  linksTo[link~toEventId]~append(link)
  self~recordRelationship("USES", link, "event relationship evidence", "INTERNAL")
  self~alchemyTouch("ADD_LINK")
  self~alchemyInstrument("INTERACTION.CAPTURE.LINK", link~linkId)
  return .InteractionResult~success(link)
::method linkEvents
  use arg linkId, fromEventId, toEventId, linkKind, confidence = 100, causalStatus = "NONE", createdBy = ""
  return self~addLink(.InteractionLink~new(linkId, fromEventId, toEventId, linkKind, confidence, causalStatus, createdBy))
::method markCandidateTrigger
  use arg linkId, fromEventId, toEventId, confidence = 50, createdBy = ""
  return self~linkEvents(linkId, fromEventId, toEventId, .InteractionConstant~LINK_CANDIDATE_TRIGGER, confidence, .InteractionConstant~CAUSAL_CANDIDATE, createdBy)
::method linksFrom
  expose linksFrom
  use arg eventId
  id = eventId~string
  if \linksFrom~hasIndex(id) then return .array~new
  return .InteractionCanonical~copyArray(linksFrom[id])
::method linksTo
  expose linksTo
  use arg eventId
  id = eventId~string
  if \linksTo~hasIndex(id) then return .array~new
  return .InteractionCanonical~copyArray(linksTo[id])
::method eventsForCorrelation
  expose events captureOrder
  use arg correlationId
  out = .array~new
  do id over captureOrder
    event = events[id]
    if event~hasCorrelation(correlationId) then out~append(event)
  end
  return out
::method allEvents
  expose events captureOrder
  out = .array~new
  do id over captureOrder
    out~append(events[id])
  end
  return out
::method projectEvent
  use arg eventId, policy = .nil
  if policy == .nil then policy = .InteractionProjectionPolicy~deidentified
  event = self~event(eventId)
  if event == .nil then return .InteractionResult~failure("EVENT_UNKNOWN", eventId)
  projectedContent = .array~new
  do element over event~content
    projected = policy~projectElement(element)
    if projected \== .nil then projectedContent~append(projected)
  end
  projectedAssessments = .array~new
  do assessment over self~assessmentsFor(eventId)
    projectedDetails = .array~new
    do detail over assessment~detailElements
      projectedDetail = policy~projectElement(detail)
      if projectedDetail \== .nil then projectedDetails~append(projectedDetail)
    end
    projectedAssessments~append(.InteractionProjectedAssessment~new(assessment, projectedDetails))
  end
  projectedInformationUses = .array~new
  do item over event~informationUses
    /* The structural use evidence survives, but a customer-bearing sourceRef
       never does in the deidentified projection. */
    safeSourceRef = ""
    if policy~mode = "FULL_INTERNAL" then safeSourceRef = item~sourceRef
    else if item~sourcePrivacyClass = .InteractionConstant~PRIVACY_PUBLIC | item~sourcePrivacyClass = .InteractionConstant~PRIVACY_ORGANISATION | item~sourcePrivacyClass = .InteractionConstant~PRIVACY_DERIVED_NONCUSTOMER then safeSourceRef = item~sourceRef
    projectedInformationUses~append(.InteractionProjectedInformationUseEvidence~new(item, safeSourceRef))
  end
  projectedGenerationIntents = .array~new
  do item over event~generationIntents; projectedGenerationIntents~append(.InteractionProjectedGenerationIntentEvidence~new(item)); end
  projectedDerivedFindings = .array~new
  do item over event~derivedFindings; projectedDerivedFindings~append(.InteractionProjectedDerivedFinding~new(item)); end
  projectedEvent = .InteractionProjectedEvent~new(event, policy~projectReference(event~actorRef), policy~projectReference(event~subjectRef), projectedContent, projectedAssessments, projectedInformationUses, projectedGenerationIntents, projectedDerivedFindings)
  self~alchemyTouch("PROJECT_EVENT")
  self~alchemyInstrument("INTERACTION.PROJECTION", eventId~string || ":" || policy~mode)
  return .InteractionResult~success(projectedEvent)

::class InteractionAssessmentFactory public
::method sentiment class
  use arg assessmentId, eventId, value, assessorId, modelId = "", confidence = 50
  return .InteractionAssessment~new(assessmentId, eventId, .InteractionConstant~ASSESS_SENTIMENT, value, "MODEL", assessorId, modelId, confidence)
::method style class
  use arg assessmentId, eventId, assessorId, modelId = "", confidence = 50
  return .InteractionAssessment~new(assessmentId, eventId, .InteractionConstant~ASSESS_STYLE, "PROFILE", "MODEL", assessorId, modelId, confidence)
::method engagement class
  use arg assessmentId, eventId, value, assessorId, modelId = "", confidence = 50
  return .InteractionAssessment~new(assessmentId, eventId, .InteractionConstant~ASSESS_ENGAGEMENT, value, "MODEL", assessorId, modelId, confidence)

::requires "AlchemyObject.cls"
