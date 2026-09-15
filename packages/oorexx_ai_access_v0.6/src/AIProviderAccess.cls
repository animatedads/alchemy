/* ooRexx AI Access v0.6
 *
 * Provider-neutral model access layer intended to be loaded as a normal
 * Runtime Registry capability artifact.
 *
 * v0.6 retains the v0.5 provider-neutral authority, tool-proposal and structured-conversation
 * API while repairing the common behavioural-base adoption contract:
 *   - preferred non-virtual Alchemy v0.7 INIT construction;
 *   - complete STANDARD adoption metadata;
 *   - Runtime Registry v0.14 qualification;
 *   - optional Work Load Units v0.12 qualification.
 *   - AIProviderRuntimeCapability
 *   - AIProviderAdapterBase
 *
 * The narrow value boundary deliberately does NOT inherit AlchemyObject.
 * AIProviderRequest remains a plain bounded value object carrying model input,
 * optional model-visible tool descriptions and structured messages only, so
 * adopting the common base cannot accidentally hand a provider
 * Ability/Registry/WLU authority through a behavioural request object.
 *
 * Authority boundary:
 *   - the outer runtime capability receives AbilityInvocationContext;
 *   - the provider implementation receives only AIProviderRequest;
 *   - the provider never receives RuntimeRegistry, AbilitySession, WLU
 *     authority/account/rate-card/reservation objects, or caller credentials;
 *   - the wrapper owns metering and projects a bounded business response.
 */

::class AIProviderAccessBuild public
::constant PRODUCT "ooRexx AI Access"
::constant RELEASE "0.6"
::constant API_VERSION "ai.provider.access/0.5"
::constant ALCHEMY_OBJECTS_VERSION "0.7"
::constant RUNTIME_REGISTRY_VERSION "0.14"
::constant WLU_VERSION "0.12"

/* Plain JSON-like value object describing one model-visible tool.  It contains
 * no internal Ability id and no execution authority. */
::class AIProviderToolDefinition public
::attribute name get
::attribute description get

::method init
  expose name description inputSchema
  use arg nameArg, descriptionArg = "", inputSchemaArg = .nil
  name = nameArg~string~strip~lower
  description = descriptionArg~string
  if name = "" then raise syntax 88.900 array("AI provider tool name must not be empty")
  allowed = "abcdefghijklmnopqrstuvwxyz0123456789._-"
  if verify(name, allowed) \= 0 then raise syntax 88.900 array("AI provider tool name contains unsupported character")
  if inputSchemaArg == .nil then inputSchemaArg = .directory~new
  if \inputSchemaArg~isa(.Directory) then raise syntax 88.900 array("AI provider tool input schema must be Directory")
  inputSchema = self~copyJsonObject(inputSchemaArg, "AI provider tool input schema")

::method inputSchema
  expose inputSchema
  return self~copyJsonObject(inputSchema, "AI provider tool input schema")

::method copyJsonObject private
  use arg source, label
  wireText = .JSON~toJSON(source)
  copied = .JSON~fromJSON(wireText)
  if \copied~isa(.Directory) then raise syntax 88.900 array(label || " must project as JSON object")
  return copied


/* Plain provider-returned tool proposal.  Arguments are detached at the
 * provider boundary; this object still carries no execution authority. */
::class AIProviderToolCall public
::attribute callId get
::attribute name get

::method init
  expose callId name arguments
  use arg callIdArg, nameArg, argumentsArg = .nil
  callId = callIdArg~string~strip
  name = nameArg~string~strip~lower
  if callId = "" then raise syntax 88.900 array("AI provider tool call id must not be empty")
  if name = "" then raise syntax 88.900 array("AI provider tool call name must not be empty")
  if argumentsArg == .nil then argumentsArg = .directory~new
  if \argumentsArg~isa(.Directory) then raise syntax 88.900 array("AI provider tool call arguments must be Directory")
  wireText = .JSON~toJSON(argumentsArg)
  arguments = .JSON~fromJSON(wireText)
  if \arguments~isa(.Directory) then raise syntax 88.900 array("AI provider tool call arguments must project as JSON object")

::method arguments
  expose arguments
  return .JSON~fromJSON(.JSON~toJSON(arguments))




