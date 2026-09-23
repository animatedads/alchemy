/* Budget boundary for external reasoning. */

::class LlmPaReasoningEscalator public
::attribute provider get
::attribute model get

::method init
  expose delegate authority provider model
  use arg delegateArg, authorityArg, providerArg, modelArg
  delegate = delegateArg
  authority = authorityArg
  provider = providerArg~string~strip~lower
  model = modelArg~string~strip
  if delegate == .nil | authority == .nil | provider = "" | model = "" then raise syntax 88.900 array("reasoning escalator configuration is incomplete")

::method runOnce public
  expose delegate authority provider model
  use arg requestedModel = "", prompt, maxOutputTokens = 512
  requested = requestedModel~string~strip
  if requested <> "" & \requested~caselessEquals(model) then return .LlmPaResult~failure("PA_ESCALATOR_MODEL_MISMATCH", requested)
  estimate = self~estimateMicroWlu(prompt, maxOutputTokens)
  reserved = authority~reserve(provider, model, estimate, "pa-escalation")
  if \reserved~ok then return .LlmPaResult~failure(reserved~code, reserved~detail)
  reservation = reserved~value
  called = delegate~runOnce(model, prompt, maxOutputTokens)
  if \called~ok then do
    ignore = authority~release(reservation["reservation_id"])
    return called
  end
  actual = self~estimateMicroWlu(called~value~text, 0)
  settled = authority~settle(reservation["reservation_id"], actual)
  if settled~ok then return called
  return .LlmPaResult~failure("PA_ESCALATOR_SETTLEMENT_FAILED", settled~code || ":" || settled~detail)

::method estimateMicroWlu private
  use arg textArg, outputTokensArg
  inputTokens = .WLUUnits~ceilDivide(textArg~string~length, 4)
  return (inputTokens + outputTokensArg + 0) * 1000000

::requires "LlmPaBudgetAuthority.cls"
::requires "LlmPaCore.cls"
::requires "WorkLoadUnits.cls"
