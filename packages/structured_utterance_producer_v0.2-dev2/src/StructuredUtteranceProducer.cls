/* StructuredUtteranceProducer.cls
 * Provider-neutral pre-flattening handoff for Structured Utterance v0.3.
 *
 * This package deliberately does not invoke a model, parse provider text, infer
 * semantic markup from strings, or decide Brand/Legal/Security effects.  It
 * accepts generation-time structured evidence, seals it, and only then renders
 * delivery text.  A flattened provider reply is never an authoritative source
 * for reconstructing lost intent or information-use lineage.
 */

::class StructuredUtteranceProducerBuild public
::constant VERSION "0.2-dev2"
::constant API_VERSION "structured.utterance.producer/0.1"
::constant PLAN_SCHEMA "structured.utterance.producer.plan/0.1"
::constant RECORD_SCHEMA "structured.utterance.producer.record/0.1"
::constant PAYLOAD_SCHEMA "structured.utterance.production-result/0.1"
::constant GENERATION "STRUCTURED-UTTERANCE-PRODUCER-V0.2-DEV2"

::class StructuredUtteranceProducerResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = okArg == .true
  code = codeArg~string
  detail = detailArg~string
  value = valueArg
::method success class
  use arg valueArg = .nil
  return self~new(.true, "OK", "", valueArg)
::method failure class
  use arg codeArg, detailArg = "", valueArg = .nil
  return self~new(.false, codeArg, detailArg, valueArg)

::class StructuredUtteranceProducerCanonical public
::method token class
  use arg value, fieldName = "TOKEN"
  t = .StructuredUtteranceCanonical~token(value)
  if t = "" then raise syntax 88.980 array("Structured Utterance Producer invalid controlled " || fieldName)
  return t
::method optionalToken class
  use arg value
  if value == .nil then return ""
  s = value~string
  if s = "" then return ""
  return self~token(s)
::method copyArray class
  use arg source
  return .StructuredUtteranceCanonical~copyArray(source)
::method appendUniqueToken class
  use arg target, value
  t = self~token(value)
  do existing over target
    if existing = t then return .true
  end
  target~append(t)
  return .true
::method controlledRef class
  use arg value, fieldName = "REFERENCE", allowEmpty = .false
  if value == .nil then s = ""; else s = value~string
  if s = "" then do
    if allowEmpty then return ""
  end
  return self~token(s, fieldName)

/* A generation plan is the authoritative pre-flattening handoff.  It contains
 * native Structured Utterance semantic objects rather than a second competing
 * taxonomy.  The producer does not infer these objects from prose. */
::class StructuredUtteranceGenerationPlan subclass AlchemyObject public
::attribute planId get
::attribute utteranceId get
::attribute actorKind get
::attribute surface get
::attribute inReplyTo get
::attribute producerKind get
::attribute producerId get
::attribute providerInvocationRef get
::attribute modelRef get
::attribute responsePlanRef get
::attribute createdAt get
::attribute sealed get

