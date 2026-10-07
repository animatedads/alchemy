parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 50, 5, .false, .false))
formatReg = service~register("format device", "FORMAT", "TEST")
formatReg~requireSlot("DEVICE", "Which device?", .true)
service~register("list customers", "LIST", "TEST")

d = service~input("format device")
call assertEq "CLARIFY", d~status, "format needs device"
call assertEq "Which device?", d~question, "pending question"

d = service~input("NEW REQUEST list customers")
call assertEq "READY", d~status, "new request escapes pending clarification"
call assertEq "LIST_CUSTOMERS", d~proposal~intentionId, "replacement intention selected"

/* Explicit cancellation leaves no hidden clarification state. */
d = service~input("format device")
call assertEq "CLARIFY", d~status, "second pending clarification"
d = service~input("cancel")
call assertEq "UNKNOWN", d~status, "cancel acknowledges no active meaning"
d = service~input("list customers")
call assertEq "READY", d~status, "ordinary request after cancel is fresh"

/* Programmatic callers do not need to manufacture textual control phrases. */
d = service~input("format device")
call assertEq "CLARIFY", d~status, "third pending clarification"
d = service~inputNew("list customers")
call assertEq "READY", d~status, "inputNew resets state and evaluates new request"

say "PASS test_clarification_escape"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
