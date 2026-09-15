/* ooRexx AI Provider Grok (xAI) Batch WLU admission v0.4
 *
 * Batch work is a different workload class from real-time completion:
 *
 *   Real-time (GrokWLU):
 *     - short targetSeconds / TTL (seconds)
 *     - high expected delivery rate
 *     - facts: AI_INPUT_TOKEN, AI_OUTPUT_TOKEN
 *     - settlement immediately after the single completion
 *
 *   Batch (this unit):
 *     - long targetSeconds / TTL (default 24 h = 86400 s)
 *     - deliberately low requested delivery rate (work is deferred)
 *     - distinct fact types so rate-cards can price batch work differently:
 *         AI_BATCH_REQUEST          (count of requests being admitted)
 *         AI_BATCH_INPUT_TOKEN      (conservative estimate of total input)
 *         AI_BATCH_OUTPUT_TOKEN     (planned max output across the add)
 *     - admission happens at submit / add-requests time
 *     - settlement is expected later when results are retrieved or the
 *       batch reaches terminal state (num_pending = 0)
 *
 * No endpoint, credential, Secret Broker or transport authority is present
 * in the planner.  Model / size / request-count policy is non-secret and
 * shared with GrokBatchModelPolicy.
 */

::class GrokBatchWLUBuild public
::constant RELEASE "0.4"
::constant API_VERSION "ai.provider.grok.batch.wlu/0.3"
::constant PROVIDER_VERSION "0.4"
::constant WLU_VERSION "0.12"
::constant ALCHEMY_OBJECTS_VERSION "0.8"

/* Long-horizon non-secret estimation policy for batch work. */
::class GrokBatchTokenBudgetPolicy public
::attribute inputTokensPerByte get
::attribute inputOverheadTokens get
::attribute targetSeconds get
::attribute ttlSeconds get
::attribute requestedRateMicroWluPerSecond get

::method init
  expose inputTokensPerByte inputOverheadTokens targetSeconds ttlSeconds requestedRateMicroWluPerSecond
  /* Defaults: conservative 2 tokens/byte + 512 framing; 24h horizon; low rate. */
  use arg inputMultiplierArg = 2, overheadArg = 512, targetArg = 86400, ttlArg = 90000, rateArg = 0
  inputTokensPerByte = inputMultiplierArg
  inputOverheadTokens = overheadArg
  targetSeconds = targetArg
  ttlSeconds = ttlArg
  requestedRateMicroWluPerSecond = rateArg
  if \datatype(inputTokensPerByte, "W") then raise syntax 88.900 array("Grok batch WLU input multiplier must be whole")
  if inputTokensPerByte < 1 then raise syntax 88.900 array("Grok batch WLU input multiplier must be positive")
  if inputTokensPerByte > 64 then raise syntax 88.900 array("Grok batch WLU input multiplier exceeds policy limit")
  if \datatype(inputOverheadTokens, "W") then raise syntax 88.900 array("Grok batch WLU input overhead must be whole")
  if inputOverheadTokens < 0 then raise syntax 88.900 array("Grok batch WLU input overhead must not be negative")
  if inputOverheadTokens > 1048576 then raise syntax 88.900 array("Grok batch WLU input overhead exceeds policy limit")
  if \datatype(targetSeconds, "W") then raise syntax 88.900 array("Grok batch WLU target seconds must be whole")
  if targetSeconds < 0 then raise syntax 88.900 array("Grok batch WLU target seconds must not be negative")
  if targetSeconds > 604800 then raise syntax 88.900 array("Grok batch WLU target exceeds 7-day policy limit")
  if \datatype(ttlSeconds, "W") then raise syntax 88.900 array("Grok batch WLU TTL must be whole")
  if ttlSeconds < 1 then raise syntax 88.900 array("Grok batch WLU TTL must be positive")
  /* Allow up to 7 days + small margin for batch TTL. */
  if ttlSeconds > 700000 then raise syntax 88.900 array("Grok batch WLU TTL exceeds policy limit")
  if \datatype(requestedRateMicroWluPerSecond, "W") then raise syntax 88.900 array("Grok batch WLU rate must be whole")
  if requestedRateMicroWluPerSecond < 0 then raise syntax 88.900 array("Grok batch WLU rate must not be negative")

::method fromEnvironment class
  multiplier = value("AI_GROK_BATCH_WLU_INPUT_TOKENS_PER_BYTE",, "ENVIRONMENT")
  overhead = value("AI_GROK_BATCH_WLU_INPUT_OVERHEAD_TOKENS",, "ENVIRONMENT")
  target = value("AI_GROK_BATCH_WLU_TARGET_SECONDS",, "ENVIRONMENT")
  ttl = value("AI_GROK_BATCH_WLU_TTL",, "ENVIRONMENT")
  rate = value("AI_GROK_BATCH_WLU_RATE_MICRO_PER_SEC",, "ENVIRONMENT")
  if multiplier = "" then multiplier = 2
  if overhead = "" then overhead = 512
  if target = "" then target = 86400
  if ttl = "" then ttl = 90000
  if rate = "" then rate = 0
  return self~new(multiplier, overhead, target, ttl, rate)