::method init
  expose planId utteranceId actorKind surface inReplyTo producerKind producerId providerInvocationRef modelRef responsePlanRef createdAt sealed segments acts informationUses generationIntents speechActs correlations contextTags brandContext
  use arg planIdArg, utteranceIdArg, actorKindArg = "AGENT", surfaceArg = "CHAT", inReplyToArg = "", producerKindArg = "ORCHESTRATOR", producerIdArg = "UNSPECIFIED", providerInvocationRefArg = "", modelRefArg = "", responsePlanRefArg = "", createdAtArg = .nil

  meta = .directory~new
  meta["purpose"] = "Authoritative pre-flattening generation plan for Structured Utterance"
  meta["package_version"] = .StructuredUtteranceProducerBuild~VERSION
  meta["api_version"] = .StructuredUtteranceProducerBuild~API_VERSION
  meta["standards"] = "structured.utterance/0.3; ALCHEMY-HOUSE-OBJECT-0.8"
  meta["design_limitations"] = "No provider invocation; no post-hoc intent reconstruction; no Brand/Legal/Security effect decision; no action authority"
  self~init:super(meta)

  self~registerStateVariable("planId", "INTERNAL", "stable opaque generation-plan identifier")
  self~registerStateVariable("utteranceId", "INTERNAL", "stable Structured Utterance identifier")
  self~registerStateVariable("providerInvocationRef", "INTERNAL", "opaque provider invocation evidence reference; never provider text")
  self~registerStateVariable("modelRef", "INTERNAL", "controlled model/release reference")
  self~registerStateVariable("sealed", "INTERNAL", "generation-plan immutability state")
  self~registerMethodContract("SEAL", "seal generation-time semantic evidence before rendering", .array~new, "STRUCTUREDUTTERANCEPRODUCERRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("POINTID", "return stable non-content plan evidence point", .array~new, "STRING", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE_PRODUCER.PLAN.SEAL.BEFORE", "before plan seal; non-content counts only", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE_PRODUCER.PLAN.SEAL.AFTER", "after plan seal; non-content counts only", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE_PRODUCER.PLAN.SEAL.FAIL", "plan seal rejected; code only", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~registerExternalRequirement("library", "structured_utterance", "0.3", .true)
  self~declareHouseCompliance(95)

  planId = .StructuredUtteranceProducerCanonical~controlledRef(planIdArg, "PLAN_ID")
  utteranceId = .StructuredUtteranceProducerCanonical~controlledRef(utteranceIdArg, "UTTERANCE_ID")
  actorKind = .StructuredUtteranceProducerCanonical~token(actorKindArg, "ACTOR_KIND")
  surface = .StructuredUtteranceProducerCanonical~token(surfaceArg, "SURFACE")
  inReplyTo = .StructuredUtteranceProducerCanonical~controlledRef(inReplyToArg, "IN_REPLY_TO", .true)
  producerKind = .StructuredUtteranceProducerCanonical~token(producerKindArg, "PRODUCER_KIND")
  producerId = .StructuredUtteranceProducerCanonical~controlledRef(producerIdArg, "PRODUCER_ID")
  providerInvocationRef = .StructuredUtteranceProducerCanonical~controlledRef(providerInvocationRefArg, "PROVIDER_INVOCATION_REF", .true)
  modelRef = .StructuredUtteranceProducerCanonical~controlledRef(modelRefArg, "MODEL_REF", .true)
  responsePlanRef = .StructuredUtteranceProducerCanonical~controlledRef(responsePlanRefArg, "RESPONSE_PLAN_REF", .true)
  if createdAtArg == .nil then createdAt = .DateTime~new; else createdAt = createdAtArg

  segments = .array~new
  acts = .array~new
  informationUses = .array~new
  generationIntents = .array~new
  speechActs = .array~new
  correlations = .array~new
  contextTags = .array~new
  brandContext = .BrandExperienceContext~new
  sealed = .false

::method pointId
  expose planId
  return "STRUCTURED_UTTERANCE_PRODUCER:PLAN:" || planId

::method addSegment
  expose segments sealed
  use arg segment
  if sealed then return .false
  if segment == .nil then return .false
  if \segment~isA(.StructuredUtteranceSegment) then return .false
  segments~append(segment)
  return .true

::method addAct
  expose acts sealed
  use arg act
  if sealed then return .false
  if act == .nil then return .false
  if \act~isA(.UtteranceCommunicativeAct) then return .false
  acts~append(act)
  return .true

::method addInformationUse
  expose informationUses sealed
  use arg edge
  if sealed then return .false
  if edge == .nil then return .false
  if \edge~isA(.UtteranceInformationUseEdge) then return .false
  informationUses~append(edge)
  return .true

::method addGenerationIntent
  expose generationIntents sealed
  use arg intent
  if sealed then return .false
  if intent == .nil then return .false
  if \intent~isA(.UtteranceGenerationIntent) then return .false
  generationIntents~append(intent)
  return .true

::method addSpeechAct
  expose speechActs sealed
  use arg value
  if sealed then return .false
  return .StructuredUtteranceProducerCanonical~appendUniqueToken(speechActs, value)

::method addCorrelation
  expose correlations sealed
  use arg value
  if sealed then return .false
  ref = .StructuredUtteranceProducerCanonical~controlledRef(value, "CORRELATION")
  do existing over correlations
    if existing = ref then return .true
  end
  correlations~append(ref)
  return .true

::method addContextTag
  expose contextTags sealed
  use arg value
  if sealed then return .false
  return .StructuredUtteranceProducerCanonical~appendUniqueToken(contextTags, value)

::method addBrandDomain
  expose brandContext sealed
  use arg value
  if sealed then return .false
  return brandContext~addDomain(value)

::method addBrandFunction
  expose brandContext sealed
  use arg value
  if sealed then return .false
  return brandContext~addFunction(value)

::method addBrandOpportunity
  expose brandContext sealed
  use arg value
  if sealed then return .false
  return brandContext~addOpportunity(value)

::method segments
  expose segments
  return .StructuredUtteranceProducerCanonical~copyArray(segments)
::method acts
  expose acts
  return .StructuredUtteranceProducerCanonical~copyArray(acts)
::method informationUses
  expose informationUses
  return .StructuredUtteranceProducerCanonical~copyArray(informationUses)
::method generationIntents
  expose generationIntents
  return .StructuredUtteranceProducerCanonical~copyArray(generationIntents)
::method speechActs
  expose speechActs
  return .StructuredUtteranceProducerCanonical~copyArray(speechActs)
::method correlations
  expose correlations
  return .StructuredUtteranceProducerCanonical~copyArray(correlations)
::method contextTags
  expose contextTags
  return .StructuredUtteranceProducerCanonical~copyArray(contextTags)
::method brandDomains
  expose brandContext
  return brandContext~domains
::method brandFunctions
  expose brandContext
  return brandContext~functions
::method brandOpportunities
  expose brandContext
  return brandContext~opportunities

::method seal
  expose sealed segments acts informationUses generationIntents planId
  if sealed then return .StructuredUtteranceProducerResult~success(self)
  ev = .directory~new
  ev["plan_id"] = planId
  ev["segments"] = segments~items
  ev["acts"] = acts~items
  ev["information_uses"] = informationUses~items
  ev["generation_intents"] = generationIntents~items
  self~alchemyInstrument("STRUCTURED_UTTERANCE_PRODUCER.PLAN.SEAL.BEFORE", ev)
  if segments~items = 0 then return self~sealFailure("PLAN_NO_SEGMENTS", ev)
  do segment over segments
    if \segment~sealed then do
      r = segment~seal
      if \r~ok then return self~sealFailure("PLAN_SEGMENT_INVALID:" || r~code, ev)
    end
  end
  do act over acts
    if \act~sealed then do
      r = act~seal
      if \r~ok then return self~sealFailure("PLAN_ACT_INVALID:" || r~code, ev)
    end
  end
  do edge over informationUses
    if \edge~sealed then do
      r = edge~seal
      if \r~ok then return self~sealFailure("PLAN_INFORMATION_USE_INVALID:" || r~code, ev)
    end
  end
  do intent over generationIntents
    if \intent~sealed then do
      r = intent~seal
      if \r~ok then return self~sealFailure("PLAN_INTENT_INVALID:" || r~code, ev)
    end
  end
  sealed = .true
  self~alchemyInstrument("STRUCTURED_UTTERANCE_PRODUCER.PLAN.SEAL.AFTER", ev)
  return .StructuredUtteranceProducerResult~success(self)

::method sealFailure private
  use arg codeArg, evidence
  fail = .directory~new
  fail["plan_id"] = self~planId
  fail["code"] = codeArg
  self~alchemyInstrument("STRUCTURED_UTTERANCE_PRODUCER.PLAN.SEAL.FAIL", fail)
  return .StructuredUtteranceProducerResult~failure(codeArg)

/* Deliberately no parser lives here.  Text-only data is evidence that the
 * structured generation boundary has already been crossed and lost. */
::method fromFlattenedReply class
  use arg ignoredText = "", ignoredProviderRef = ""
  return .StructuredUtteranceProducerResult~failure("FLATTENED_REPLY_INSUFFICIENT", "authoritative generation-time structure is required; post-hoc text cannot reconstruct intent or lineage")

::class StructuredUtteranceProductionRecord subclass AlchemyObject public
::attribute planPoint get
::attribute utterance get
::attribute utterancePoint get
::attribute deliveryText get
::attribute deidentifiedText get
::attribute sourceMode get
::attribute createdAt get

::method init
  expose planPoint utterance utterancePoint deliveryText deidentifiedText sourceMode createdAt
  use arg planArg, utteranceArg, deliveryTextArg, deidentifiedTextArg
  meta = .directory~new
  meta["purpose"] = "Bound result proving text was rendered from sealed pre-flattening structure"
  meta["package_version"] = .StructuredUtteranceProducerBuild~VERSION
  meta["api_version"] = .StructuredUtteranceProducerBuild~API_VERSION
  meta["design_limitations"] = "Record is evidence of structured production, not truth, legality, appropriateness, Brand effect, or execution authority"
  self~init:super(meta)
  self~registerStateVariable("planPoint", "CUSTOMER", "stable non-content generation-plan evidence point")
  self~registerStateVariable("utterancePoint", "CUSTOMER", "stable Structured Utterance point")
  self~registerStateVariable("deliveryText", "SECRET", "customer-visible rendered content may contain customer data")
  self~registerStateVariable("deidentifiedText", "CUSTOMER", "privacy-reduced analytic rendering")
  self~registerStateVariable("sourceMode", "CUSTOMER", "evidence that rendering source was authoritative structured plan")
  self~registerMethodContract("RESULTPAYLOAD", "project the production record into a typed domain result payload without inventing Structured Response envelope fields", .array~new, "STRUCTUREDUTTERANCEPRODUCTIONPAYLOAD", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~registerExternalRequirement("library", "structured_utterance", "0.3", .true)
  self~declareHouseCompliance(95)
  planPoint = planArg~pointId
  utterance = utteranceArg
  utterancePoint = utteranceArg~pointId
  deliveryText = deliveryTextArg~string
  deidentifiedText = deidentifiedTextArg~string
  sourceMode = "AUTHORITATIVE_STRUCTURED_PLAN"
  createdAt = .DateTime~new

::method pointId
  expose planPoint
  return "STRUCTURED_UTTERANCE_PRODUCER:RECORD:" || substr(planPoint, lastpos(":", planPoint) + 1)

::method resultPayload
  return .StructuredUtteranceProductionPayload~new(self)

/* Typed domain result for carriage by the platform Structured Response API.
 * This class deliberately does not define request/result/receipt/warning/error,
 * timing, transport, authority, or admission fields.  Those remain owned by the
 * external Structured Response contract. */
::class StructuredUtteranceProductionPayload subclass AlchemyObject public
::attribute schema get
::attribute recordPoint get
::attribute planPoint get
::attribute utterancePoint get
::attribute deliveryText get
::attribute deidentifiedText get
::attribute sourceMode get

::method init
  expose schema recordPoint planPoint utterancePoint deliveryText deidentifiedText sourceMode
  use arg recordArg
  if recordArg == .nil then raise syntax 88.980 array("Structured Utterance production record required")
  if \recordArg~isA(.StructuredUtteranceProductionRecord) then raise syntax 88.980 array("Structured Utterance production record required")
  meta = .directory~new
  meta["purpose"] = "Typed Structured Utterance production result payload for carriage by external Structured Response authority"
  meta["package_version"] = .StructuredUtteranceProducerBuild~VERSION
  meta["api_version"] = .StructuredUtteranceProducerBuild~API_VERSION
  meta["payload_schema"] = .StructuredUtteranceProducerBuild~PAYLOAD_SCHEMA
  meta["design_limitations"] = "Domain payload only; does not own Structured Response envelope, timing, receipt, warning/error, authority, admission or transport semantics"
  self~init:super(meta)
  self~registerStateVariable("schema", "CUSTOMER", "domain payload schema identifier")
  self~registerStateVariable("recordPoint", "CUSTOMER", "stable production-record evidence point")
  self~registerStateVariable("planPoint", "CUSTOMER", "stable generation-plan evidence point")
  self~registerStateVariable("utterancePoint", "CUSTOMER", "stable Structured Utterance evidence point")
  self~registerStateVariable("deliveryText", "SECRET", "customer-visible rendered content; may contain customer data")
  self~registerStateVariable("deidentifiedText", "CUSTOMER", "privacy-reduced analytic rendering")
  self~registerStateVariable("sourceMode", "CUSTOMER", "rendering source provenance")
  self~registerMethodContract("ASDIRECTORY", "return domain payload fields only, excluding common Structured Response envelope vocabulary", .array~new, "DIRECTORY", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~registerExternalRequirement("library", "structured_utterance", "0.3", .true)
  self~declareHouseCompliance(95)
  schema = .StructuredUtteranceProducerBuild~PAYLOAD_SCHEMA
  recordPoint = recordArg~pointId
  planPoint = recordArg~planPoint
  utterancePoint = recordArg~utterancePoint
  deliveryText = recordArg~deliveryText
  deidentifiedText = recordArg~deidentifiedText
  sourceMode = recordArg~sourceMode

::method pointId
  expose recordPoint
  return "STRUCTURED_UTTERANCE_PRODUCER:PAYLOAD:" || substr(recordPoint, lastpos(":", recordPoint) + 1)

::method asDirectory
  expose schema recordPoint planPoint utterancePoint deliveryText deidentifiedText sourceMode
  d = .directory~new
  d["schema"] = schema
  d["recordPoint"] = recordPoint
  d["planPoint"] = planPoint
  d["utterancePoint"] = utterancePoint
  d["deliveryText"] = deliveryText
  d["deidentifiedText"] = deidentifiedText
  d["sourceMode"] = sourceMode
  return d

::class StructuredUtteranceProducer subclass AlchemyObject public
::method init
  meta = .directory~new
  meta["purpose"] = "Provider-neutral Structured Utterance pre-flattening producer"
  meta["package_version"] = .StructuredUtteranceProducerBuild~VERSION
  meta["api_version"] = .StructuredUtteranceProducerBuild~API_VERSION
  meta["standards"] = "structured.utterance.producer/0.1; structured.utterance/0.3; ALCHEMY-HOUSE-OBJECT-0.8"
  meta["design_limitations"] = "No model invocation; no text-to-structure inference; no business effect or execution authority"
  self~init:super(meta)
  self~registerMethodContract("PRODUCE", "materialize and seal StructuredUtterance from a sealed generation plan, then render", .array~of("PLAN"), "STRUCTUREDUTTERANCEPRODUCERRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("PRODUCEPAYLOAD", "produce a typed domain result payload suitable for carriage by an external Structured Response implementation", .array~of("PLAN"), "STRUCTUREDUTTERANCEPRODUCERRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerMethodContract("REJECTFLATTENEDREPLY", "fail closed when only flattened provider text remains", .array~of("TEXT"), "STRUCTUREDUTTERANCEPRODUCERRESULT", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE_PRODUCER.PRODUCE.BEFORE", "structured production entered; ids/counts only", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE_PRODUCER.PRODUCE.AFTER", "structured production complete; ids/counts only", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE_PRODUCER.PRODUCE.FAIL", "structured production rejected; code only", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("STRUCTURED_UTTERANCE_PRODUCER.FLATTENED_REJECT", "flattened-only reconstruction rejected; content length only", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~registerExternalRequirement("library", "structured_utterance", "0.3", .true)
  self~declareHouseCompliance(95)

::method rejectFlattenedReply
  use arg textArg = "", providerRefArg = ""
  ev = .directory~new
  if textArg == .nil then ev["characters"] = 0; else ev["characters"] = textArg~string~length
  if providerRefArg == .nil then ev["provider_ref_present"] = .false
  else if providerRefArg~string = "" then ev["provider_ref_present"] = .false
  else ev["provider_ref_present"] = .true
  self~alchemyInstrument("STRUCTURED_UTTERANCE_PRODUCER.FLATTENED_REJECT", ev)
  return .StructuredUtteranceProducerResult~failure("FLATTENED_REPLY_INSUFFICIENT", "authoritative generation-time structure is required; markup inside provider text is not structural authority")

::method produce
  use arg plan
  if plan == .nil then return self~failure("GENERATION_PLAN_REQUIRED")
  if \plan~isA(.StructuredUtteranceGenerationPlan) then return self~failure("GENERATION_PLAN_REQUIRED")
  if \plan~sealed then return self~failure("GENERATION_PLAN_NOT_SEALED")
  before = .directory~new
  before["plan_id"] = plan~planId
  before["utterance_id"] = plan~utteranceId
  before["segments"] = plan~segments~items
  before["acts"] = plan~acts~items
  before["information_uses"] = plan~informationUses~items
  before["generation_intents"] = plan~generationIntents~items
  self~alchemyInstrument("STRUCTURED_UTTERANCE_PRODUCER.PRODUCE.BEFORE", before)

  ctx = .BrandExperienceContext~new
  do value over plan~brandDomains; ctx~addDomain(value); end
  do value over plan~brandFunctions; ctx~addFunction(value); end
  do value over plan~brandOpportunities; ctx~addOpportunity(value); end

  u = .StructuredUtterance~new(plan~utteranceId, plan~actorKind, plan~surface, plan~inReplyTo, ctx, plan~createdAt)
  do value over plan~speechActs; u~addSpeechAct(value); end
  do value over plan~correlations; u~addCorrelation(value); end
  do value over plan~contextTags; u~addContextTag(value); end
  do segment over plan~segments; u~addSegment(segment); end
  do act over plan~acts; u~addAct(act); end
  do edge over plan~informationUses; u~addInformationUse(edge); end
  do intent over plan~generationIntents; u~addGenerationIntent(intent); end

  sealedResult = u~seal
  if \sealedResult~ok then return self~failure("STRUCTURED_UTTERANCE_INVALID", sealedResult~code)
  delivery = .StructuredUtteranceRenderer~renderDelivery(u)
  if \delivery~ok then return self~failure("DELIVERY_RENDER_FAILED", delivery~code)
  safe = .StructuredUtteranceRenderer~renderDeidentified(u)
  if \safe~ok then return self~failure("DEIDENTIFIED_RENDER_FAILED", safe~code)

  record = .StructuredUtteranceProductionRecord~new(plan, u, delivery~value, safe~value)
  after = .directory~new
  after["plan_id"] = plan~planId
  after["utterance_id"] = u~utteranceId
  after["delivery_characters"] = delivery~value~length
  after["deidentified_characters"] = safe~value~length
  after["analysis_findings"] = u~analysisFindings~items
  self~alchemyInstrument("STRUCTURED_UTTERANCE_PRODUCER.PRODUCE.AFTER", after)
  return .StructuredUtteranceProducerResult~success(record)

::method producePayload
  use arg plan
  r = self~produce(plan)
  if \r~ok then return r
  return .StructuredUtteranceProducerResult~success(r~value~resultPayload)

::method failure private
  use arg codeArg, detailArg = ""
  ev = .directory~new
  ev["code"] = codeArg
  self~alchemyInstrument("STRUCTURED_UTTERANCE_PRODUCER.PRODUCE.FAIL", ev)
  return .StructuredUtteranceProducerResult~failure(codeArg, detailArg)

::requires 'StructuredUtterance.cls'
