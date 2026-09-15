/* WLUExternalPlan.cls - narrow provider-neutral pre-admission plan import. */
::options digits 30

::class WLUExternalPlanBuild public
::constant VERSION "0.1"
::constant API_VERSION "work.load.units.external-plan/0.1"

::class WLUImportedStagePlan public
::attribute stage get
::attribute ttlSeconds get
::attribute requestId get
::attribute rateCardId get
::attribute rateCardVersion get
::attribute factCount get
::attribute sourcePlanClass get
::method init
  expose stage ttlSeconds requestId rateCardId rateCardVersion factCount sourcePlanClass
  use strict arg stage, ttlSeconds, requestId, rateCardId, rateCardVersion, factCount, sourcePlanClass
::method scope
  expose stage
  return stage~scope
::method expectedMicroWlu
  expose stage
  return stage~expectedMicroWlu
::method ceilingMicroWlu
  expose stage
  return stage~ceilingMicroWlu
::method requestedRateMicroWluPerSecond
  expose stage
  return stage~demand~requestedRateMicroWluPerSecond

::class WLUExternalPlanImporter subclass AlchemyObject public
::attribute authority get
::method init
  expose authority
  use strict arg authorityArg
  if authorityArg == .nil then raise syntax 88.900 array("WLUExternalPlanImporter requires WLUAuthority")
  if \authorityArg~isA(.WLUAuthority) then raise syntax 88.900 array("WLUExternalPlanImporter requires WLUAuthority")
  authority = authorityArg
  alchemyConstruction = .WLUAlchemySupport~construction(authority~keyRing, "WLUExternalPlanImporter", "Provider-neutral pre-admission execution-plan import and WLU valuation boundary")
  self~init:super(alchemyConstruction[1], alchemyConstruction[2], alchemyConstruction[3])
  ignore = .WLUAlchemySupport~finishConstruction(self)
  self~recordRelationship("WLU_AUTHORITY", authority, "policy-owned valuation authority", "INTERNAL")
  self~registerStateVariable("authority", "INTERNAL", "WLU valuation authority identity; provider authority is never stored")
  self~registerMethodContract("IMPORTPLAN", "Import a narrow external execution plan into a WLUJobStage using WLU policy valuation", .array~of("IDENTITY", "STAGEID", "EXTERNALPLAN"), "WLURESULT", .true, "AUTO", "CUSTOMER", "SECURITY_BOUNDARY", "READ", "NONE")
  self~registerInstrumentationPoint("WLU.EXTERNAL_PLAN.IMPORT", "records bounded plan/fact/valuation metadata; never prompt, response, credential or transport content", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("contract", "external_plan", .WLUExternalPlanBuild~API_VERSION, .false)
  self~declareHouseCompliance(95)

::method importPlan public protected
  expose authority
  use strict arg identity, stageId, externalPlan
  identity = identity~string~strip
  stageId = stageId~string~strip
  if identity = "" then return .WLUResult~failure("WLU_EXTERNAL_PLAN_IDENTITY_REQUIRED", "identity must not be empty")
  if stageId = "" then return .WLUResult~failure("WLU_EXTERNAL_PLAN_STAGE_REQUIRED", "stage id must not be empty")
  surface = self~validatePlanSurface(externalPlan)
  if \surface~ok then return surface
  scope = externalPlan~scope~string~strip
  if scope = "" then return .WLUResult~failure("WLU_EXTERNAL_PLAN_SCOPE_REQUIRED", "external plan scope must not be empty")
  factResult = self~toWluFacts(externalPlan~plannedFacts)
  if \factResult~ok then return factResult
  facts = factResult~value
  if facts~items = 0 then return .WLUResult~failure("WLU_EXTERNAL_PLAN_FACTS_REQUIRED", "external plan must contain at least one metered fact")
  quoteResult = authority~quoteFacts(identity, scope, facts)
  if \quoteResult~ok then return quoteResult
  quote = quoteResult~value
  if quote~microWlu <= 0 then return .WLUResult~failure("WLU_EXTERNAL_PLAN_ZERO_WORK", "external plan values to zero WLU and cannot form an executable job stage")
  ceiling = externalPlan~ceilingMicroWlu
  if ceiling == .nil then ceiling = quote~microWlu
  if \datatype(ceiling, "W") then return .WLUResult~failure("WLU_EXTERNAL_PLAN_CEILING_INVALID", "external plan ceiling must be a whole micro-WLU value or .nil")
  if ceiling < quote~microWlu then return .WLUResult~failure("WLU_EXTERNAL_PLAN_CEILING_BELOW_QUOTE", "expected=" || quote~microWlu || " ceiling=" || ceiling)
  targetSeconds = externalPlan~targetSeconds
  if \datatype(targetSeconds, "W") then return .WLUResult~failure("WLU_EXTERNAL_PLAN_TARGET_INVALID", "target seconds must be a non-negative whole number")
  if targetSeconds < 0 then return .WLUResult~failure("WLU_EXTERNAL_PLAN_TARGET_INVALID", "target seconds must be a non-negative whole number")
  ttlSeconds = externalPlan~ttlSeconds
  if \datatype(ttlSeconds, "W") then return .WLUResult~failure("WLU_EXTERNAL_PLAN_TTL_INVALID", "TTL seconds must be a non-negative whole number")
  if ttlSeconds < 0 then return .WLUResult~failure("WLU_EXTERNAL_PLAN_TTL_INVALID", "TTL seconds must be a non-negative whole number")
  requestId = externalPlan~requestId~string~strip
  stage = .WLUJobStage~new(stageId, scope, quote~microWlu, ceiling, 0, 0, targetSeconds, .nil, quote~rateCardId, quote~rateCardVersion)
  planClass = externalPlan~class~id~string
  imported = .WLUImportedStagePlan~new(stage, ttlSeconds, requestId, quote~rateCardId, quote~rateCardVersion, facts~items, planClass)
  event = .directory~new
  event["stage_id"] = stageId
  event["scope"] = scope
  event["source_plan_class"] = planClass
  event["fact_count"] = facts~items
  event["expected_micro_wlu"] = quote~microWlu
  event["ceiling_micro_wlu"] = ceiling
  event["target_seconds"] = targetSeconds
  event["ttl_seconds"] = ttlSeconds
  event["rate_card_id"] = quote~rateCardId
  event["rate_card_version"] = quote~rateCardVersion
  self~alchemyInstrument("WLU.EXTERNAL_PLAN.IMPORT", event)
  return .WLUResult~success(imported)

::method validatePlanSurface private
  use strict arg externalPlan
  if externalPlan == .nil then return .WLUResult~failure("WLU_EXTERNAL_PLAN_REQUIRED", "external execution plan is required")
  required = .array~of("SCOPE", "PLANNEDFACTS", "CEILINGMICROWLU", "TARGETSECONDS", "TTLSECONDS", "REQUESTID")
  do name over required
    if \externalPlan~hasMethod(name) then return .WLUResult~failure("WLU_EXTERNAL_PLAN_CONTRACT_INVALID", "external plan is missing method " || name)
  end
  return .WLUResult~success(externalPlan)

::method toWluFacts private
  use strict arg externalFacts
  if externalFacts == .nil then return .WLUResult~failure("WLU_EXTERNAL_PLAN_FACTS_REQUIRED", "planned facts are required")
  if \externalFacts~hasMethod("SUPPLIER") then return .WLUResult~failure("WLU_EXTERNAL_PLAN_FACTS_INVALID", "planned facts must be a collection")
  output = .array~new
  supplier = externalFacts~supplier
  do while supplier~available
    fact = supplier~item
    if fact == .nil then return .WLUResult~failure("WLU_EXTERNAL_PLAN_FACT_INVALID", "planned fact is .nil")
    if \fact~hasMethod("FACTTYPE") then return .WLUResult~failure("WLU_EXTERNAL_PLAN_FACT_INVALID", "planned fact lacks FACTTYPE")
    if \fact~hasMethod("QUANTITY") then return .WLUResult~failure("WLU_EXTERNAL_PLAN_FACT_INVALID", "planned fact lacks QUANTITY")
    source = ""
    if fact~hasMethod("SOURCE") then source = fact~source
    dimensions = .nil
    if fact~hasMethod("DIMENSIONS") then dimensions = fact~dimensions
    output~append(.WLUFact~new(fact~factType, fact~quantity, source, dimensions))
    supplier~next
  end
  return .WLUResult~success(output)

::requires "WLUJobBudget.cls"
