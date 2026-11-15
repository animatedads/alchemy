/* ooRexx AI Provider OpenAI-Compatible WLU admission v0.4
 *
 * Provider-specific conservative pre-admission planning for the generic
 * AbilityWLU bridge.  This source is optional: deployments which do not use
 * WLU do not load it and the main provider source has no AbilityWLU require.
 *
 * No tokenizer exactness is claimed.  The default estimator deliberately
 * budgets model-visible prompt/tool/message bytes conservatively plus framing
 * overhead.  A deployment may tighten or enlarge those bounds only through explicit
 * non-secret policy.  Actual provider-reported usage remains authoritative
 * for settlement.
 */

::class OpenAICompatWLUBuild public
::constant RELEASE "0.4"
::constant API_VERSION "ai.provider.openai-compat.wlu/0.4"
::constant PROVIDER_VERSION "0.5"
::constant WLU_VERSION "0.11"
::constant ALCHEMY_OBJECTS_VERSION "0.7"

/* Plain immutable non-secret estimation policy. */
::class OpenAICompatTokenBudgetPolicy public
::attribute inputTokensPerByte get
::attribute inputOverheadTokens get
::attribute targetSeconds get
::attribute ttlSeconds get

::method init
  expose inputTokensPerByte inputOverheadTokens targetSeconds ttlSeconds
  use arg inputMultiplierArg = 2, overheadArg = 512, targetArg = 0, ttlArg = 30
  inputTokensPerByte = inputMultiplierArg
  inputOverheadTokens = overheadArg
  targetSeconds = targetArg
  ttlSeconds = ttlArg
  if \datatype(inputTokensPerByte, "W") then raise syntax 88.900 array("OpenAI-compatible WLU input multiplier must be whole")
  if inputTokensPerByte < 1 then raise syntax 88.900 array("OpenAI-compatible WLU input multiplier must be positive")
  if inputTokensPerByte > 64 then raise syntax 88.900 array("OpenAI-compatible WLU input multiplier exceeds policy limit")
  if \datatype(inputOverheadTokens, "W") then raise syntax 88.900 array("OpenAI-compatible WLU input overhead must be whole")
  if inputOverheadTokens < 0 then raise syntax 88.900 array("OpenAI-compatible WLU input overhead must not be negative")
  if inputOverheadTokens > 1048576 then raise syntax 88.900 array("OpenAI-compatible WLU input overhead exceeds policy limit")
  if \datatype(targetSeconds, "W") then raise syntax 88.900 array("OpenAI-compatible WLU target seconds must be whole")
  if targetSeconds < 0 then raise syntax 88.900 array("OpenAI-compatible WLU target seconds must not be negative")
  if \datatype(ttlSeconds, "W") then raise syntax 88.900 array("OpenAI-compatible WLU TTL must be whole")
  if ttlSeconds < 1 then raise syntax 88.900 array("OpenAI-compatible WLU TTL must be positive")
  if ttlSeconds > 3600 then raise syntax 88.900 array("OpenAI-compatible WLU TTL exceeds policy limit")

::method fromEnvironment class
  multiplier = value("AI_OPENAI_COMPAT_WLU_INPUT_TOKENS_PER_BYTE",, "ENVIRONMENT")
  overhead = value("AI_OPENAI_COMPAT_WLU_INPUT_OVERHEAD_TOKENS",, "ENVIRONMENT")
  target = value("AI_OPENAI_COMPAT_WLU_TARGET_SECONDS",, "ENVIRONMENT")
  ttl = value("AI_OPENAI_COMPAT_WLU_TTL",, "ENVIRONMENT")
  if multiplier = "" then multiplier = 2
  if overhead = "" then overhead = 512
  if target = "" then target = 0
  if ttl = "" then ttl = 30
  return self~new(multiplier, overhead, target, ttl)


::class OpenAICompatConservativeTokenEstimator subclass AlchemyObject public

