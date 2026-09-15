/* ooRexx AI Provider Grok (xAI) WLU admission v0.4
 *
 * Provider-specific conservative pre-admission planning for the generic
 * AbilityWLU bridge.  This source is optional: deployments which do not use
 * WLU do not load it and the main provider source has no AbilityWLU require.
 *
 * No tokenizer exactness is claimed.  The default estimator deliberately
 * budgets two input tokens per prompt byte plus 512 framing tokens.  A
 * deployment may tighten or enlarge those bounds only through explicit
 * non-secret policy.  Actual provider-reported usage remains authoritative
 * for settlement.
 */

::class GrokWLUBuild public
::constant RELEASE "0.4"
::constant API_VERSION "ai.provider.grok.wlu/0.3"
::constant PROVIDER_VERSION "0.4"
::constant WLU_VERSION "0.12"
::constant ALCHEMY_OBJECTS_VERSION "0.8"

/* Plain immutable non-secret estimation policy. */
::class GrokTokenBudgetPolicy public
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
  if \datatype(inputTokensPerByte, "W") then raise syntax 88.900 array("Grok WLU input multiplier must be whole")
  if inputTokensPerByte < 1 then raise syntax 88.900 array("Grok WLU input multiplier must be positive")
  if inputTokensPerByte > 64 then raise syntax 88.900 array("Grok WLU input multiplier exceeds policy limit")
  if \datatype(inputOverheadTokens, "W") then raise syntax 88.900 array("Grok WLU input overhead must be whole")
  if inputOverheadTokens < 0 then raise syntax 88.900 array("Grok WLU input overhead must not be negative")
  if inputOverheadTokens > 1048576 then raise syntax 88.900 array("Grok WLU input overhead exceeds policy limit")
  if \datatype(targetSeconds, "W") then raise syntax 88.900 array("Grok WLU target seconds must be whole")
  if targetSeconds < 0 then raise syntax 88.900 array("Grok WLU target seconds must not be negative")
  if \datatype(ttlSeconds, "W") then raise syntax 88.900 array("Grok WLU TTL must be whole")
  if ttlSeconds < 1 then raise syntax 88.900 array("Grok WLU TTL must be positive")
  if ttlSeconds > 3600 then raise syntax 88.900 array("Grok WLU TTL exceeds policy limit")

::method fromEnvironment class
  multiplier = value("AI_GROK_WLU_INPUT_TOKENS_PER_BYTE",, "ENVIRONMENT")
  overhead = value("AI_GROK_WLU_INPUT_OVERHEAD_TOKENS",, "ENVIRONMENT")
  target = value("AI_GROK_WLU_TARGET_SECONDS",, "ENVIRONMENT")
  ttl = value("AI_GROK_WLU_TTL",, "ENVIRONMENT")
  if multiplier = "" then multiplier = 2
  if overhead = "" then overhead = 512
  if target = "" then target = 0
  if ttl = "" then ttl = 30
  return self~new(multiplier, overhead, target, ttl)


::class GrokConservativeTokenEstimator subclass AlchemyObject public