::class GrokBatchConservativeTokenEstimator subclass AlchemyObject public

::method init
  expose budgetPolicy
  use arg budgetPolicyArg
  if \budgetPolicyArg~isa(.GrokBatchTokenBudgetPolicy) then raise syntax 88.900 array("Grok batch estimator requires GrokBatchTokenBudgetPolicy")
  budgetPolicy = budgetPolicyArg
  meta = .directory~new
  meta["purpose"] = "Conservative token estimator for Grok batch WLU admission"
  meta["package"] = "oorexx_ai_provider_grok"
  meta["package_version"] = .GrokBatchWLUBuild~RELEASE
  meta["api_version"] = .GrokBatchWLUBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.grok.batch.wlu/0.3; work.load.units/0.12 planning boundary"
  meta["design_limitations"] = "Estimator is deliberately conservative and tokenizer-inexact; it has no WLU reservation/settlement or provider execution authority"
  self~init:super(meta)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .GrokBatchWLUBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method estimateInputTokens
  expose budgetPolicy
  use arg promptArg
  prompt = promptArg~string
  /* Deliberately not tokenizer-exact.  Same conservative formula as real-time. */
  estimate = prompt~length * budgetPolicy~inputTokensPerByte + budgetPolicy~inputOverheadTokens
  if estimate < 1 then estimate = 1
  return estimate


/* Planner for batch submit / add-requests.
 * Receives only session/descriptor/body and non-secret policy objects.
 * Produces AbilityWLUPlan with long TTL and batch-specific facts. */
::class GrokBatchWLUPlanner subclass AlchemyObject public

::method init
  expose modelPolicy estimator budgetPolicy
  use arg modelPolicyArg, estimatorArg, budgetPolicyArg
  if \modelPolicyArg~isa(.GrokBatchModelPolicy) then raise syntax 88.900 array("Grok batch WLU planner requires GrokBatchModelPolicy")
  if \estimatorArg~isa(.GrokBatchConservativeTokenEstimator) then raise syntax 88.900 array("Grok batch WLU planner requires estimator")
  if \budgetPolicyArg~isa(.GrokBatchTokenBudgetPolicy) then raise syntax 88.900 array("Grok batch WLU planner requires budget policy")
  modelPolicy = modelPolicyArg
  estimator = estimatorArg
  budgetPolicy = budgetPolicyArg
  meta = .directory~new
  meta["purpose"] = "Pre-admission WLU planner for Grok batch operations"
  meta["package"] = "oorexx_ai_provider_grok"
  meta["package_version"] = .GrokBatchWLUBuild~RELEASE
  meta["api_version"] = .GrokBatchWLUBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.grok.batch.wlu/0.3; work.load.units/0.12 provider-neutral AbilityWLUPlan boundary"
  meta["design_limitations"] = "Planner produces conservative batch planning facts only; Runtime Registry/WLU own admission and settlement and this object never receives provider credentials"
  self~init:super(meta)
  self~registerExternalRequirement("library", "oorexx_work_load_units", "v" || .GrokBatchWLUBuild~WLU_VERSION, .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .GrokBatchWLUBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)
  self~registerInstrumentationPoint("AI.BATCH.WLU.PLAN", "batch WLU plan produced; counts and estimates only", .true, "ALL", "INTERNAL")

::method fromEnvironment class
  modelPolicy = .GrokBatchModelPolicy~fromEnvironment
  budgetPolicy = .GrokBatchTokenBudgetPolicy~fromEnvironment
  estimator = .GrokBatchConservativeTokenEstimator~new(budgetPolicy)
  return self~new(modelPolicy, estimator, budgetPolicy)

/* Plan admission for an "add requests" style body.
 *
 * Expected body shape (Directory):
 *   batch_id          (optional for create-only plans)
 *   requests          Array of Directory items each with:
 *                       model, prompt, max_output_tokens [, batch_request_id]
 *
 * Returns RuntimeResult success(AbilityWLUPlan) or failure.
 */
