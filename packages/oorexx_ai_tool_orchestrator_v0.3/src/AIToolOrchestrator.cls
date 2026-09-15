/* ooRexx AI Tool Orchestrator v0.3
 *
 * Provider-neutral coordination above AI Access and AI Tool Broker.
 * Model work is invoked only through Runtime Registry's canonical pinned
 * Ability route.  Tool work is invoked only through AIToolBroker tickets.
 * A pending model turn carries no Runtime Registry session or execution
 * authority.
 */

::class AIToolOrchestratorBuild public
::constant PRODUCT "ooRexx AI Tool Orchestrator"
::constant RELEASE "0.3"
::constant API_VERSION "ai.tool.orchestrator/0.3"
::constant RUNTIME_REGISTRY_VERSION "0.13"
::constant ABILITY_HTTP_VERSION "0.7"
::constant AI_ACCESS_VERSION "0.5"
::constant AI_TOOL_BROKER_VERSION "0.4"
::constant ALCHEMY_OBJECTS_VERSION "0.7"

/* Plain detached result of one successful model inference.  The stamped tool
 * offer and optional provider call are data, not retained execution authority. */
::class AIToolPendingTurn public
::attribute text get
::attribute model get
::attribute finishReason get
::attribute modelGenerationId get
::attribute toolOffer get
::attribute toolCall get
::attribute requestModel get
::attribute userPrompt get
::attribute maxOutputTokens get

::method init
  expose text model finishReason modelGenerationId toolOffer toolCall modelExecution requestModel userPrompt maxOutputTokens
  use arg textArg = "", modelArg = "", finishReasonArg = "stop", modelGenerationArg = "", toolOfferArg = .nil, toolCallArg = .nil, modelExecutionArg = .nil, requestModelArg = "", userPromptArg = "", maxOutputTokensArg = 256
  text = textArg~string
  model = modelArg~string~strip
  finishReason = finishReasonArg~string~strip
  modelGenerationId = modelGenerationArg~string~strip
  if toolOfferArg \== .nil then do
    if \toolOfferArg~isa(.AIToolOffer) then raise syntax 88.900 array("pending turn tool offer must be AIToolOffer")
  end
  if toolCallArg \== .nil then do
    if \toolCallArg~isa(.AIProviderToolCall) then raise syntax 88.900 array("pending turn tool call must be AIProviderToolCall")
  end
  toolOffer = toolOfferArg
  toolCall = toolCallArg
  requestModel = requestModelArg~string~strip
  if requestModel = "" then requestModel = model
  userPrompt = userPromptArg~string
  maxOutputTokens = maxOutputTokensArg
  if \datatype(maxOutputTokens, "W") then raise syntax 88.900 array("pending turn max output tokens must be whole")
  if maxOutputTokens < 1 then raise syntax 88.900 array("pending turn max output tokens must be positive")
  modelExecution = self~copyOptionalObject(modelExecutionArg, "pending model execution")

::method hasToolCall
  expose toolCall
  return toolCall \== .nil

::method modelExecution
  expose modelExecution
  return self~copyOptionalObject(modelExecution, "pending model execution")

::method copyOptionalObject private
  use arg source, label
  if source == .nil then return .nil
  if \source~isa(.Directory) then raise syntax 88.900 array(label || " must be Directory")
  copied = .JSON~fromJSON(.JSON~toJSON(source))
  if \copied~isa(.Directory) then raise syntax 88.900 array(label || " must project as JSON object")
  return copied


/* Plain final business/evidence split.  Tool execution evidence remains
 * detached from the tool business value. */
::class AIToolRunResult public
::attribute text get
::attribute model get
::attribute finishReason get
::attribute modelGenerationId get
::attribute toolExecuted get
::attribute toolName get
::attribute toolCallId get
::attribute toolGenerationId get
::attribute continuationPerformed get
::attribute continuationModelGenerationId get

