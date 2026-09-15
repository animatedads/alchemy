/* ooRexx AI Model Router v0.1
 *
 * Provider-neutral, non-entitling cross-provider route selection over
 * authenticated WLU route evidence and institutional route-decision policy.
 *
 * This package intentionally contains no provider transport, credentials,
 * Secret Broker authority, Runtime Registry session, or WLU admission object.
 */

::class AIModelRouterBuild public
::constant PRODUCT "ooRexx AI Model Router"
::constant RELEASE "0.1"
::constant API_VERSION "ai.model.router/0.1"
::constant ALCHEMY_OBJECTS_VERSION "0.8"
::constant WLU_VERSION "0.12"
::constant INSTITUTIONAL_POLICY_VERSION "0.6"

/* Plain deployment declaration.  Coordinates identify the later Runtime
 * Registry target but confer no lease/session/invocation authority. */
::class AIModelRouteCandidate public
::attribute routeId get
::attribute providerId get
::attribute modelId get
::attribute channelId get
::attribute zone get
::attribute batchCapable get
::attribute scope get
::attribute expectedMicroWlu get
::attribute ceilingMicroWlu get
::attribute environment get
::attribute clientId get
::attribute abilityId get

::method init
  expose routeId providerId modelId channelId zone batchCapable scope expectedMicroWlu ceilingMicroWlu environment clientId abilityId tags
  use strict arg routeIdArg, providerIdArg, modelIdArg, channelIdArg, zoneArg, batchCapableArg, scopeArg, expectedArg, ceilingArg, environmentArg, clientIdArg, abilityIdArg = "model.complete", tagsArg = .nil
  routeId = routeIdArg~string~strip~translate
  providerId = providerIdArg~string~strip~translate
  modelId = modelIdArg~string~strip
  channelId = channelIdArg~string~strip
  zone = zoneArg~string~strip~translate
  batchCapable = batchCapableArg == .true
  scope = scopeArg~string~strip
  environment = environmentArg~string~strip~lower
  clientId = clientIdArg~string~strip~lower
  abilityId = abilityIdArg~string~strip~lower
  if routeId = "" then raise syntax 88.900 array("AI model route id required")
  if providerId = "" then raise syntax 88.900 array("AI model provider id required")
  if modelId = "" then raise syntax 88.900 array("AI model id required")
  if channelId = "" then raise syntax 88.900 array("AI model channel id required")
  if zone = "" then zone = "ANY"
  if scope = "" then raise syntax 88.900 array("AI model WLU scope required")
  if environment = "" | clientId = "" | abilityId = "" then raise syntax 88.900 array("AI model Runtime Registry deployment coordinates required")
  if \datatype(expectedArg, "W") | expectedArg <= 0 then raise syntax 88.900 array("AI model expected micro-WLU must be positive whole")
  if \datatype(ceilingArg, "W") | ceilingArg < expectedArg then raise syntax 88.900 array("AI model ceiling micro-WLU must be whole and >= expected")
  expectedMicroWlu = expectedArg
  ceilingMicroWlu = ceilingArg
  tags = self~normalizeTags(tagsArg)

::method tags
  expose tags
  copied = .array~new
  do value over tags
    copied~append(value)
  end
  return copied

::method hasTag
  expose tags
  use strict arg tagArg
  wanted = tagArg~string~strip~translate
  do value over tags
    if value = wanted then return .true
  end
  return .false

::method satisfiesZone
  expose zone
  use strict arg requiredArg
  required = requiredArg~string~strip~translate
  if required = "" | required = "ANY" then return .true
  if zone = "ANY" then return .true
  return zone = required

::method normalizeTags private
  use arg source
  normalized = .array~new
  if source == .nil then return normalized
  if \source~isa(.Collection) then raise syntax 88.900 array("AI model route tags must be collection")
  seen = .directory~new
  do item over source
    value = item~string~strip~translate
    if value = "" then iterate
    if seen~at(value) == .nil then do
      seen[value] = .true
      normalized~append(value)
    end
  end
  return normalized