/* Plain provider-neutral conversation message.  This is data only: roles are
 * intentionally limited to user/assistant/tool; tool result messages bind to
 * a provider call id, never to an internal Ability id. */
::class AIProviderMessage public
::attribute role get
::attribute content get
::attribute toolCallId get

::method init
  expose role content toolCallId toolCalls
  use arg roleArg, contentArg = "", toolCallsArg = .nil, toolCallIdArg = ""
  role = roleArg~string~strip~lower
  content = contentArg~string
  toolCallId = toolCallIdArg~string~strip
  if role = "" then raise syntax 88.900 array("AI provider message role must not be empty")
  validRole = role = "user"
  if \validRole then validRole = role = "assistant"
  if \validRole then validRole = role = "tool"
  if \validRole then raise syntax 88.900 array("AI provider message role unsupported")

  toolCalls = .array~new
  if toolCallsArg == .nil then toolCallsArg = .array~new
  if \toolCallsArg~isa(.Array) then raise syntax 88.900 array("AI provider message tool calls must be Array")
  if toolCallsArg~items > 64 then raise syntax 88.900 array("AI provider message tool call count exceeds package bound")
  do toolCall over toolCallsArg
    if \toolCall~isa(.AIProviderToolCall) then raise syntax 88.900 array("AI provider message tool calls must contain AIProviderToolCall")
    toolCalls~append(toolCall)
  end

  if role = "user" then do
    if toolCallId <> "" then raise syntax 88.900 array("user message cannot carry tool call id")
    if toolCalls~items > 0 then raise syntax 88.900 array("user message cannot carry tool calls")
  end
  if role = "assistant" then do
    if toolCallId <> "" then raise syntax 88.900 array("assistant message cannot carry tool call id")
  end
  if role = "tool" then do
    if toolCallId = "" then raise syntax 88.900 array("tool message requires tool call id")
    if toolCalls~items > 0 then raise syntax 88.900 array("tool message cannot carry tool calls")
  end

::method toolCalls
  expose toolCalls
  copied = .array~new
  do toolCall over toolCalls
    copied~append(toolCall)
  end
  return copied

::method toolCallCount
  expose toolCalls
  return toolCalls~items

::method user class
  use arg contentArg
  return self~new("user", contentArg, .array~new, "")

::method assistant class
  use arg contentArg = "", toolCallsArg = .nil
  return self~new("assistant", contentArg, toolCallsArg, "")

::method tool class
  use arg callIdArg, contentArg
  return self~new("tool", contentArg, .array~new, callIdArg)


/* Intentionally plain value object: this is the narrow provider authority
 * boundary.  Do not add Ability/Registry/WLU context methods here. */
::class AIProviderRequest public
::attribute model get
::attribute prompt get
::attribute maxOutputTokens get

::method init
  expose model prompt maxOutputTokens toolDefinitions messages
  use arg modelArg, promptArg, maxOutputTokensArg = 256, toolDefinitionsArg = .nil, messagesArg = .nil
  model = modelArg~string~strip
  prompt = promptArg~string
  maxOutputTokens = maxOutputTokensArg

  if model = "" then raise syntax 88.900 array("AI provider model must not be empty")
  if \datatype(maxOutputTokens, "W") then raise syntax 88.900 array("AI provider maxOutputTokens must be a whole number")
  if maxOutputTokens < 1 then raise syntax 88.900 array("AI provider maxOutputTokens must be positive")
  if maxOutputTokens > 8192 then raise syntax 88.900 array("AI provider maxOutputTokens exceeds package bound")

  toolDefinitions = .array~new
  if toolDefinitionsArg == .nil then toolDefinitionsArg = .array~new
  if \toolDefinitionsArg~isa(.Array) then raise syntax 88.900 array("AI provider tool definitions must be Array")
  if toolDefinitionsArg~items > 64 then raise syntax 88.900 array("AI provider tool definition count exceeds package bound")
  do definition over toolDefinitionsArg
    if \definition~isa(.AIProviderToolDefinition) then raise syntax 88.900 array("AI provider tool definitions must contain AIProviderToolDefinition")
    toolDefinitions~append(definition)
  end

  messages = .array~new
  if messagesArg == .nil then messagesArg = .array~new
  if \messagesArg~isa(.Array) then raise syntax 88.900 array("AI provider messages must be Array")
  if messagesArg~items > 64 then raise syntax 88.900 array("AI provider message count exceeds package bound")
  do message over messagesArg
    if \message~isa(.AIProviderMessage) then raise syntax 88.900 array("AI provider messages must contain AIProviderMessage")
    messages~append(message)
  end
  if messages~items > 0 then do
    if prompt <> "" then raise syntax 88.900 array("AI provider request cannot combine prompt content with structured messages")
  end