::method init
  expose text model finishReason modelGenerationId toolExecuted toolName toolCallId toolGenerationId toolValue modelExecution toolExecution continuationPerformed continuationModelGenerationId continuationModelExecution
  use arg pending, dispatch = .nil, continuation = .nil
  if pending == .nil then raise syntax 88.900 array("run result requires pending turn")
  if \pending~isa(.AIToolPendingTurn) then raise syntax 88.900 array("run result pending turn type invalid")
  text = pending~text
  model = pending~model
  finishReason = pending~finishReason
  modelGenerationId = pending~modelGenerationId
  modelExecution = self~copyOptionalObject(pending~modelExecution, "model execution")
  toolExecuted = .false
  toolName = ""
  toolCallId = ""
  toolGenerationId = ""
  toolValue = .nil
  toolExecution = .nil
  continuationPerformed = .false
  continuationModelGenerationId = ""
  continuationModelExecution = .nil
  if dispatch \== .nil then do
    if \dispatch~isa(.AIToolDispatchResult) then raise syntax 88.900 array("run result dispatch type invalid")
    if \dispatch~ok then raise syntax 88.900 array("run result requires successful dispatch")
    call = pending~toolCall
    if call == .nil then raise syntax 88.900 array("run result dispatch has no provider call")
    toolExecuted = .true
    toolName = call~name
    toolCallId = call~callId
    toolGenerationId = dispatch~generationId
    toolValue = self~copyOptionalJson(dispatch~value)
    toolExecution = self~copyOptionalObject(dispatch~execution, "tool execution")
  end
  if continuation \== .nil then do
    if \continuation~isa(.AIToolPendingTurn) then raise syntax 88.900 array("run result continuation type invalid")
    if continuation~hasToolCall then raise syntax 88.900 array("run result continuation must not carry another tool call")
    continuationPerformed = .true
    continuationModelGenerationId = continuation~modelGenerationId
    continuationModelExecution = self~copyOptionalObject(continuation~modelExecution, "continuation model execution")
    text = continuation~text
    model = continuation~model
    finishReason = continuation~finishReason
  end

::method continuationModelExecution
  expose continuationModelExecution
  return self~copyOptionalObject(continuationModelExecution, "continuation model execution")

::method toolValue
  expose toolValue
  return self~copyOptionalJson(toolValue)

::method modelExecution
  expose modelExecution
  return self~copyOptionalObject(modelExecution, "model execution")

::method toolExecution
  expose toolExecution
  return self~copyOptionalObject(toolExecution, "tool execution")

::method copyOptionalObject private
  use arg source, label
  if source == .nil then return .nil
  if \source~isa(.Directory) then raise syntax 88.900 array(label || " must be Directory")
  copied = .JSON~fromJSON(.JSON~toJSON(source))
  if \copied~isa(.Directory) then raise syntax 88.900 array(label || " must project as JSON object")
  return copied

::method copyOptionalJson private
  use arg source
  if source == .nil then return .nil
  return .JSON~fromJSON(.JSON~toJSON(source))


::class AIToolOrchestrationOutcome public
::attribute ok get
::attribute code get
::attribute detail get
::attribute phase get
::attribute value get
::attribute httpStatus get
::attribute retryAfterSeconds get

::method init
  expose ok code detail phase value httpStatus retryAfterSeconds modelExecution toolExecution continuationModelExecution
  use arg okArg, codeArg = "OK", detailArg = "", phaseArg = "", valueArg = .nil, httpStatusArg = 0, retryAfterArg = .nil, modelExecutionArg = .nil, toolExecutionArg = .nil, continuationExecutionArg = .nil
  ok = okArg == .true
  code = codeArg~string~strip
  detail = detailArg~string
  phase = phaseArg~string~strip~upper
  value = valueArg
  httpStatus = httpStatusArg
  retryAfterSeconds = retryAfterArg
  modelExecution = self~copyOptionalObject(modelExecutionArg)
  toolExecution = self~copyOptionalObject(toolExecutionArg)
  continuationModelExecution = self~copyOptionalObject(continuationExecutionArg)

