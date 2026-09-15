/* Qualification-only planner for the orchestrator's deterministic model.
 * Tool definitions are counted conservatively as two input-token units each
 * so the test proves model/tool offers participate in pre-admission work. */
::class OrchestratorModelWLUPlanner public
::method plan
  use arg session, descriptor, body
  prompt = body~at("prompt")
  maxOutputTokens = body~at("max_output_tokens")
  if prompt == .nil then return .RuntimeResult~failure("ORCH_MODEL_WLU_INVALID", "prompt missing")
  if maxOutputTokens == .nil then maxOutputTokens = 256
  if \datatype(maxOutputTokens, "W") then return .RuntimeResult~failure("ORCH_MODEL_WLU_INVALID", "max_output_tokens must be whole")
  promptText = prompt~string~strip
  if promptText = "" then inputEstimate = 0
  else inputEstimate = words(promptText)
  tools = body~at("tools")
  if tools \== .nil then do
    if \tools~isa(.Array) then return .RuntimeResult~failure("ORCH_MODEL_WLU_INVALID", "tools must be Array")
    inputEstimate = inputEstimate + (tools~items * 2)
  end
  messages = body~at("messages")
  if messages \== .nil then do
    if \messages~isa(.Array) then return .RuntimeResult~failure("ORCH_MODEL_WLU_INVALID", "messages must be Array")
    if prompt~string <> "" then return .RuntimeResult~failure("ORCH_MODEL_WLU_INVALID", "prompt content cannot be combined with messages")
    inputEstimate = inputEstimate + messages~items
  end
  facts = .array~new
  if inputEstimate > 0 then facts~append(.AbilityMeterFact~new("AI_INPUT_TOKEN", inputEstimate, "orchestrator-model-plan"))
  facts~append(.AbilityMeterFact~new("AI_OUTPUT_TOKEN", maxOutputTokens, "orchestrator-model-plan"))
  scope = "ABILITY:" || descriptor~abilityId~upper
  return .AbilityWLUPlan~new(scope, facts, .nil, 0, 30, "")
::requires "AbilityWLU.cls"
