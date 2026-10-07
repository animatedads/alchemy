parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~registerProvider(.DeterministicIntentionProvider~new)
event = .DemoEvent~new
service~register("have dinner", event)~alias("eat dinner")

decision = service~input("I would like to eat dinner")
call assertEquals "CONFIRM", decision~status, "recognition asks for confirmation"
decision = service~input("yes")
call assertEquals "READY", decision~status, "confirmation makes decision ready"
value = service~dispatch(decision)
call assertEquals "DINNER", value, "dispatch invokes event"
call assertEquals 1, event~count, "event invoked exactly once"
say "PASS test_intention_service"
exit 0

assertEquals: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class DemoEvent public
::method init
  expose count
  count = 0
::method invoke
  expose count
  use arg decision
  count = count + 1
  return "DINNER"
::attribute count get

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