::method modelExecution
  expose modelExecution
  return self~copyOptionalObject(modelExecution)

::method toolExecution
  expose toolExecution
  return self~copyOptionalObject(toolExecution)

::method continuationModelExecution
  expose continuationModelExecution
  return self~copyOptionalObject(continuationModelExecution)

::method success class
  use arg phase, value = .nil, modelExecution = .nil, toolExecution = .nil, continuationExecution = .nil
  return self~new(.true, "OK", "", phase, value, 200, .nil, modelExecution, toolExecution, continuationExecution)

::method failure class
  use arg code, detail = "", phase = "", httpStatus = 0, retryAfter = .nil, modelExecution = .nil, toolExecution = .nil, value = .nil, continuationExecution = .nil
  return self~new(.false, code, detail, phase, value, httpStatus, retryAfter, modelExecution, toolExecution, continuationExecution)

::method copyOptionalObject private
  use arg source
  if source == .nil then return .nil
  if \source~isa(.Directory) then raise syntax 88.900 array("orchestration execution evidence must be Directory")
  copied = .JSON~fromJSON(.JSON~toJSON(source))
  if \copied~isa(.Directory) then raise syntax 88.900 array("orchestration execution evidence must project as JSON object")
  return copied


::class AIToolOrchestrator subclass AlchemyObject public