::method toolDefinitions
  expose toolDefinitions
  copied = .array~new
  do definition over toolDefinitions
    copied~append(definition)
  end
  return copied

::method toolDefinitionCount
  expose toolDefinitions
  return toolDefinitions~items

::method messages
  expose messages
  copied = .array~new
  do message over messages
    copied~append(message)
  end
  return copied

::method messageCount
  expose messages
  return messages~items


/* Intentionally plain value object: provider-returned work facts, not WLU
 * authority or a reservation. */
::class AIProviderUsage public
::attribute inputTokens get
::attribute outputTokens get

::method init
  expose inputTokens outputTokens
  use arg inputTokensArg = 0, outputTokensArg = 0
  if \datatype(inputTokensArg, "W") then raise syntax 88.900 array("AI provider input token usage must be whole")
  if \datatype(outputTokensArg, "W") then raise syntax 88.900 array("AI provider output token usage must be whole")
  if inputTokensArg < 0 then raise syntax 88.900 array("AI provider input token usage must not be negative")
  if outputTokensArg < 0 then raise syntax 88.900 array("AI provider output token usage must not be negative")
  inputTokens = inputTokensArg
  outputTokens = outputTokensArg

::method totalTokens
  expose inputTokens outputTokens
  return inputTokens + outputTokens


/* Intentionally plain value object.  Provider-specific adapters are
 * responsible for sanitising failure detail before constructing a reply. */
::class AIProviderReply public
::attribute ok get
::attribute code get
::attribute detail get
::attribute text get
::attribute model get
::attribute finishReason get
::attribute usage get

::method init
  expose ok code detail text model finishReason usage toolCalls
  use arg okArg, codeArg = "OK", detailArg = "", textArg = "", modelArg = "", finishReasonArg = "", usageArg = .nil, toolCallsArg = .nil
  ok = okArg == .true
  code = codeArg~string~strip
  detail = detailArg~string
  text = textArg~string
  model = modelArg~string~strip
  finishReason = finishReasonArg~string~strip
  if usageArg == .nil then usage = .AIProviderUsage~new(0, 0)
  else do
    if \usageArg~isa(.AIProviderUsage) then raise syntax 88.900 array("AI provider reply usage must be AIProviderUsage")
    usage = usageArg
  end
  toolCalls = .array~new
  if toolCallsArg == .nil then toolCallsArg = .array~new
  if \toolCallsArg~isa(.Array) then raise syntax 88.900 array("AI provider reply tool calls must be Array")
  if toolCallsArg~items > 64 then raise syntax 88.900 array("AI provider reply tool call count exceeds package bound")
  do toolCall over toolCallsArg
    if \toolCall~isa(.AIProviderToolCall) then raise syntax 88.900 array("AI provider reply tool calls must contain AIProviderToolCall")
    toolCalls~append(toolCall)
  end
  if ok then do
    if code = "" then code = "OK"
  end
  else do
    if code = "" then raise syntax 88.900 array("AI provider failure code must not be empty")
  end

::method toolCalls
  expose toolCalls
  copied = .array~new
  do toolCall over toolCalls
    copied~append(toolCall)
  end
  return copied

::method toolCallCount
  expose toolCalls
  return toolCalls~items

::method success class
  use arg text, model = "", finishReason = "stop", usage = .nil, toolCalls = .nil
  return self~new(.true, "OK", "", text, model, finishReason, usage, toolCalls)

::method failure class
  use arg code, detail = "", usage = .nil, model = ""
  return self~new(.false, code, detail, "", model, "", usage, .array~new)


