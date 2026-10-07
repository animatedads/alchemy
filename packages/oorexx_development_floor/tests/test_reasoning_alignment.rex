::class FakeReasoningProvider public
::method complete
  use strict arg request
  return .AIProviderReply~success('{"score":0.23,"gaps":["stdout obligation not covered"]}', "qwen-fixture", "stop", .AIProviderUsage~new(17, 8))

provider = .FakeReasoningProvider~new
manager = .DFReasoningAlignmentManager~new(provider, .nil, 0.70)
outcome = manager~evaluate("W1", "use a sieve and satisfy exact stdout", "used a sieve", "qwen-fixture", 512)
call assertTrue outcome~ok, "evaluation should parse"
call assertEqual 0.23, outcome~score, "score"
call assertEqual "MISMATCH", outcome~verdict, "Floor threshold verdict"
call assertEqual 1, outcome~gaps~items, "gap count"
call assertEqual 17, outcome~inputTokens, "input tokens"
call assertEqual 8, outcome~outputTokens, "output tokens"
say "PASS reasoning alignment score is advisory management evidence"
exit 0

assertTrue: procedure
  use arg condition, label
  if condition then return
  say "FAIL" label
  exit 1

assertEqual: procedure
  use arg expected, actual, label
  if expected = actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::requires "ReasoningAlignmentManager.cls"
::requires "AIProviderAccess.cls"