::method init
  expose budgetPolicy
  use arg policyArg = .nil
  if policyArg == .nil then policyArg = .OpenAICompatTokenBudgetPolicy~new
  if \policyArg~isa(.OpenAICompatTokenBudgetPolicy) then raise syntax 88.900 array("OpenAI-compatible token estimator requires OpenAICompatTokenBudgetPolicy")
  budgetPolicy = policyArg
  meta = .directory~new
  meta["purpose"] = "Conservative pre-admission input token budget for OpenAI-compatible providers"
  meta["package_version"] = .OpenAICompatWLUBuild~RELEASE
  meta["api_version"] = .OpenAICompatWLUBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerStateVariable("budgetPolicy", "INTERNAL", "non-secret token estimation bounds")
  self~registerMethodContract("ESTIMATEINPUTTOKENS", "estimate conservative input token reservation from prompt plus additional model-visible input bytes", .array~of("PROMPT", "ADDITIONALBYTES"), "NUMERIC", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("AI.WLU.ESTIMATE", "records prompt byte count and conservative token budget; never prompt contents", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .OpenAICompatWLUBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method estimateInputTokens public
  expose budgetPolicy
  use arg promptArg, additionalBytesArg = 0
  numeric digits 30
  if \datatype(additionalBytesArg, "W") then raise syntax 88.900 array("OpenAI-compatible additional input bytes must be whole")
  if additionalBytesArg < 0 then raise syntax 88.900 array("OpenAI-compatible additional input bytes must not be negative")
  promptBytes = promptArg~string~length
  inputBytes = promptBytes + additionalBytesArg
  estimated = inputBytes * budgetPolicy~inputTokensPerByte + budgetPolicy~inputOverheadTokens
  event = .directory~new
  event["prompt_bytes"] = promptBytes
  event["additional_model_input_bytes"] = additionalBytesArg
  event["input_bytes"] = inputBytes
  event["estimated_input_tokens"] = estimated
  event["input_tokens_per_byte"] = budgetPolicy~inputTokensPerByte
  event["input_overhead_tokens"] = budgetPolicy~inputOverheadTokens
  self~alchemyInstrument("AI.WLU.ESTIMATE", event)
  return estimated


::class OpenAICompatWLUPlanner subclass AlchemyObject public

::method init
  expose modelPolicy estimator budgetPolicy
  use arg modelPolicyArg, estimatorArg = .nil, budgetPolicyArg = .nil
  if modelPolicyArg == .nil then raise syntax 88.900 array("OpenAI-compatible WLU planner requires model policy")
  if \modelPolicyArg~isa(.OpenAICompatModelPolicy) then raise syntax 88.900 array("OpenAI-compatible WLU planner model policy invalid")
  if budgetPolicyArg == .nil then budgetPolicyArg = .OpenAICompatTokenBudgetPolicy~new
  if \budgetPolicyArg~isa(.OpenAICompatTokenBudgetPolicy) then raise syntax 88.900 array("OpenAI-compatible WLU planner budget policy invalid")
  if estimatorArg == .nil then estimatorArg = .OpenAICompatConservativeTokenEstimator~new(budgetPolicyArg)
  if \estimatorArg~hasMethod("ESTIMATEINPUTTOKENS") then raise syntax 88.900 array("OpenAI-compatible WLU planner estimator contract invalid")
  modelPolicy = modelPolicyArg
  estimator = estimatorArg
  budgetPolicy = budgetPolicyArg
  meta = .directory~new
  meta["purpose"] = "Provider-specific WLU pre-admission planner for OpenAI-compatible model completion"
  meta["package_version"] = .OpenAICompatWLUBuild~RELEASE
  meta["api_version"] = .OpenAICompatWLUBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerStateVariable("modelPolicy", "INTERNAL", "model allowlist and output-token cap only")
  self~registerStateVariable("estimator", "INTERNAL", "conservative token estimator")
  self~registerStateVariable("budgetPolicy", "INTERNAL", "non-secret WLU estimation bounds")
  self~registerMethodContract("PLAN", "construct provider-specific WLU plan before Runtime Registry dynamic invocation", .array~of("SESSION", "DESCRIPTOR", "BODY"), "ANY", .false, "AUTO", "INTERNAL", "SECURITY_BOUNDARY", "READ", "NONE")
  self~registerInstrumentationPoint("AI.WLU.PLAN", "records model and numeric reservation metadata without prompt contents or credentials", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "oorexx_work_load_units", "v" || .OpenAICompatWLUBuild~WLU_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_ai_provider_openai_compat", "v" || .OpenAICompatWLUBuild~PROVIDER_VERSION, .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .OpenAICompatWLUBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method fromEnvironment class
  modelPolicy = .OpenAICompatModelPolicy~fromEnvironment
  budgetPolicy = .OpenAICompatTokenBudgetPolicy~fromEnvironment
  estimator = .OpenAICompatConservativeTokenEstimator~new(budgetPolicy)
  return self~new(modelPolicy, estimator, budgetPolicy)

::method plan public
  expose modelPolicy estimator budgetPolicy
  use arg session, descriptor, body
  if body == .nil then return .RuntimeResult~failure("AI_REQUEST_INVALID", "request body missing")
  if \body~isa(.Directory) then return .RuntimeResult~failure("AI_REQUEST_INVALID", "request body must be Directory")
  modelValue = body~at("model")
  promptValue = body~at("prompt")
  maxOutputValue = body~at("max_output_tokens")
  if modelValue == .nil then return .RuntimeResult~failure("AI_REQUEST_INVALID", "model missing")
  if promptValue == .nil then return .RuntimeResult~failure("AI_REQUEST_INVALID", "prompt missing")
  if maxOutputValue == .nil then maxOutputValue = 256
  model = modelValue~string~strip
  if \modelPolicy~allowsModel(model) then return .RuntimeResult~failure("AI_PROVIDER_MODEL_NOT_ALLOWED", "requested model is not enabled for this deployment")
  if \datatype(maxOutputValue~string, "W") then return .RuntimeResult~failure("AI_REQUEST_INVALID", "max_output_tokens must be whole")
  maxOutputTokens = maxOutputValue~string
  if maxOutputTokens < 1 then return .RuntimeResult~failure("AI_REQUEST_INVALID", "max_output_tokens must be positive")
  if maxOutputTokens > modelPolicy~maxOutputTokensLimit then return .RuntimeResult~failure("AI_PROVIDER_OUTPUT_LIMIT", "requested output token limit exceeds deployment policy")

  toolsValue = body~at("tools")
  toolDefinitionCount = 0
  toolInputBytes = 0
  if toolsValue \== .nil then do
    if \toolsValue~isa(.Array) then return .RuntimeResult~failure("AI_REQUEST_INVALID", "tools must be Array")
    toolDefinitionCount = toolsValue~items
    toolInputBytes = .JSON~toJSON(toolsValue)~length
  end

  messagesValue = body~at("messages")
  messageCount = 0
  messageToolCallCount = 0
  messageInputBytes = 0
  messageWireOverheadBytes = 0
  if messagesValue \== .nil then do
    if \messagesValue~isa(.Array) then return .RuntimeResult~failure("AI_REQUEST_INVALID", "messages must be Array")
    if promptValue~string <> "" then return .RuntimeResult~failure("AI_REQUEST_INVALID", "prompt content cannot be combined with structured messages")
    messageCount = messagesValue~items
    messageInputBytes = .JSON~toJSON(messagesValue)~length
    do messageValue over messagesValue
      if messageValue~isa(.Directory) then do
        callsValue = messageValue~at("tool_calls")
        if callsValue \== .nil then do
          if callsValue~isa(.Array) then messageToolCallCount = messageToolCallCount + callsValue~items
        end
      end
    end
    /* Conservative allowance for OpenAI-compatible role/tool_call_id and
     * assistant function wrapper expansion.  Contents are never logged. */
    messageWireOverheadBytes = messageCount * 64 + messageToolCallCount * 96
  end
  additionalInputBytes = toolInputBytes + messageInputBytes + messageWireOverheadBytes
  inputEstimate = estimator~estimateInputTokens(promptValue, additionalInputBytes)
  planned = .array~new
  if inputEstimate > 0 then planned~append(.AbilityMeterFact~new("AI_INPUT_TOKEN", inputEstimate, "openai-compat-conservative-plan"))
  planned~append(.AbilityMeterFact~new("AI_OUTPUT_TOKEN", maxOutputTokens, "openai-compat-max-output-plan"))
  scope = "ABILITY:" || descriptor~abilityId~string~strip~upper

  event = .directory~new
  event["model"] = model
  event["estimated_input_tokens"] = inputEstimate
  event["max_output_tokens"] = maxOutputTokens
  event["tool_definition_count"] = toolDefinitionCount
  event["tool_input_bytes"] = toolInputBytes
  event["message_count"] = messageCount
  event["message_tool_call_count"] = messageToolCallCount
  event["message_input_bytes"] = messageInputBytes
  event["message_wire_overhead_bytes"] = messageWireOverheadBytes
  event["planned_fact_count"] = planned~items
  self~alchemyInstrument("AI.WLU.PLAN", event)
  return .RuntimeResult~success(.AbilityWLUPlan~new(scope, planned, .nil, budgetPolicy~targetSeconds, budgetPolicy~ttlSeconds, ""))

::requires "OpenAICompatProvider.cls"
::requires "AbilityWLU.cls"
::requires "AlchemyObject.cls"
::requires "json.cls"