::class AIModelRouteRequest public
::attribute requiredZone get
::attribute batchAllowed get

::method init
  expose requiredZone batchAllowed requiredTags allowedProviders
  use arg requiredTagsArg = .nil, requiredZoneArg = "ANY", batchAllowedArg = .true, allowedProvidersArg = .nil
  requiredZone = requiredZoneArg~string~strip~translate
  if requiredZone = "" then requiredZone = "ANY"
  batchAllowed = batchAllowedArg == .true
  requiredTags = self~normalize(requiredTagsArg, "required tags")
  allowedProviders = self~normalize(allowedProvidersArg, "allowed providers")

::method requiredTags
  expose requiredTags
  return self~copyArray(requiredTags)

::method allowedProviders
  expose allowedProviders
  return self~copyArray(allowedProviders)

::method allowsProvider
  expose allowedProviders
  use strict arg providerIdArg
  if allowedProviders~items = 0 then return .true
  wanted = providerIdArg~string~strip~translate
  do value over allowedProviders
    if value = wanted then return .true
  end
  return .false

::method accepts
  expose requiredTags batchAllowed
  use strict arg candidate
  if candidate == .nil | \candidate~isa(.AIModelRouteCandidate) then return .false
  if \self~allowsProvider(candidate~providerId) then return .false
  if \candidate~satisfiesZone(self~requiredZone) then return .false
  if \batchAllowed & candidate~batchCapable then return .false
  do tag over requiredTags
    if \candidate~hasTag(tag) then return .false
  end
  return .true

::method normalize private
  use arg source, label
  normalized = .array~new
  if source == .nil then return normalized
  if \source~isa(.Collection) then raise syntax 88.900 array("AI model route " || label || " must be collection")
  seen = .directory~new
  do item over source
    value = item~string~strip~translate
    if value = "" then iterate
    if seen~at(value) == .nil then do
      seen[value] = .true
      normalized~append(value)
    end
  end
  return normalized

::method copyArray private
  use strict arg source
  copied = .array~new
  do item over source
    copied~append(item)
  end
  return copied


::class AIModelRouteCatalog public
::method init
  expose candidates
  candidates = .directory~new

::method register
  expose candidates
  use strict arg candidate
  if candidate == .nil | \candidate~isa(.AIModelRouteCandidate) then raise syntax 88.900 array("AI model route catalog requires AIModelRouteCandidate")
  id = candidate~routeId
  if candidates~at(id) \== .nil then return .AIModelRouteOutcome~failure("AI_MODEL_ROUTE_DUPLICATE", id)
  candidates[id] = candidate
  return .AIModelRouteOutcome~success(candidate)

::method route
  expose candidates
  use strict arg routeIdArg
  return candidates~at(routeIdArg~string~strip~translate)

::method eligible
  expose candidates
  use strict arg request
  if request == .nil | \request~isa(.AIModelRouteRequest) then raise syntax 88.900 array("AI model route request required")
  matchedRoutes = .array~new
  ids = candidates~allIndexes
  ids~sort
  do id over ids
    candidate = candidates[id]
    if request~accepts(candidate) then matchedRoutes~append(candidate)
  end
  return matchedRoutes

::method count
  expose candidates
  return candidates~items


/* Detached non-authoritative selection result.  The deployment coordinates are
 * identifiers only; consumers must still acquire Runtime Registry authority
 * and pass ordinary WLU admission before any provider execution. */
::class AIModelRoutePlan public
::attribute routeId get
::attribute providerId get
::attribute modelId get
::attribute channelId get
::attribute environment get
::attribute clientId get
::attribute abilityId get
::attribute scope get
::attribute expectedMicroWlu get
::attribute ceilingMicroWlu get
::attribute advisory get
::attribute decision get

