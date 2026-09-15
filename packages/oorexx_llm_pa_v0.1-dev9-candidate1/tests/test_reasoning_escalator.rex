policy = .LlmPaExternalBudgetPolicy~new(3, 10000)
authority = .LlmPaExternalBudgetAuthority~new(policy, .TestEscalatorClock~new(1700000000000000))
ignore = authority~registerRate("test", "cheap-model", 10000, "test-1")
delegate = .TestEscalatorDelegate~new
escalator = .LlmPaReasoningEscalator~new(delegate, authority, "test", "cheap-model")

allowed = escalator~runOnce("cheap-model", "Hi", 1)
if \allowed~ok then exit 1
if delegate~calls \= 1 then exit 2

denied = escalator~runOnce("cheap-model", "This request must be refused before provider execution.", 100)
if denied~ok then exit 3
if denied~code \= "PA_WLU_HOURLY_CEILING" then exit 4
if delegate~calls \= 1 then exit 5
say "PASS test_reasoning_escalator"
exit 0

::class TestEscalatorClock public
::attribute value get
::method init
  expose value
  use arg valueArg
  value = valueArg
::method microseconds
  expose value
  return value

::class TestEscalatorDelegate public
::attribute calls get
::method init
  expose calls
  calls = 0
::method runOnce
  expose calls
  use arg modelArg, promptArg, maxTokensArg
  calls += 1
  return .LlmPaResult~success(.TestEscalatorReply~new("ok"))

::class TestEscalatorReply public
::attribute text get
::method init
  expose text
  use arg textArg
  text = textArg

::requires "LlmPaReasoningEscalator.cls"