::method planAddRequests public
  expose modelPolicy estimator budgetPolicy
  use arg session, descriptor, body
  if body == .nil then return .RuntimeResult~failure("AI_BATCH_REQUEST_INVALID", "request body missing")
  if \body~isa(.Directory) then return .RuntimeResult~failure("AI_BATCH_REQUEST_INVALID", "request body must be Directory")

  requests = body~at("requests")
  if requests == .nil then requests = body~at("batch_requests")
  if requests == .nil | \requests~isa(.Array) then ,
    return .RuntimeResult~failure("AI_BATCH_REQUEST_INVALID", "requests / batch_requests array required")
  if requests~items = 0 then return .RuntimeResult~failure("AI_BATCH_REQUESTS_EMPTY", "at least one request required")
  if requests~items > modelPolicy~maxRequestsPerAdd then ,
    return .RuntimeResult~failure("AI_BATCH_REQUESTS_LIMIT", "request count exceeds deployment max_requests_per_add")

  totalInput = 0
  totalOutput = 0
  requestCount = 0
  do item over requests
    if \item~isa(.Directory) then return .RuntimeResult~failure("AI_BATCH_REQUEST_INVALID", "each request must be Directory")
    modelValue = item~at("model")
    promptValue = item~at("prompt")
    maxOutputValue = item~at("max_output_tokens")
    if modelValue == .nil then return .RuntimeResult~failure("AI_BATCH_REQUEST_INVALID", "model missing on request")
    if promptValue == .nil then return .RuntimeResult~failure("AI_BATCH_REQUEST_INVALID", "prompt missing on request")
    if maxOutputValue == .nil then maxOutputValue = 256
    model = modelValue~string~strip
    if \modelPolicy~allowsModel(model) then ,
      return .RuntimeResult~failure("AI_PROVIDER_MODEL_NOT_ALLOWED", "requested model is not enabled for batch: " || model)
    if \datatype(maxOutputValue~string, "W") then ,
      return .RuntimeResult~failure("AI_BATCH_REQUEST_INVALID", "max_output_tokens must be whole")
    maxOutputTokens = maxOutputValue~string
    if maxOutputTokens < 1 then return .RuntimeResult~failure("AI_BATCH_REQUEST_INVALID", "max_output_tokens must be positive")
    if maxOutputTokens > modelPolicy~maxOutputTokensLimit then ,
      return .RuntimeResult~failure("AI_PROVIDER_OUTPUT_LIMIT", "requested output token limit exceeds batch policy")

    inputEst = estimator~estimateInputTokens(promptValue)
    if inputEst > modelPolicy~maxEstimatedInputTokensPerRequest then ,
      return .RuntimeResult~failure("AI_BATCH_INPUT_ESTIMATE_LIMIT", "estimated input tokens exceed per-request policy")

    totalInput = totalInput + inputEst
    totalOutput = totalOutput + maxOutputTokens
    requestCount = requestCount + 1
  end

  planned = .array~new
  planned~append(.AbilityMeterFact~new("AI_BATCH_REQUEST", requestCount, "grok-batch-plan"))
  if totalInput > 0 then planned~append(.AbilityMeterFact~new("AI_BATCH_INPUT_TOKEN", totalInput, "grok-batch-conservative-plan"))
  if totalOutput > 0 then planned~append(.AbilityMeterFact~new("AI_BATCH_OUTPUT_TOKEN", totalOutput, "grok-batch-max-output-plan"))

  scope = "ABILITY:" || descriptor~abilityId~string~strip~upper
  if body~at("batch_id") \== .nil then scope = scope || ":BATCH:" || body~at("batch_id")~string~strip~upper

  event = .directory~new
  event["request_count"] = requestCount
  event["estimated_input_tokens"] = totalInput
  event["planned_output_tokens"] = totalOutput
  event["target_seconds"] = budgetPolicy~targetSeconds
  event["ttl_seconds"] = budgetPolicy~ttlSeconds
  event["requested_rate_micro_wlu_per_sec"] = budgetPolicy~requestedRateMicroWluPerSecond
  event["planned_fact_count"] = planned~items
  self~alchemyInstrument("AI.BATCH.WLU.PLAN", event)

  /* Long TTL, long target, intentionally low (or zero) delivery rate.
   * Batch work is capacity that is reserved for deferred execution, not
   * for immediate high-rate consumption of real-time pools. */
  return .RuntimeResult~success(.AbilityWLUPlan~new(scope, planned, .nil, ,
    budgetPolicy~targetSeconds, budgetPolicy~ttlSeconds, ""))

/* Convenience plan for pure create-batch (no requests yet).
 * Reserves a minimal AI_BATCH_REQUEST fact of quantity 0 or 1 depending
 * on deployment preference; default is a single lightweight fact so the
 * create itself is still metered without claiming inference work. */
::method planCreateBatch public
  expose budgetPolicy
  use arg session, descriptor, body
  planned = .array~new
  planned~append(.AbilityMeterFact~new("AI_BATCH_CREATE", 1, "grok-batch-create-plan"))
  scope = "ABILITY:" || descriptor~abilityId~string~strip~upper
  event = .directory~new
  event["operation"] = "createBatch"
  event["target_seconds"] = budgetPolicy~targetSeconds
  event["ttl_seconds"] = budgetPolicy~ttlSeconds
  self~alchemyInstrument("AI.BATCH.WLU.PLAN", event)
  return .RuntimeResult~success(.AbilityWLUPlan~new(scope, planned, .nil, ,
    budgetPolicy~targetSeconds, budgetPolicy~ttlSeconds, ""))

::requires "GrokBatchProvider.cls"
::requires "AbilityWLU.cls"
::requires "AlchemyObject.cls"