::method init
  expose routeId providerId modelId channelId environment clientId abilityId scope expectedMicroWlu ceilingMicroWlu advisory decision
  use strict arg candidate, advisoryArg, decisionArg
  if candidate == .nil | \candidate~isa(.AIModelRouteCandidate) then raise syntax 88.900 array("AI model route plan candidate required")
  if advisoryArg == .nil | \advisoryArg~isa(.WLURouteAdvisoryResult) then raise syntax 88.900 array("AI model route plan advisory required")
  if decisionArg == .nil | \decisionArg~isa(.WLURouteDecisionEvidence) then raise syntax 88.900 array("AI model route plan decision required")
  routeId = candidate~routeId
  providerId = candidate~providerId
  modelId = candidate~modelId
  channelId = candidate~channelId
  environment = candidate~environment
  clientId = candidate~clientId
  abilityId = candidate~abilityId
  scope = candidate~scope
  expectedMicroWlu = candidate~expectedMicroWlu
  ceilingMicroWlu = candidate~ceilingMicroWlu
  advisory = advisoryArg
  decision = decisionArg

::method admitted
  return .false

::method executableAuthority
  return .false


::class AIModelRouteOutcome public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::attribute advisory get
::attribute decision get

::method init
  expose ok code detail value advisory decision
  use arg okArg, codeArg = "OK", detailArg = "", valueArg = .nil, advisoryArg = .nil, decisionArg = .nil
  ok = okArg == .true
  code = codeArg~string~strip
  detail = detailArg~string
  value = valueArg
  advisory = advisoryArg
  decision = decisionArg

::method success class
  use arg value = .nil, advisory = .nil, decision = .nil
  return self~new(.true, "OK", "", value, advisory, decision)

::method failure class
  use arg code, detail = "", value = .nil, advisory = .nil, decision = .nil
  return self~new(.false, code, detail, value, advisory, decision)


::class AIModelRouter subclass AlchemyObject public

