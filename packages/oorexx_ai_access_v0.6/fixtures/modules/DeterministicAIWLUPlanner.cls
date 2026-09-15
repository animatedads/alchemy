/* Qualification-only WLU planner for the deterministic AI provider fixture.
 * Real provider packages must supply their own conservative provider/model
 * planner.  This fixture deliberately uses the same lexical accounting model
 * as DeterministicAIProvider_v1.cls so the test can prove admission ordering.
 */
::class DeterministicAIWLUPlanner public
::method plan
  use arg session, descriptor, body
  if body == .nil then return .RuntimeResult~failure("AI_WLU_PLAN_INVALID", "request body missing")
  prompt = body~at("prompt")
  maxOutputTokens = body~at("max_output_tokens")
  if prompt == .nil then return .RuntimeResult~failure("AI_WLU_PLAN_INVALID", "prompt missing")
  if maxOutputTokens == .nil then maxOutputTokens = 256
  if \datatype(maxOutputTokens, "W") then return .RuntimeResult~failure("AI_WLU_PLAN_INVALID", "max_output_tokens must be whole")
  if maxOutputTokens < 1 then return .RuntimeResult~failure("AI_WLU_PLAN_INVALID", "max_output_tokens must be positive")

  promptText = prompt~string~strip
  if promptText = "" then inputEstimate = 0
  else inputEstimate = words(promptText)
  planned = .array~new
  if inputEstimate > 0 then planned~append(.AbilityMeterFact~new("AI_INPUT_TOKEN", inputEstimate, "deterministic-ai-plan"))
  planned~append(.AbilityMeterFact~new("AI_OUTPUT_TOKEN", maxOutputTokens, "deterministic-ai-plan"))
  scope = "ABILITY:" || descriptor~abilityId~upper
  return .RuntimeResult~success(.AbilityWLUPlan~new(scope, planned, .nil, 0, 30, ""))

::requires "AbilityWLU.cls"