::method init
  expose modelRegistry modelRouter modelEnvironment modelClientId toolBroker inferenceCount dispatchCount
  use arg modelRegistryArg, modelRouterArg, modelEnvironmentArg, modelClientIdArg, toolBrokerArg
  if modelRegistryArg == .nil then raise syntax 88.900 array("AI tool orchestrator requires model AbilityRegistry")
  if modelRouterArg == .nil then raise syntax 88.900 array("AI tool orchestrator requires model AbilityHttpRouter")
  if toolBrokerArg == .nil then raise syntax 88.900 array("AI tool orchestrator requires AIToolBroker")
  if \toolBrokerArg~isa(.AIToolBroker) then raise syntax 88.900 array("AI tool orchestrator broker type invalid")
  modelEnvironment = modelEnvironmentArg~string~strip~lower
  modelClientId = modelClientIdArg~string~strip~lower
  if modelEnvironment = "" then raise syntax 88.900 array("AI tool orchestrator model environment required")
  if modelClientId = "" then raise syntax 88.900 array("AI tool orchestrator model client id required")
  modelRegistry = modelRegistryArg
  modelRouter = modelRouterArg
  toolBroker = toolBrokerArg
  inferenceCount = 0
  dispatchCount = 0

  meta = .directory~new
  meta["purpose"] = "Provider-neutral coordinator for canonical model inference and generation-stamped AI tool execution"
  meta["package_version"] = .AIToolOrchestratorBuild~RELEASE
  meta["api_version"] = .AIToolOrchestratorBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerStateVariable("modelRegistry", "SECRET", "model Ability Registry acquisition authority")
  self~registerStateVariable("modelRouter", "SECRET", "canonical model Ability dispatch authority")
  self~registerStateVariable("toolBroker", "SECRET", "tool proposal authorization and dispatch authority")
  self~registerStateVariable("inferenceCount", "INTERNAL", "aggregate orchestrated model inference count")
  self~registerStateVariable("dispatchCount", "INTERNAL", "aggregate orchestrated pending-turn dispatch count")
  self~registerMethodContract("INFER", "derive a generation-stamped tool offer and invoke model.complete through the canonical Ability route", .array~of("MODEL", "PROMPT", "MAXOUTPUTTOKENS"), "ANY", .false, "FALSE", "SECRET", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("DISPATCH", "authorize and execute at most one provider tool proposal, then perform exactly one structured continuation model turn", .array~of("PENDING"), "ANY", .false, "FALSE", "SECRET", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("RUNONCE", "perform one model inference, at most one tool execution, and at most one structured continuation model turn without automatic stale retry", .array~of("MODEL", "PROMPT", "MAXOUTPUTTOKENS"), "ANY", .false, "FALSE", "SECRET", "SENSITIVE", "EXTERNAL", "USE")
  self~registerInstrumentationPoint("AI.ORCHESTRATION.INFER", "records generations, status, call count and WLU-presence without prompt, schemas, model text or tool arguments", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.ORCHESTRATION.DISPATCH", "records status and generation identity without tool arguments, tool result contents or continuation contents", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "runtime_registry", "v" || .AIToolOrchestratorBuild~RUNTIME_REGISTRY_VERSION, .true)
  self~registerExternalRequirement("library", "ability_http", "v" || .AIToolOrchestratorBuild~ABILITY_HTTP_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_ai_access", "v" || .AIToolOrchestratorBuild~AI_ACCESS_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_ai_tool_broker", "v" || .AIToolOrchestratorBuild~AI_TOOL_BROKER_VERSION, .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .AIToolOrchestratorBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method infer public
  expose toolBroker inferenceCount
  use arg modelArg, promptArg, maxOutputTokensArg = 256
  inferenceCount = inferenceCount + 1

  offered = toolBroker~offer
  if \offered~ok then do
    self~recordInfer("DENIED", "", "", 0, .false, offered~code)
    return .AIToolOrchestrationOutcome~failure("AI_TOOL_OFFER_FAILED", offered~code || ": " || offered~detail, "OFFER", 503)
  end
  toolOffer = offered~value

  signal on syntax name requestInvalid
  providerRequest = .AIProviderRequest~new(modelArg, promptArg, maxOutputTokensArg, toolOffer~toolDefinitions)
  signal off syntax

  modelOutcome = self~invokeModel(providerRequest, toolOffer)
  if \modelOutcome~ok then do
    modelEvidence = modelOutcome~modelExecution
    self~recordInfer("DENIED", "", toolOffer~generationId, 0, modelEvidence \== .nil, modelOutcome~code)
    return modelOutcome
  end
  pending = modelOutcome~value
  callCount = 0
  if pending~hasToolCall then callCount = 1
  self~recordInfer("READY", pending~modelGenerationId, toolOffer~generationId, callCount, pending~modelExecution \== .nil, "OK")
  return modelOutcome

requestInvalid:
  signal off syntax
  self~recordInfer("DENIED", "", toolOffer~generationId, 0, .false, "AI_MODEL_REQUEST_INVALID")
  return .AIToolOrchestrationOutcome~failure("AI_MODEL_REQUEST_INVALID", "model request is invalid", "MODEL_REQUEST", 422)

::method dispatch public
  expose toolBroker dispatchCount
  use arg pending
  dispatchCount = dispatchCount + 1
  if pending == .nil then return .AIToolOrchestrationOutcome~failure("AI_PENDING_TURN_INVALID", "pending turn missing", "TOOL_PREPARE", 400)
  if \pending~isa(.AIToolPendingTurn) then return .AIToolOrchestrationOutcome~failure("AI_PENDING_TURN_INVALID", "pending turn type invalid", "TOOL_PREPARE", 400)

  if \pending~hasToolCall then do
    finalValue = .AIToolRunResult~new(pending)
    self~recordDispatch("COMPLETE", "", pending~modelGenerationId, "", .false, "OK")
    return .AIToolOrchestrationOutcome~success("COMPLETE", finalValue, pending~modelExecution, .nil)
  end

  prepared = toolBroker~prepareOffered(pending~toolOffer, pending~toolCall)
  if \prepared~ok then do
    status = 422
    if prepared~code = "AI_TOOL_OFFER_STALE" then status = 409
    self~recordDispatch("DENIED", pending~toolCall~name, pending~modelGenerationId, pending~toolOffer~generationId, .false, prepared~code)
    return .AIToolOrchestrationOutcome~failure(prepared~code, prepared~detail, "TOOL_PREPARE", status, .nil, pending~modelExecution)
  end

  dispatched = toolBroker~execute(prepared~value)
  if \dispatched~ok then do
    self~recordDispatch("DENIED", pending~toolCall~name, pending~modelGenerationId, dispatched~generationId, dispatched~execution \== .nil, dispatched~code)
    return .AIToolOrchestrationOutcome~failure(dispatched~code, dispatched~detail, "TOOL_EXECUTE", dispatched~httpStatus, dispatched~retryAfterSeconds, pending~modelExecution, dispatched~execution)
  end

  continuationOutcome = self~continueAfterTool(pending, dispatched)
  if \continuationOutcome~ok then do
    self~recordDispatch("DENIED", pending~toolCall~name, pending~modelGenerationId, dispatched~generationId, dispatched~execution \== .nil, continuationOutcome~code)
    return .AIToolOrchestrationOutcome~failure(continuationOutcome~code, continuationOutcome~detail, continuationOutcome~phase, continuationOutcome~httpStatus, continuationOutcome~retryAfterSeconds, pending~modelExecution, dispatched~execution, .nil, continuationOutcome~modelExecution)
  end
  continuation = continuationOutcome~value
  finalValue = .AIToolRunResult~new(pending, dispatched, continuation)
  self~recordDispatch("COMPLETE", pending~toolCall~name, pending~modelGenerationId, dispatched~generationId, dispatched~execution \== .nil, "OK")
  return .AIToolOrchestrationOutcome~success("COMPLETE", finalValue, pending~modelExecution, dispatched~execution, continuation~modelExecution)

::method continueAfterTool private
  use arg pending, dispatched
  signal on syntax name continuationInvalid
  toolResultText = .JSON~toJSON(dispatched~value)
  messages = .array~new
  messages~append(.AIProviderMessage~user(pending~userPrompt))
  messages~append(.AIProviderMessage~assistant(pending~text, .array~of(pending~toolCall)))
  messages~append(.AIProviderMessage~tool(pending~toolCall~callId, toolResultText))
  continuationRequest = .AIProviderRequest~new(pending~requestModel, "", pending~maxOutputTokens, .array~new, messages)
  signal off syntax
  continuationOutcome = self~invokeModel(continuationRequest, .nil, .false)
  if \continuationOutcome~ok then return .AIToolOrchestrationOutcome~failure(continuationOutcome~code, continuationOutcome~detail, "MODEL_CONTINUATION", continuationOutcome~httpStatus, continuationOutcome~retryAfterSeconds, continuationOutcome~modelExecution)
  return continuationOutcome

continuationInvalid:
  signal off syntax
  return .AIToolOrchestrationOutcome~failure("AI_TOOL_RESULT_NOT_SERIALIZABLE", "tool business result could not be converted to a structured continuation message", "MODEL_CONTINUATION", 502)

::method runOnce public
  use arg modelArg, promptArg, maxOutputTokensArg = 256
  inferred = self~infer(modelArg, promptArg, maxOutputTokensArg)
  if \inferred~ok then return inferred
  return self~dispatch(inferred~value)

::method invokeModel private
  expose modelRegistry modelRouter modelEnvironment modelClientId
  use arg providerRequest, toolOffer, allowToolCallArg = .true
  session = .nil
  signal on syntax name modelSyntax
  acquired = modelRegistry~acquire(modelEnvironment, modelClientId)
  if \acquired~ok then do
    signal off syntax
    return .AIToolOrchestrationOutcome~failure("AI_MODEL_PROFILE_UNAVAILABLE", acquired~code || ": " || acquired~detail, "MODEL_ACQUIRE", 503)
  end
  session = acquired~value
  modelGeneration = session~generationId
  descriptor = session~ability("model.complete")
  if descriptor == .nil then do
    releaseOutcome = session~release
    session = .nil
    signal off syntax
    return .AIToolOrchestrationOutcome~failure("AI_MODEL_ABILITY_NOT_GRANTED", "model.complete", "MODEL_ACQUIRE", 403)
  end

  bodyObject = self~providerRequestBody(providerRequest)
  headers = .directory~new
  headers["content-type"] = "application/json"
  request = .AbilityHttpRequest~new("POST", "/v1/abilities/model.complete", "HTTP/1.1", headers, .JSON~toJSON(bodyObject))
  response = modelRouter~routePinnedAbility(session, "model.complete", request)
  decoded = self~decodeModelResponse(response, modelGeneration, toolOffer, providerRequest, allowToolCallArg)
  releaseOutcome = session~release
  session = .nil
  if \releaseOutcome~ok then do
    signal off syntax
    return .AIToolOrchestrationOutcome~failure("AI_MODEL_SESSION_RELEASE_FAILED", "model Ability session release failed", "MODEL_RELEASE", 500, .nil, decoded~modelExecution, .nil, decoded~value)
  end
  signal off syntax
  return decoded

modelSyntax:
  signal off syntax
  if session \== .nil then do
    if \session~released then releaseOutcome = session~release
  end
  return .AIToolOrchestrationOutcome~failure("AI_MODEL_ROUTE_FAILED", "model Ability processing raised a condition", "MODEL_ROUTE", 500)

::method providerRequestBody private
  use arg providerRequest
  body = .directory~new
  body["model"] = providerRequest~model
  body["prompt"] = providerRequest~prompt
  body["max_output_tokens"] = providerRequest~maxOutputTokens
  if providerRequest~toolDefinitionCount > 0 then do
    wireTools = .array~new
    do definition over providerRequest~toolDefinitions
      item = .directory~new
      item["name"] = definition~name
      item["description"] = definition~description
      item["input_schema"] = definition~inputSchema
      wireTools~append(item)
    end
    body["tools"] = wireTools
  end
  if providerRequest~messageCount > 0 then do
    wireMessages = .array~new
    do message over providerRequest~messages
      item = .directory~new
      item["role"] = message~role
      item["content"] = message~content
      if message~role = "tool" then item["tool_call_id"] = message~toolCallId
      if message~role = "assistant" then do
        if message~toolCallCount > 0 then do
          calls = .array~new
          do toolCall over message~toolCalls
            callItem = .directory~new
            callItem["call_id"] = toolCall~callId
            callItem["name"] = toolCall~name
            callItem["arguments"] = toolCall~arguments
            calls~append(callItem)
          end
          item["tool_calls"] = calls
        end
      end
      wireMessages~append(item)
    end
    body["messages"] = wireMessages
  end
  return body

::method decodeModelResponse private
  use arg response, modelGeneration, toolOffer, providerRequest, allowToolCallArg = .true
  signal on syntax name decodeFailure
  envelope = .JSON~fromJSON(response~body)
  execution = .nil
  if envelope~isa(.Directory) then execution = self~copyOptionalObject(envelope~at("execution"))

  if response~status \= 200 then do
    detail = "model Ability invocation failed"
    code = "AI_MODEL_ABILITY_FAILED"
    retryAfter = .nil
    if response~status = 429 then code = "AI_MODEL_WLU_DENIED"
    if envelope~isa(.Directory) then do
      value = envelope~at("detail")
      if value \== .nil then detail = value~string
      wluCode = envelope~at("wlu_code")
      if wluCode \== .nil then code = "AI_MODEL_WLU_DENIED"
      retryValue = envelope~at("retry_after_seconds")
      if retryValue \== .nil then retryAfter = retryValue
    end
    return .AIToolOrchestrationOutcome~failure(code, detail, "MODEL_EXECUTE", response~status, retryAfter, execution)
  end

  if \envelope~isa(.Directory) then return .AIToolOrchestrationOutcome~failure("AI_MODEL_REPLY_INVALID", "model response envelope must be object", "MODEL_DECODE", 502, .nil, execution)
  payload = envelope~at("result")
  if \payload~isa(.Directory) then return .AIToolOrchestrationOutcome~failure("AI_MODEL_REPLY_INVALID", "model result must be object", "MODEL_DECODE", 502, .nil, execution)
  textValue = payload~at("text"); if textValue == .nil then textValue = ""
  modelValue = payload~at("model"); if modelValue == .nil then modelValue = ""
  finishValue = payload~at("finish_reason"); if finishValue == .nil then finishValue = "stop"
  callsValue = payload~at("tool_calls")
  calls = .array~new
  if callsValue \== .nil then do
    if \callsValue~isa(.Array) then return .AIToolOrchestrationOutcome~failure("AI_MODEL_REPLY_INVALID", "tool_calls must be array", "MODEL_DECODE", 502, .nil, execution)
    do item over callsValue
      if \item~isa(.Directory) then return .AIToolOrchestrationOutcome~failure("AI_MODEL_REPLY_INVALID", "tool call must be object", "MODEL_DECODE", 502, .nil, execution)
      callId = item~at("call_id")
      toolName = item~at("name")
      arguments = item~at("arguments")
      if callId == .nil then return .AIToolOrchestrationOutcome~failure("AI_MODEL_REPLY_INVALID", "tool call id missing", "MODEL_DECODE", 502, .nil, execution)
      if toolName == .nil then return .AIToolOrchestrationOutcome~failure("AI_MODEL_REPLY_INVALID", "tool call name missing", "MODEL_DECODE", 502, .nil, execution)
      if arguments == .nil then arguments = .directory~new
      calls~append(.AIProviderToolCall~new(callId, toolName, arguments))
    end
  end
  if calls~items > 1 then return .AIToolOrchestrationOutcome~failure("AI_TOOL_MULTIPLE_CALLS_UNSUPPORTED", "v0.3 does not execute multiple tool calls in one model turn", "MODEL_DECODE", 422, .nil, execution)
  if \allowToolCallArg then do
    if calls~items > 0 then return .AIToolOrchestrationOutcome~failure("AI_TOOL_CONTINUATION_CALL_UNSUPPORTED", "v0.3 permits no further tool proposal during the continuation turn", "MODEL_CONTINUATION", 422, .nil, execution)
  end

  callObject = .nil
  if calls~items = 1 then callObject = calls~at(1)
  pending = .AIToolPendingTurn~new(textValue, modelValue, finishValue, modelGeneration, toolOffer, callObject, execution, providerRequest~model, providerRequest~prompt, providerRequest~maxOutputTokens)
  return .AIToolOrchestrationOutcome~success("MODEL", pending, execution)

decodeFailure:
  signal off syntax
  return .AIToolOrchestrationOutcome~failure("AI_MODEL_REPLY_INVALID", "model response could not be decoded", "MODEL_DECODE", 502)

::method recordInfer private
  use arg stateArg, modelGenerationArg, toolGenerationArg, callCountArg, hasWluArg, codeArg
  event = .directory~new
  event["state"] = stateArg
  event["model_generation_id"] = modelGenerationArg
  event["tool_generation_id"] = toolGenerationArg
  event["tool_call_count"] = callCountArg
  event["execution_metadata"] = hasWluArg
  event["code"] = codeArg
  self~alchemyInstrument("AI.ORCHESTRATION.INFER", event)
  return event

::method recordDispatch private
  use arg stateArg, toolArg, modelGenerationArg, toolGenerationArg, hasWluArg, codeArg
  event = .directory~new
  event["state"] = stateArg
  event["tool"] = toolArg
  event["model_generation_id"] = modelGenerationArg
  event["tool_generation_id"] = toolGenerationArg
  event["execution_metadata"] = hasWluArg
  event["code"] = codeArg
  self~alchemyInstrument("AI.ORCHESTRATION.DISPATCH", event)
  return event

::method copyOptionalObject private
  use arg source
  if source == .nil then return .nil
  if \source~isa(.Directory) then return .nil
  copied = .JSON~fromJSON(.JSON~toJSON(source))
  if \copied~isa(.Directory) then return .nil
  return copied

::requires "AlchemyObject.cls"
::requires "AIProviderAccess.cls"
::requires "AIToolBroker.cls"
::requires "AbilityHttpServer.cls"
::requires "json.cls"