::method init
  expose keyRing advisor decisionGate routeCount
  use strict arg keyRingArg
  if keyRingArg == .nil | \keyRingArg~isa(.WLUFastMacKeyRing) then raise syntax 88.900 array("AI model router requires WLUFastMacKeyRing")
  keyRing = keyRingArg
  advisor = .WLUJobRouteAdvisor~new(keyRing)
  decisionGate = .WLUJobRouteDecisionGate~new(keyRing)
  routeCount = 0

  meta = .directory~new
  meta["purpose"] = "Non-authoritative cross-provider AI route selection over authenticated WLU evidence and institutional policy"
  meta["package_version"] = .AIModelRouterBuild~RELEASE
  meta["api_version"] = .AIModelRouterBuild~API_VERSION
  meta["authorship"] = .array~of("Alchemy ooRexx project")
  meta["standards"] = .array~of("ALCHEMY-HOUSE-OBJECT-0.8", "work.load.units/0.12", "institutional.policy/0.6", "ai.model.router/0.1")
  meta["design_limitations"] = .array~of("Returns policy-governed route evidence only; performs no Runtime Registry acquisition, WLU admission, provider invocation, credential lookup or transport")
  self~init:super(meta)
  self~registerStateVariable("keyRing", "SECRET", "WLU route-evidence verification/signing authority retained by advisory and decision gate")
  self~registerStateVariable("advisor", "INTERNAL", "non-entitling WLU route advisor")
  self~registerStateVariable("decisionGate", "INTERNAL", "non-entitling institutional route decision gate")
  self~registerStateVariable("routeCount", "INTERNAL", "aggregate route evaluations")
  self~registerMethodContract("ROUTE", "select a declared model route using authenticated WLU evidence and operative institutional route policy", .array~of("CATALOG", "REQUEST", "SOURCE", "ADVISORYPOLICY", "POLICYCATALOG", "POLICYID", "ACTIONTIME", "ACTORMODE"), "AIMODELROUTEOUTCOME", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerInstrumentationPoint("AI.MODEL.ROUTE", "records candidate count, selected route identity and policy result without prompts, credentials, provider payloads or execution authority", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .AIModelRouterBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_work_load_units", "v" || .AIModelRouterBuild~WLU_VERSION, .true)
  self~registerExternalRequirement("library", "institutional_policy", "v" || .AIModelRouterBuild~INSTITUTIONAL_POLICY_VERSION, .true)
  self~declareHouseCompliance(95)

::method route public
  expose advisor decisionGate routeCount
  use strict arg catalog, request, source, advisoryPolicy, policyCatalog, policyId, actionTime = .nil, actorMode = "AUTOMATED"
  routeCount = routeCount + 1
  if catalog == .nil | \catalog~isa(.AIModelRouteCatalog) then return self~finish("AI_MODEL_ROUTE_CATALOG_REQUIRED", "route catalog required", 0)
  if request == .nil | \request~isa(.AIModelRouteRequest) then return self~finish("AI_MODEL_ROUTE_REQUEST_REQUIRED", "route request required", 0)
  candidates = catalog~eligible(request)
  if candidates~items = 0 then return self~finish("AI_MODEL_ROUTE_NO_CANDIDATES", "no declared route satisfies request constraints", 0)

  stages = .array~new
  do candidate over candidates
    stages~append(.WLUJobStage~new(candidate~routeId, candidate~scope, candidate~expectedMicroWlu, candidate~ceilingMicroWlu))
  end
  advised = advisor~advise(source, stages, advisoryPolicy)
  if \advised~ok then return self~finish("AI_MODEL_ROUTE_ADVISORY_FAILED", advised~code || ": " || advised~detail, candidates~items)
  advisory = advised~value
  if \advisory~hasRecommendation then return self~finish("AI_MODEL_ROUTE_NO_EVIDENCE_ELIGIBLE", advisory~status, candidates~items, "", advisory)

  selected = catalog~route(advisory~recommendedStageId)
  if selected == .nil then return self~finish("AI_MODEL_ROUTE_CATALOG_DRIFT", advisory~recommendedStageId, candidates~items, advisory~recommendedStageId, advisory)

  decided = decisionGate~decide(policyCatalog, policyId, advisory, selected~routeId, actionTime, actorMode)
  if \decided~ok then return self~finish("AI_MODEL_ROUTE_POLICY_EVALUATION_FAILED", decided~code || ": " || decided~detail, candidates~items, selected~routeId, advisory)
  decision = decided~value
  if \decision~verify(decisionGate~keyRing) then return self~finish("AI_MODEL_ROUTE_DECISION_PROOF_INVALID", "route decision proof did not verify", candidates~items, selected~routeId, advisory, decision)
  if \decision~allowed then return self~finish("AI_MODEL_ROUTE_POLICY_DENIED", decision~reasonCode, candidates~items, selected~routeId, advisory, decision)

  plan = .AIModelRoutePlan~new(selected, advisory, decision)
  meta = self~routeMeta("PERMITTED", candidates~items, selected~routeId, decision~policyId, decision~policyVersion, decision~reasonCode)
  self~alchemyInstrument("AI.MODEL.ROUTE", meta)
  return .AIModelRouteOutcome~success(plan, advisory, decision)

::method finish private
  use arg code, detail, candidateCount = 0, routeId = "", advisory = .nil, decision = .nil
  policyId = ""
  policyVersion = ""
  reason = code
  if decision \== .nil then do
    policyId = decision~policyId
    policyVersion = decision~policyVersion
    reason = decision~reasonCode
  end
  meta = self~routeMeta("DENIED", candidateCount, routeId, policyId, policyVersion, reason)
  self~alchemyInstrument("AI.MODEL.ROUTE", meta)
  return .AIModelRouteOutcome~failure(code, detail, .nil, advisory, decision)

::method routeMeta private
  use strict arg state, candidateCount, routeId, policyId, policyVersion, reason
  meta = .directory~new
  meta["state"] = state
  meta["candidate_count"] = candidateCount
  meta["selected_route_id"] = routeId
  meta["policy_id"] = policyId
  meta["policy_version"] = policyVersion
  meta["reason_code"] = reason
  return meta

::requires "AlchemyObject.cls"
::requires "WLURouteDecisionPolicy.cls"