/* Common provider-adapter behavioural base.  Real provider packages normally
 * override completeRequest(), not complete().  That leaves lifecycle and
 * non-content instrumentation in one place while keeping provider-specific
 * network/credential behavior out of this generic package. */
::class AIProviderAdapterBase subclass AlchemyObject public

::method init
  meta = .directory~new
  meta["purpose"] = "Provider adapter behind the ooRexx AI Access narrow request boundary"
  meta["package_version"] = .AIProviderAccessBuild~RELEASE
  meta["api_version"] = "ai.provider.adapter/0.1"
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.7; ai.provider.access/0.5 narrow provider authority boundary"
  meta["design_limitations"] = "Provider-neutral behavioural base only; credentials, provider transport, model policy, Runtime Registry lifecycle and WLU admission authority remain outside the provider request value boundary"
  self~init:super(meta)
  self~registerMethodContract("SELFTEST", "validate provider adapter surface", .array~new, "BOOLEAN", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("COMPLETE", "execute one provider model completion through the narrow request object", .array~of("REQUEST"), "ANY", .false, "AUTO", "INTERNAL", "SENSITIVE", "EXTERNAL", "NONE")
  self~describeMethodData("COMPLETE", "INPUT", "request", "AIPROVIDERREQUEST", .true, "bounded provider request without Ability/Registry/WLU authority", "INTERNAL")
  self~registerInstrumentationPoint("AI.PROVIDER.COMPLETE.BEFORE", "provider completion entered; records bounded non-content request metadata", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.PROVIDER.COMPLETE.AFTER", "provider completion returned; records bounded usage/status metadata", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.PROVIDER.COMPLETE.FAIL", "provider completion raised; records condition identity without condition message", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .AIProviderAccessBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method selfTest public
  return self~checkSurfaceContract~ok

::method complete public
  use arg request
  if request == .nil then return .AIProviderReply~failure("AI_PROVIDER_REQUEST_TYPE", "expected AIProviderRequest")
  if \request~isa(.AIProviderRequest) then return .AIProviderReply~failure("AI_PROVIDER_REQUEST_TYPE", "expected AIProviderRequest")

  self~alchemyTouch("PROVIDER.COMPLETE")
  before = .directory~new
  before["model"] = request~model
  before["max_output_tokens"] = request~maxOutputTokens
  before["prompt_characters"] = request~prompt~length
  before["tool_definition_count"] = request~toolDefinitionCount
  before["message_count"] = request~messageCount
  self~alchemyInstrument("AI.PROVIDER.COMPLETE.BEFORE", before)

  signal on syntax name providerAdapterRaised
  providerReply = self~completeRequest(request)
  signal off syntax

  after = .directory~new
  if providerReply == .nil then do
    after["reply_class"] = "NIL"
    after["ok"] = .false
  end
  else do
    after["reply_class"] = providerReply~class~id
    if providerReply~isa(.AIProviderReply) then do
      after["ok"] = providerReply~ok
      after["code"] = providerReply~code
      after["input_tokens"] = providerReply~usage~inputTokens
      after["output_tokens"] = providerReply~usage~outputTokens
      after["tool_call_count"] = providerReply~toolCallCount
    end
  end
  self~alchemyInstrument("AI.PROVIDER.COMPLETE.AFTER", after)
  return providerReply

providerAdapterRaised:
  signal off syntax
  info = condition("O")
  ev = .directory~new
  ev["condition"] = condition("C")
  if info \== .nil then do
    code = info~at("CODE")
    if code \== .nil then ev["code"] = code~string
  end
  self~alchemyInstrument("AI.PROVIDER.COMPLETE.FAIL", ev)
  raise propagate

/* Subclasses implement provider-specific behavior here. */
::method completeRequest protected
  use arg request
  return .AIProviderReply~failure("AI_PROVIDER_NOT_IMPLEMENTED", "provider adapter did not implement completeRequest", .AIProviderUsage~new(0, 0), request~model)


::class AIProviderRuntimeCapability subclass AlchemyObject public

::method init
  expose provider invocationCount
  invocationCount = 0

  meta = .directory~new
  meta["purpose"] = "Runtime Registry capability wrapper for provider-neutral AI model access"
  meta["package_version"] = .AIProviderAccessBuild~RELEASE
  meta["api_version"] = .AIProviderAccessBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.7; ai.provider.access/0.5; runtime.registry/0.3; ability.http/0.7"
  meta["design_limitations"] = "Wrapper retains Runtime Registry and optional WLU metering authority but provides no provider credential store, no provider-specific transport policy and no untrusted-process containment"
  self~init:super(meta)
  self~registerStateVariable("invocationCount", "INTERNAL", "aggregate dynamic provider invocation count for this immutable runtime generation")
  self~registerStateVariable("provider", "SECRET", "provider adapter object reference; never customer disclosure")
  self~registerMethodContract("RUNTIMESELFTEST", "Runtime Registry generation self-test", .array~new, "BOOLEAN", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("RUNTIMEINVOCATIONCOUNT", "return aggregate dynamic invocation count", .array~new, "NUMERIC", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerMethodContract("RUNTIMEINVOKEABILITY", "invoke a bounded AI ability using AbilityInvocationContext while retaining metering authority outside the provider", .array~of("ABILITYID", "CONTEXT"), "ANY", .false, "AUTO", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~describeMethodData("RUNTIMEINVOKEABILITY", "INPUT", "abilityId", "STRING", .true, "ability identifier", "INTERNAL")
  self~describeMethodData("RUNTIMEINVOKEABILITY", "INPUT", "context", "ABILITYINVOCATIONCONTEXT", .true, "outer runtime context retained by wrapper and never handed to provider", "SECRET")
  self~registerMethodContract("CREATEPROVIDER", "deployment/provider-specific provider construction hook", .array~new, "ANY", .true, "FALSE", "SECRET", "SECURITY_BOUNDARY", "EXTERNAL", "NONE")
  self~registerInstrumentationPoint("AI.INVOCATION.BEFORE", "AI ability invocation entered; no prompt contents recorded", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.INVOCATION.AFTER", "AI ability invocation completed; bounded model/usage/status only", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.INVOCATION.FAIL", "AI ability invocation failed; bounded stage/code only", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .AIProviderAccessBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~registerExternalRequirement("library", "runtime_registry", "v" || .AIProviderAccessBuild~RUNTIME_REGISTRY_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_work_load_units", "v" || .AIProviderAccessBuild~WLU_VERSION, .false)
  self~declareHouseCompliance(95)

  provider = self~createProvider
  if provider == .nil then raise syntax 88.900 array("AI provider module did not create a provider implementation")
  if \provider~hasMethod("COMPLETE") then raise syntax 88.900 array("AI provider implementation must implement complete(request)")
  self~recordRelationship("PROVIDER_ADAPTER", provider, "provider implementation behind narrow AIProviderRequest boundary", "INTERNAL")

/* Subclasses provide a deployment/provider-specific implementation. */
::method createProvider protected
  return .nil

::method runtimeSelfTest public
  expose provider
  if \self~checkSurfaceContract~ok then return .false
  if provider == .nil then return .false
  if \provider~hasMethod("COMPLETE") then return .false
  if provider~isa(.AlchemyObject) then do
    if \provider~checkSurfaceContract~ok then return .false
  end
  if provider~hasMethod("SELFTEST") then return provider~selfTest == .true
  return .true

::method runtimeInvocationCount public
  expose invocationCount
  return invocationCount

::method runtimeInvokeAbility public
  expose provider invocationCount
  use arg abilityId, context
  invocationCount = invocationCount + 1
  self~alchemyTouch("RUNTIMEINVOKEABILITY")

  before = .directory~new
  before["invocation"] = invocationCount
  before["ability_id"] = abilityId~string~strip~lower
  self~alchemyInstrument("AI.INVOCATION.BEFORE", before)

  if abilityId~string~strip~lower <> "model.complete" then return self~invocationFailure(context, "AI_ABILITY_UNKNOWN", abilityId, "ABILITY")

  body = context~body
  if body == .nil then return self~invocationFailure(context, "AI_REQUEST_INVALID", "request body missing", "REQUEST")
  if \body~isa(.Directory) then return self~invocationFailure(context, "AI_REQUEST_INVALID", "request body must be Directory", "REQUEST")

  model = body~at("model")
  prompt = body~at("prompt")
  maxOutputTokens = body~at("max_output_tokens")
  if model == .nil then return self~invocationFailure(context, "AI_REQUEST_INVALID", "model missing", "REQUEST")
  if prompt == .nil then return self~invocationFailure(context, "AI_REQUEST_INVALID", "prompt missing", "REQUEST")
  if maxOutputTokens == .nil then maxOutputTokens = 256
  toolsValue = body~at("tools")
  messagesValue = body~at("messages")

  signal on syntax name requestInvalid
  toolDefinitions = self~decodeToolDefinitions(toolsValue)
  messages = self~decodeMessages(messagesValue)
  providerRequest = .AIProviderRequest~new(model, prompt, maxOutputTokens, toolDefinitions, messages)
  signal off syntax

  signal on syntax name providerRaised
  providerReply = provider~complete(providerRequest)
  signal off syntax

  if providerReply == .nil then return self~invocationFailure(context, "AI_PROVIDER_REPLY_INVALID", "provider returned nil", "PROVIDER")
  if \providerReply~isa(.AIProviderReply) then return self~invocationFailure(context, "AI_PROVIDER_REPLY_INVALID", "provider returned unsupported object", "PROVIDER")

  meterOutcome = self~meterUsage(context, providerReply~usage)
  if meterOutcome \== .nil then do
    if \meterOutcome~ok then do
      self~recordInvocationFailure("METER", meterOutcome~code)
      return meterOutcome
    end
  end

  if \providerReply~ok then return self~invocationFailure(context, providerReply~code, providerReply~detail, "PROVIDER")

  responseData = .directory~new
  responseData["text"] = providerReply~text
  if providerReply~model = "" then responseData["model"] = providerRequest~model
  else responseData["model"] = providerReply~model
  if providerReply~finishReason = "" then responseData["finish_reason"] = "stop"
  else responseData["finish_reason"] = providerReply~finishReason
  if providerReply~toolCallCount > 0 then do
    projectedCalls = .array~new
    do toolCall over providerReply~toolCalls
      projected = .directory~new
      projected["call_id"] = toolCall~callId
      projected["name"] = toolCall~name
      projected["arguments"] = toolCall~arguments
      projectedCalls~append(projected)
    end
    responseData["tool_calls"] = projectedCalls
  end

  after = .directory~new
  after["invocation"] = invocationCount
  after["model"] = responseData["model"]
  after["finish_reason"] = responseData["finish_reason"]
  after["input_tokens"] = providerReply~usage~inputTokens
  after["output_tokens"] = providerReply~usage~outputTokens
  after["tool_call_count"] = providerReply~toolCallCount
  after["message_count"] = providerRequest~messageCount
  self~alchemyInstrument("AI.INVOCATION.AFTER", after)
  return context~success(responseData)

requestInvalid:
  signal off syntax
  info = condition("O")
  detail = "invalid AI provider request"
  if info \== .nil then do
    message = info~at("MESSAGE")
    if message \== .nil then do
      if message <> "" then detail = message
    end
  end
  return self~invocationFailure(context, "AI_REQUEST_INVALID", detail, "REQUEST")

providerRaised:
  signal off syntax
  /* Raw provider condition messages may contain SDK/network/credential data.
   * They are deliberately not returned to the caller and are not placed in
   * Alchemy instrumentation. */
  self~recordInvocationFailure("PROVIDER_EXCEPTION", "AI_PROVIDER_EXCEPTION")
  return context~failure("AI_PROVIDER_EXCEPTION", "provider raised a condition")

::method decodeToolDefinitions private
  use arg toolsValue
  definitions = .array~new
  if toolsValue == .nil then return definitions
  if \toolsValue~isa(.Array) then raise syntax 88.900 array("tools must be Array")
  if toolsValue~items > 64 then raise syntax 88.900 array("tool definition count exceeds package bound")
  do item over toolsValue
    if \item~isa(.Directory) then raise syntax 88.900 array("tool definition must be JSON object")
    keys = item~allIndexes
    do key over keys
      keyName = key~string
      allowedKey = keyName = "name"
      if \allowedKey then allowedKey = keyName = "description"
      if \allowedKey then allowedKey = keyName = "input_schema"
      if \allowedKey then raise syntax 88.900 array("unsupported tool definition field: " || keyName)
    end
    nameValue = item~at("name")
    if nameValue == .nil then raise syntax 88.900 array("tool definition name missing")
    descriptionValue = item~at("description")
    if descriptionValue == .nil then descriptionValue = ""
    schemaValue = item~at("input_schema")
    if schemaValue == .nil then raise syntax 88.900 array("tool definition input_schema missing")
    definitions~append(.AIProviderToolDefinition~new(nameValue, descriptionValue, schemaValue))
  end
  return definitions

::method decodeMessages private
  use arg messagesValue
  messages = .array~new
  if messagesValue == .nil then return messages
  if \messagesValue~isa(.Array) then raise syntax 88.900 array("messages must be Array")
  if messagesValue~items > 64 then raise syntax 88.900 array("message count exceeds package bound")
  do item over messagesValue
    if \item~isa(.Directory) then raise syntax 88.900 array("message must be JSON object")
    keys = item~allIndexes
    do key over keys
      keyName = key~string
      allowedKey = keyName = "role"
      if \allowedKey then allowedKey = keyName = "content"
      if \allowedKey then allowedKey = keyName = "tool_calls"
      if \allowedKey then allowedKey = keyName = "tool_call_id"
      if \allowedKey then raise syntax 88.900 array("unsupported message field: " || keyName)
    end
    roleValue = item~at("role")
    if roleValue == .nil then raise syntax 88.900 array("message role missing")
    contentValue = item~at("content")
    if contentValue == .nil then contentValue = ""
    toolCallIdValue = item~at("tool_call_id")
    if toolCallIdValue == .nil then toolCallIdValue = ""
    toolCalls = self~decodeProviderToolCalls(item~at("tool_calls"))
    messages~append(.AIProviderMessage~new(roleValue, contentValue, toolCalls, toolCallIdValue))
  end
  return messages

::method decodeProviderToolCalls private
  use arg callsValue
  calls = .array~new
  if callsValue == .nil then return calls
  if \callsValue~isa(.Array) then raise syntax 88.900 array("message tool_calls must be Array")
  if callsValue~items > 64 then raise syntax 88.900 array("message tool call count exceeds package bound")
  do item over callsValue
    if \item~isa(.Directory) then raise syntax 88.900 array("message tool call must be JSON object")
    keys = item~allIndexes
    do key over keys
      keyName = key~string
      allowedKey = keyName = "call_id"
      if \allowedKey then allowedKey = keyName = "name"
      if \allowedKey then allowedKey = keyName = "arguments"
      if \allowedKey then raise syntax 88.900 array("unsupported message tool call field: " || keyName)
    end
    callIdValue = item~at("call_id")
    nameValue = item~at("name")
    argsValue = item~at("arguments")
    if callIdValue == .nil then raise syntax 88.900 array("message tool call id missing")
    if nameValue == .nil then raise syntax 88.900 array("message tool call name missing")
    if argsValue == .nil then argsValue = .directory~new
    calls~append(.AIProviderToolCall~new(callIdValue, nameValue, argsValue))
  end
  return calls

::method invocationFailure private
  use arg context, code, detail, stage = "WRAPPER"
  self~recordInvocationFailure(stage, code)
  return context~failure(code, detail)

::method recordInvocationFailure private
  expose invocationCount
  use arg stage, code
  ev = .directory~new
  ev["invocation"] = invocationCount
  ev["stage"] = stage~string~translate
  ev["code"] = code~string
  self~alchemyInstrument("AI.INVOCATION.FAIL", ev)
  return ev

::method meterUsage private
  use arg context, usage
  if usage == .nil then return .nil
  if \context~wluManaged then return .nil

  if usage~inputTokens > 0 then do
    meterOutcome = context~meterFact("AI_INPUT_TOKEN", usage~inputTokens, "ai-provider-input")
    if \meterOutcome~ok then return meterOutcome
  end
  if usage~outputTokens > 0 then do
    meterOutcome = context~meterFact("AI_OUTPUT_TOKEN", usage~outputTokens, "ai-provider-output")
    if \meterOutcome~ok then return meterOutcome
  end
  return .nil

::requires "AlchemyObject.cls"
