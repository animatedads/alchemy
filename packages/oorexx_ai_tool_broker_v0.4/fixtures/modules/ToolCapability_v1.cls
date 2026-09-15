::class ToolCapability public
::method init
  expose invocationCount
  invocationCount = 0
::method runtimeSelfTest
  return .true
::method runtimeInvocationCount
  expose invocationCount
  return invocationCount
::method runtimeInvokeAbility
  expose invocationCount
  use arg abilityId, context
  invocationCount = invocationCount + 1
  if abilityId <> "math.add" then return context~failure("TOOL_ABILITY_UNKNOWN", abilityId)
  if context~wluManaged then do
    meter = context~meterFact("TOOL_CALL", 1, "ai-tool-broker-fixture")
    if \meter~ok then return meter
  end
  body = context~body
  output = .directory~new
  output["sum"] = body~at("a") + body~at("b")
  output["generation"] = "TOOL-V1"
  output["invocation_count"] = invocationCount
  return context~success(output)
