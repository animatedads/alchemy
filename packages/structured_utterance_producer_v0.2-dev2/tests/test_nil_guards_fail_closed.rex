/* Regression: nil-sensitive producer entry points fail closed without eager message sends. */
p = .StructuredUtteranceProducer~new
plan = .StructuredUtteranceGenerationPlan~new("PLAN-NIL-1", "UTT-NIL-1")

call assertFalse plan~addSegment(.nil), "nil segment rejected"
call assertFalse plan~addAct(.nil), "nil act rejected"
call assertFalse plan~addInformationUse(.nil), "nil information use rejected"
call assertFalse plan~addGenerationIntent(.nil), "nil generation intent rejected"

optional = .StructuredUtteranceProducerCanonical~controlledRef("", "OPTIONAL", .true)
call assertEqual "", optional, "empty optional reference accepted"

r = p~produce(.nil)
call assertFalse r~ok, "nil plan rejected"
call assertEqual "GENERATION_PLAN_REQUIRED", r~code, "nil plan failure code"

r = p~rejectFlattenedReply("flattened text", .nil)
call assertFalse r~ok, "flattened reply remains rejected with nil provider ref"
call assertEqual "FLATTENED_REPLY_INSUFFICIENT", r~code, "flattened reply failure code"

signal on syntax name expectedPayloadSyntax
ignored = .StructuredUtteranceProductionPayload~new(.nil)
signal off syntax
say "FAIL: nil payload constructor should raise controlled syntax"
exit 1

expectedPayloadSyntax:
say "EXPECTED SYNTAX RC=" rc "SIGL=" sigl "CONDITION=" condition("C") condition("D")
say "PASS test_nil_guards_fail_closed"
exit 0

assertFalse: procedure
  use arg value, label
  if value then do
    say "FAIL:" label
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "StructuredUtteranceProducer.cls"