::method init
  expose budgetPolicy
  use arg policyArg = .nil
  if policyArg == .nil then policyArg = .GrokTokenBudgetPolicy~new
  if \policyArg~isa(.GrokTokenBudgetPolicy) then raise syntax 88.900 array("Grok token estimator requires GrokTokenBudgetPolicy")
  budgetPolicy = policyArg
  meta = .directory~new
  meta["purpose"] = "Conservative pre-admission input token budget for Grok providers"
  meta["package"] = "oorexx_ai_provider_grok"
  meta["package_version"] = .GrokWLUBuild~RELEASE
  meta["api_version"] = .GrokWLUBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.grok.wlu/0.3; work.load.units/0.12 planning boundary"
  meta["design_limitations"] = "Estimator is deliberately conservative and tokenizer-inexact; it emits numeric planning evidence only and cannot reserve, settle or grant WLU"
  self~init:super(meta)
  self~registerStateVariable("budgetPolicy", "INTERNAL", "non-secret token estimation bounds")
  self~registerMethodContract("ESTIMATEINPUTTOKENS", "estimate conservative input token reservation from prompt byte length", .array~of("PROMPT"), "NUMERIC", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("AI.WLU.ESTIMATE", "records prompt byte count and conservative token budget; never prompt contents", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .GrokWLUBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method estimateInputTokens public
  expose budgetPolicy
  use arg promptArg
  numeric digits 30
  promptBytes = promptArg~string~length
  estimated = promptBytes * budgetPolicy~inputTokensPerByte + budgetPolicy~inputOverheadTokens
  event = .directory~new
  event["prompt_bytes"] = promptBytes
  event["estimated_input_tokens"] = estimated
  event["input_tokens_per_byte"] = budgetPolicy~inputTokensPerByte
  event["input_overhead_tokens"] = budgetPolicy~inputOverheadTokens
  self~alchemyInstrument("AI.WLU.ESTIMATE", event)
  return estimated


::class GrokWLUPlanner subclass AlchemyObject public

::method init
  expose modelPolicy estimator budgetPolicy
  use arg modelPolicyArg, estimatorArg = .nil, budgetPolicyArg = .nil
  if modelPolicyArg == .nil then raise syntax 88.900 array("Grok WLU planner requires model policy")
  if \modelPolicyArg~isa(.GrokModelPolicy) then raise syntax 88.900 array("Grok WLU planner model policy invalid")
  if budgetPolicyArg == .nil then budgetPolicyArg = .GrokTokenBudgetPolicy~new
  if \budgetPolicyArg~isa(.GrokTokenBudgetPolicy) then raise syntax 88.900 array("Grok WLU planner budget policy invalid")
  if estimatorArg == .nil then estimatorArg = .GrokConservativeTokenEstimator~new(budgetPolicyArg)
  if \estimatorArg~hasMethod("ESTIMATEINPUTTOKENS") then raise syntax 88.900 array("Grok WLU planner estimator contract invalid")
  modelPolicy = modelPolicyArg
  estimator = estimatorArg
  budgetPolicy = budgetPolicyArg
  meta = .directory~new
  meta["purpose"] = "Provider-specific WLU pre-admission planner for Grok model completion"
  meta["package"] = "oorexx_ai_provider_grok"
  meta["package_version"] = .GrokWLUBuild~RELEASE
  meta["api_version"] = .GrokWLUBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.grok.wlu/0.3; work.load.units/0.12 provider-neutral AbilityWLUPlan boundary"
  meta["design_limitations"] = "Planner constructs conservative AbilityWLUPlan evidence only; WLU authority owns valuation/admission/settlement and provider invocation remains outside this object"
  self~init:super(meta)
  self~registerStateVariable("modelPolicy", "INTERNAL", "model allowlist and output-token cap only")
  self~registerStateVariable("estimator", "INTERNAL", "conservative token estimator")
  self~registerStateVariable("budgetPolicy", "INTERNAL", "non-secret WLU estimation bounds")
  self~registerMethodContract("PLAN", "construct provider-specific WLU plan before Runtime Registry dynamic invocation", .array~of("SESSION", "DESCRIPTOR", "BODY"), "ANY", .true, "AUTO", "INTERNAL", "SECURITY_BOUNDARY", "READ", "NONE")
  self~registerInstrumentationPoint("AI.WLU.PLAN", "records model and numeric reservation metadata without prompt contents or credentials", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "oorexx_work_load_units", "v" || .GrokWLUBuild~WLU_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_ai_provider_grok", "v" || .GrokWLUBuild~PROVIDER_VERSION, .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .GrokWLUBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method fromEnvironment class
  modelPolicy = .GrokModelPolicy~fromEnvironment
  budgetPolicy = .GrokTokenBudgetPolicy~fromEnvironment
  estimator = .GrokConservativeTokenEstimator~new(budgetPolicy)
  return self~new(modelPolicy, estimator, budgetPolicy)

::method plan public protected
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

  inputEstimate = estimator~estimateInputTokens(promptValue)
  planned = .array~new
  if inputEstimate > 0 then planned~append(.AbilityMeterFact~new("AI_INPUT_TOKEN", inputEstimate, "grok-conservative-plan"))
  planned~append(.AbilityMeterFact~new("AI_OUTPUT_TOKEN", maxOutputTokens, "grok-max-output-plan"))
  scope = "ABILITY:" || descriptor~abilityId~string~strip~upper

  event = .directory~new
  event["model"] = model
  event["estimated_input_tokens"] = inputEstimate
  event["max_output_tokens"] = maxOutputTokens
  event["planned_fact_count"] = planned~items
  self~alchemyInstrument("AI.WLU.PLAN", event)
  return .RuntimeResult~success(.AbilityWLUPlan~new(scope, planned, .nil, budgetPolicy~targetSeconds, budgetPolicy~ttlSeconds, ""))

::requires "GrokProvider.cls"
::requires "AbilityWLU.cls"
::requires "AlchemyObject.cls"
