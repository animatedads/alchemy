/* ooRexx AI Tool Broker v0.4
 *
 * Privileged outer authority boundary between model-proposed tool calls and
 * Runtime Registry Ability execution. Providers/models never receive this
 * object, AbilityRegistry, AbilitySession, AbilityHttpRouter or WLU authority.
 */

::class AIToolBrokerBuild public
::constant PRODUCT "ooRexx AI Tool Broker"
::constant RELEASE "0.4"
::constant API_VERSION "ai.tool.broker/0.4"
::constant RUNTIME_REGISTRY_VERSION "0.13"
::constant ABILITY_HTTP_VERSION "0.7"
::constant ALCHEMY_OBJECTS_VERSION "0.7"
::constant AI_ACCESS_VERSION "0.5"

::class AIToolDefinition public
::attribute toolName get
::attribute abilityId get
::attribute description get

::method init
  expose toolName abilityId description
  use arg toolNameArg, abilityIdArg, descriptionArg = ""
  toolName = toolNameArg~string~strip~lower
  abilityId = abilityIdArg~string~strip~lower
  description = descriptionArg~string
  if toolName = "" then raise syntax 88.900 array("AI tool name must not be empty")
  if abilityId = "" then raise syntax 88.900 array("AI tool Ability id must not be empty")
  allowed = "abcdefghijklmnopqrstuvwxyz0123456789._-"
  if verify(toolName, allowed) \= 0 then raise syntax 88.900 array("AI tool name contains unsupported character")
  if verify(abilityId, allowed) \= 0 then raise syntax 88.900 array("AI tool Ability id contains unsupported character")
  if abilityId = "query" then raise syntax 88.900 array("AI tool cannot inline materialized query Ability")
  if abilityId = "evaluate" then raise syntax 88.900 array("AI tool cannot inline materialized evaluation Ability")

::method publicDescription
  expose toolName description
  d = .directory~new
  d["name"] = toolName
  d["description"] = description
  return d


/* Generation-stamped, non-authority offer.  The provider receives only the
 * toolDefinitions array; generationId remains with the trusted orchestrator. */
::class AIToolOffer public
::attribute generationId get

::method init
  expose generationId toolDefinitions offeredNames
  use arg generationArg, definitionsArg = .nil
  generationId = generationArg~string~strip
  if generationId = "" then raise syntax 88.900 array("AI tool offer generation id must not be empty")
  if definitionsArg == .nil then definitionsArg = .array~new
  if \definitionsArg~isa(.Array) then raise syntax 88.900 array("AI tool offer definitions must be Array")
  toolDefinitions = .array~new
  offeredNames = .directory~new
  do definition over definitionsArg
    if \definition~isa(.AIProviderToolDefinition) then raise syntax 88.900 array("AI tool offer requires AIProviderToolDefinition values")
    if offeredNames~hasIndex(definition~name) then raise syntax 88.900 array("duplicate AI tool offer name: " || definition~name)
    offeredNames[definition~name] = .true
    toolDefinitions~append(definition)
  end

::method toolDefinitions
  expose toolDefinitions
  copied = .array~new
  do definition over toolDefinitions
    copied~append(definition)
  end
  return copied

::method containsTool
  expose offeredNames
  use arg toolNameArg
  return offeredNames[toolNameArg~string~strip~lower] == .true

::method count
  expose toolDefinitions
  return toolDefinitions~items


::class AIToolProposal public
::attribute callId get
::attribute toolName get

::method init
  expose callId toolName arguments
  use arg callIdArg, toolNameArg, argumentsArg
  callId = callIdArg~string~strip
  toolName = toolNameArg~string~strip~lower
  if callId = "" then raise syntax 88.900 array("AI tool proposal call id must not be empty")
  if toolName = "" then raise syntax 88.900 array("AI tool proposal tool name must not be empty")
  if argumentsArg == .nil then argumentsArg = .directory~new
  if \argumentsArg~isa(.Directory) then raise syntax 88.900 array("AI tool proposal arguments must be Directory")
  arguments = self~copyJsonObject(argumentsArg)

::method fromProviderCall class
  use arg providerCall
  if providerCall == .nil then raise syntax 88.900 array("AI tool proposal requires provider tool call")
  if \providerCall~isa(.AIProviderToolCall) then raise syntax 88.900 array("AI tool proposal requires AIProviderToolCall")
  return self~new(providerCall~callId, providerCall~name, providerCall~arguments)

::method arguments
  expose arguments
  return self~copyJsonObject(arguments)

::method copyJsonObject private
  use arg source
  wireText = .JSON~toJSON(source)
  copied = .JSON~fromJSON(wireText)
  if \copied~isa(.Directory) then raise syntax 88.900 array("AI tool proposal arguments must project as JSON object")
  return copied


::class AIToolCatalog subclass AlchemyObject public

::method init
  expose definitions
  use arg definitionsArg
  definitions = .directory~new
  if definitionsArg == .nil then definitionsArg = .array~new
  do definition over definitionsArg
    if \definition~isa(.AIToolDefinition) then raise syntax 88.900 array("AI tool catalog accepts AIToolDefinition")
    if definitions~hasIndex(definition~toolName) then raise syntax 88.900 array("Duplicate AI tool name: " || definition~toolName)
    definitions[definition~toolName] = definition
  end
  meta = .directory~new
  meta["purpose"] = "Explicit allowlist of model-visible tool names mapped privately to Runtime Registry dynamic Abilities"
  meta["package_version"] = .AIToolBrokerBuild~RELEASE
  meta["api_version"] = .AIToolBrokerBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerStateVariable("definitions", "INTERNAL", "explicit non-secret tool allowlist with private Ability mapping")
  self~registerMethodContract("RESOLVE", "resolve model-visible tool name through explicit allowlist", .array~of("TOOLNAME"), "ANY", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerMethodContract("DESCRIPTIONS", "return safe model-visible tool descriptions without internal Ability ids", .array~new, "ARRAY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("ALLDEFINITIONS", "return trusted broker definitions including private Ability mappings", .array~new, "ARRAY", .false, "AUTO", "SECRET", "SENSITIVE", "READ", "NONE")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .AIToolBrokerBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_ai_access", "v" || .AIToolBrokerBuild~AI_ACCESS_VERSION, .true)
  self~declareHouseCompliance(95)

::method resolve public
  expose definitions
  use arg toolNameArg
  return definitions[toolNameArg~string~strip~lower]

::method descriptions public
  expose definitions
  output = .array~new
  names = definitions~allIndexes
  names~sort
  do name over names
    output~append(definitions[name]~publicDescription)
  end
  return output

::method allDefinitions public
  expose definitions
  output = .array~new
  names = definitions~allIndexes
  names~sort
  do name over names
    output~append(definitions[name])
  end
  return output


::class AIToolDispatchResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute httpStatus get
::attribute generationId get
::attribute retryAfterSeconds get

::method init
  expose ok code detail httpStatus generationId retryAfterSeconds businessValue executionMetadata
  use arg okArg, codeArg, detailArg, statusArg, generationArg = "", businessArg = .nil, executionArg = .nil, retryArg = .nil
  ok = okArg == .true
  code = codeArg~string
  detail = detailArg~string
  httpStatus = statusArg
  generationId = generationArg~string
  businessValue = businessArg
  executionMetadata = executionArg
  retryAfterSeconds = retryArg

::method success class
  use arg statusArg, generationArg, businessArg, executionArg = .nil
  return self~new(.true, "OK", "", statusArg, generationArg, businessArg, executionArg)

::method failure class
  use arg codeArg, detailArg = "", statusArg = 0, generationArg = "", executionArg = .nil, retryArg = .nil
  return self~new(.false, codeArg, detailArg, statusArg, generationArg, .nil, executionArg, retryArg)

::method value
  expose businessValue
  return businessValue

::method execution
  expose executionMetadata
  return executionMetadata


/* One-shot authority-bearing ticket. It owns exactly one held AbilitySession
 * and therefore exactly one immutable Ability generation lease. */
::class AIToolTicket subclass AlchemyObject public
::attribute callId get
::attribute toolName get
::attribute abilityId get
::attribute generationId get
::attribute state get

::method init
  expose callId toolName abilityId generationId state arguments heldSession
  use arg proposal, definition, session
  if \proposal~isa(.AIToolProposal) then raise syntax 88.900 array("AI tool ticket requires proposal")
  if \definition~isa(.AIToolDefinition) then raise syntax 88.900 array("AI tool ticket requires definition")
  if session == .nil then raise syntax 88.900 array("AI tool ticket requires held AbilitySession")
  callId = proposal~callId
  toolName = definition~toolName
  abilityId = definition~abilityId
  generationId = session~generationId
  arguments = proposal~arguments
  heldSession = session
  state = "READY"
  meta = .directory~new
  meta["purpose"] = "One-shot generation-pinned authority ticket for one approved AI tool proposal"
  meta["package_version"] = .AIToolBrokerBuild~RELEASE
  meta["api_version"] = .AIToolBrokerBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerStateVariable("heldSession", "SECRET", "held AbilitySession authority and exact generation lease")
  self~registerStateVariable("arguments", "SECRET", "validated detached tool arguments; contents never instrumented")
  self~registerStateVariable("state", "INTERNAL", "one-shot ticket state")
  self~registerMethodContract("DISPATCH", "consume ticket through canonical pinned Ability router and release held session", .array~of("ROUTER"), "ANY", .false, "FALSE", "SECRET", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("CANCEL", "release an unexecuted or release-failed held Ability session", .array~new, "BOOLEAN", .false, "FALSE", "SECRET", "SENSITIVE", "MUTATE", "USE")
  self~registerExternalRequirement("library", "runtime_registry", "v" || .AIToolBrokerBuild~RUNTIME_REGISTRY_VERSION, .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .AIToolBrokerBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method dispatch public
  expose abilityId generationId state arguments heldSession
  use arg router
  if state \= "READY" then return .AIToolDispatchResult~failure("AI_TOOL_TICKET_CONSUMED", "tool ticket is not ready", 409, generationId)
  if router == .nil then return .AIToolDispatchResult~failure("AI_TOOL_ROUTER_MISSING", "pinned Ability router missing", 500, generationId)
  if \router~hasMethod("ROUTEPINNEDABILITY") then return .AIToolDispatchResult~failure("AI_TOOL_ROUTER_INCOMPATIBLE", "Runtime Registry v0.13 pinned route required", 500, generationId)
  state = "DISPATCHING"
  headers = .directory~new
  headers["content-type"] = "application/json"
  bodyText = .JSON~toJSON(arguments)
  headers["content-length"] = bodyText~length
  request = .AbilityHttpRequest~new("POST", "/v1/abilities/" || abilityId, "HTTP/1.1", headers, bodyText)

  signal on syntax name dispatchRaised
  response = router~routePinnedAbility(heldSession, abilityId, request)
  signal off syntax
  releaseOutcome = heldSession~release
  if \releaseOutcome~ok then do
    state = "RELEASE_FAILED"
    return .AIToolDispatchResult~failure("AI_TOOL_SESSION_RELEASE_FAILED", "pinned Ability session release failed", 500, generationId)
  end
  heldSession = .nil
  state = "CONSUMED"
  return self~decodeResponse(response)

dispatchRaised:
  signal off syntax
  state = "FAILED"
  if heldSession \== .nil then do
    releaseOutcome = heldSession~release
    if releaseOutcome~ok then heldSession = .nil
    else state = "RELEASE_FAILED"
  end
  return .AIToolDispatchResult~failure("AI_TOOL_DISPATCH_EXCEPTION", "pinned Ability dispatch raised a condition", 500, generationId)

::method cancel public
  expose state heldSession
  canRelease = state = "READY"
  if \canRelease then canRelease = state = "RELEASE_FAILED"
  if \canRelease then return .false
  if heldSession == .nil then do
    state = "CANCELLED"
    return .true
  end
  releaseOutcome = heldSession~release
  if \releaseOutcome~ok then do
    state = "RELEASE_FAILED"
    return .false
  end
  heldSession = .nil
  state = "CANCELLED"
  return .true

::method decodeResponse private
  expose generationId
  use arg response
  status = response~status
  signal on syntax name invalidResponse
  object = .JSON~fromJSON(response~body)
  signal off syntax
  if \object~isa(.Directory) then return .AIToolDispatchResult~failure("AI_TOOL_RESPONSE_INVALID", "Ability response must be JSON object", status, generationId)
  execution = object~at("execution")
  if status >= 200 then do
    if status < 300 then do
      resultValue = object~at("result")
      returnedGeneration = object~at("ability_generation")
      if returnedGeneration == .nil then returnedGeneration = generationId
      return .AIToolDispatchResult~success(status, returnedGeneration, resultValue, execution)
    end
  end
  detail = object~at("detail")
  if detail == .nil then detail = object~at("title")
  if detail == .nil then detail = "Ability tool dispatch rejected"
  wluCode = object~at("wlu_code")
  retryAfter = object~at("retry_after_seconds")
  if wluCode \== .nil then return .AIToolDispatchResult~failure("AI_TOOL_WLU_DENIED", detail~string, status, generationId, execution, retryAfter)
  return .AIToolDispatchResult~failure("AI_TOOL_ABILITY_REJECTED", detail~string, status, generationId, execution)

invalidResponse:
  signal off syntax
  return .AIToolDispatchResult~failure("AI_TOOL_RESPONSE_INVALID", "Ability response JSON invalid", status, generationId)


::class AIToolBroker subclass AlchemyObject public

::method init
  expose abilityRegistry router environment clientId catalog offerCount preparationCount executionCount
  use arg registryArg, routerArg, environmentArg, clientIdArg, catalogArg
  if registryArg == .nil then raise syntax 88.900 array("AI tool broker requires AbilityRegistry")
  if routerArg == .nil then raise syntax 88.900 array("AI tool broker requires AbilityHttpRouter")
  if catalogArg == .nil then raise syntax 88.900 array("AI tool broker requires explicit tool catalog")
  if \catalogArg~isa(.AIToolCatalog) then raise syntax 88.900 array("AI tool broker catalog type invalid")
  abilityRegistry = registryArg
  router = routerArg
  environment = environmentArg~string~strip~lower
  clientId = clientIdArg~string~strip~lower
  catalog = catalogArg
  offerCount = 0
  preparationCount = 0
  executionCount = 0
  if environment = "" then raise syntax 88.900 array("AI tool broker environment required")
  if clientId = "" then raise syntax 88.900 array("AI tool broker client id required")
  meta = .directory~new
  meta["purpose"] = "Privileged outer broker turning model tool proposals into generation-pinned canonical Ability invocations"
  meta["package_version"] = .AIToolBrokerBuild~RELEASE
  meta["api_version"] = .AIToolBrokerBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerStateVariable("abilityRegistry", "SECRET", "Ability Registry acquisition authority")
  self~registerStateVariable("router", "SECRET", "canonical pinned Ability dispatch authority")
  self~registerStateVariable("catalog", "INTERNAL", "explicit model-visible tool allowlist")
  self~registerStateVariable("offerCount", "INTERNAL", "aggregate generation-stamped tool offer count")
  self~registerStateVariable("preparationCount", "INTERNAL", "aggregate prepared proposal count")
  self~registerStateVariable("executionCount", "INTERNAL", "aggregate dispatch attempt count")
  self~registerMethodContract("OFFER", "derive model-safe tool definitions from the exact active Ability generation without retaining its lease", .array~new, "ANY", .false, "FALSE", "SECRET", "SENSITIVE", "READ", "USE")
  self~registerMethodContract("PREPARE", "validate allowlist/schema and hold exact Ability generation for one proposal", .array~of("PROPOSAL"), "ANY", .false, "FALSE", "SECRET", "SENSITIVE", "READ", "USE")
  self~registerMethodContract("PREPAREOFFERED", "validate a provider tool call against its generation-stamped offer and hold the same active Ability generation", .array~of("OFFER", "PROVIDERCALL"), "ANY", .false, "FALSE", "SECRET", "SENSITIVE", "READ", "USE")
  self~registerMethodContract("EXECUTE", "consume one prepared ticket through canonical pinned Ability router", .array~of("TICKET"), "ANY", .false, "FALSE", "SECRET", "SENSITIVE", "EXTERNAL", "USE")
  self~registerInstrumentationPoint("AI.TOOL.OFFER", "records generation, definition count and status without schemas or private Ability mappings", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.TOOL.PREPARE", "records tool/call identity, generation and status without argument contents", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.TOOL.EXECUTE", "records tool/call identity, generation, HTTP status and WLU-presence flag", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "runtime_registry", "v" || .AIToolBrokerBuild~RUNTIME_REGISTRY_VERSION, .true)
  self~registerExternalRequirement("library", "ability_http", "v" || .AIToolBrokerBuild~ABILITY_HTTP_VERSION, .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .AIToolBrokerBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method offer public
  expose abilityRegistry environment clientId catalog offerCount
  offerCount = offerCount + 1
  acquired = abilityRegistry~acquire(environment, clientId)
  if \acquired~ok then do
    self~recordOffer("DENIED", "", 0, acquired~code)
    return .RuntimeResult~failure("AI_TOOL_PROFILE_UNAVAILABLE", acquired~code || ": " || acquired~detail)
  end
  session = acquired~value
  generation = session~generationId
  definitions = .array~new
  do definition over catalog~allDefinitions
    descriptor = session~ability(definition~abilityId)
    if descriptor == .nil then do
      releaseOutcome = session~release
      self~recordOffer("DENIED", generation, definitions~items, "AI_TOOL_ABILITY_NOT_GRANTED")
      return .RuntimeResult~failure("AI_TOOL_ABILITY_NOT_GRANTED", definition~abilityId)
    end
    definitions~append(.AIProviderToolDefinition~new(definition~toolName, definition~description, descriptor~inputSchema~document))
  end
  releaseOutcome = session~release
  if \releaseOutcome~ok then do
    self~recordOffer("DENIED", generation, definitions~items, "AI_TOOL_SESSION_RELEASE_FAILED")
    return .RuntimeResult~failure("AI_TOOL_SESSION_RELEASE_FAILED", "tool offer session release failed")
  end
  toolOffer = .AIToolOffer~new(generation, definitions)
  self~recordOffer("READY", generation, toolOffer~count, "OK")
  return .RuntimeResult~success(toolOffer)

::method prepare public
  expose abilityRegistry environment clientId catalog preparationCount
  use arg proposal
  preparationCount = preparationCount + 1
  if proposal == .nil then return .RuntimeResult~failure("AI_TOOL_PROPOSAL_INVALID", "proposal missing")
  if \proposal~isa(.AIToolProposal) then return .RuntimeResult~failure("AI_TOOL_PROPOSAL_INVALID", "proposal type invalid")
  definition = catalog~resolve(proposal~toolName)
  if definition == .nil then do
    self~recordPrepare(proposal, "DENIED", "", "AI_TOOL_NOT_ALLOWED")
    return .RuntimeResult~failure("AI_TOOL_NOT_ALLOWED", proposal~toolName)
  end
  acquired = abilityRegistry~acquire(environment, clientId)
  if \acquired~ok then do
    self~recordPrepare(proposal, "DENIED", "", acquired~code)
    return .RuntimeResult~failure("AI_TOOL_PROFILE_UNAVAILABLE", acquired~code || ": " || acquired~detail)
  end
  return self~prepareSession(proposal, definition, acquired~value)

::method prepareOffered public
  expose abilityRegistry environment clientId catalog preparationCount
  use arg toolOffer, providerCall
  preparationCount = preparationCount + 1
  if toolOffer == .nil then return .RuntimeResult~failure("AI_TOOL_OFFER_INVALID", "tool offer missing")
  if \toolOffer~isa(.AIToolOffer) then return .RuntimeResult~failure("AI_TOOL_OFFER_INVALID", "tool offer type invalid")
  if providerCall == .nil then return .RuntimeResult~failure("AI_TOOL_PROPOSAL_INVALID", "provider tool call missing")
  if \providerCall~isa(.AIProviderToolCall) then return .RuntimeResult~failure("AI_TOOL_PROPOSAL_INVALID", "provider tool call type invalid")
  proposal = .AIToolProposal~fromProviderCall(providerCall)
  if \toolOffer~containsTool(proposal~toolName) then do
    self~recordPrepare(proposal, "DENIED", toolOffer~generationId, "AI_TOOL_NOT_OFFERED")
    return .RuntimeResult~failure("AI_TOOL_NOT_OFFERED", proposal~toolName)
  end
  definition = catalog~resolve(proposal~toolName)
  if definition == .nil then do
    self~recordPrepare(proposal, "DENIED", toolOffer~generationId, "AI_TOOL_NOT_ALLOWED")
    return .RuntimeResult~failure("AI_TOOL_NOT_ALLOWED", proposal~toolName)
  end
  acquired = abilityRegistry~acquire(environment, clientId)
  if \acquired~ok then do
    self~recordPrepare(proposal, "DENIED", "", acquired~code)
    return .RuntimeResult~failure("AI_TOOL_PROFILE_UNAVAILABLE", acquired~code || ": " || acquired~detail)
  end
  session = acquired~value
  if session~generationId \= toolOffer~generationId then do
    currentGeneration = session~generationId
    releaseOutcome = session~release
    self~recordPrepare(proposal, "STALE", currentGeneration, "AI_TOOL_OFFER_STALE")
    return .RuntimeResult~failure("AI_TOOL_OFFER_STALE", "offered Ability generation is no longer active")
  end
  return self~prepareSession(proposal, definition, session)

::method prepareSession private
  use arg proposal, definition, session
  descriptor = session~ability(definition~abilityId)
  if descriptor == .nil then do
    generation = session~generationId
    releaseOutcome = session~release
    self~recordPrepare(proposal, "DENIED", generation, "AI_TOOL_ABILITY_NOT_GRANTED")
    return .RuntimeResult~failure("AI_TOOL_ABILITY_NOT_GRANTED", definition~abilityId)
  end
  schemaOutcome = descriptor~validateInput(proposal~arguments)
  if \schemaOutcome~ok then do
    generation = session~generationId
    releaseOutcome = session~release
    self~recordPrepare(proposal, "DENIED", generation, "AI_TOOL_ARGUMENT_SCHEMA")
    return .RuntimeResult~failure("AI_TOOL_ARGUMENT_SCHEMA", schemaOutcome~code || ": " || schemaOutcome~detail)
  end
  ticket = .AIToolTicket~new(proposal, definition, session)
  self~recordPrepare(proposal, "READY", ticket~generationId, "OK")
  return .RuntimeResult~success(ticket)

::method execute public
  expose router executionCount
  use arg ticket
  executionCount = executionCount + 1
  if ticket == .nil then return .AIToolDispatchResult~failure("AI_TOOL_TICKET_INVALID", "ticket missing", 400)
  if \ticket~isa(.AIToolTicket) then return .AIToolDispatchResult~failure("AI_TOOL_TICKET_INVALID", "ticket type invalid", 400)
  dispatchResult = ticket~dispatch(router)
  event = .directory~new
  event["call_id"] = ticket~callId
  event["tool"] = ticket~toolName
  event["ability_id"] = ticket~abilityId
  event["generation_id"] = ticket~generationId
  event["ok"] = dispatchResult~ok
  event["http_status"] = dispatchResult~httpStatus
  if dispatchResult~execution == .nil then event["execution_metadata"] = .false
  else event["execution_metadata"] = .true
  self~alchemyInstrument("AI.TOOL.EXECUTE", event)
  return dispatchResult

::method recordOffer private
  use arg stateArg, generationArg, definitionCountArg, codeArg
  event = .directory~new
  event["state"] = stateArg
  event["generation_id"] = generationArg
  event["definition_count"] = definitionCountArg
  event["code"] = codeArg
  self~alchemyInstrument("AI.TOOL.OFFER", event)
  return event

::method recordPrepare private
  use arg proposal, stateArg, generationArg, codeArg
  event = .directory~new
  event["call_id"] = proposal~callId
  event["tool"] = proposal~toolName
  event["state"] = stateArg
  event["generation_id"] = generationArg
  event["code"] = codeArg
  event["argument_field_count"] = proposal~arguments~items
  self~alchemyInstrument("AI.TOOL.PREPARE", event)
  return event

::requires "AlchemyObject.cls"
::requires "AIProviderAccess.cls"
::requires "AbilityHttpServer.cls"
::requires "json.cls"
