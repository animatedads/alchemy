/* Semantic plan dependency regression. */
parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

plan = .IntentionPlan~new("OPEN_DOOR", "Guard then mutate")
mutation = .IntentionPlanStep~new("SET_ATTRIBUTE", "set door open", "door")
mutation~id("MUTATE")
guard = .IntentionPlanStep~new("RETURN_IF_ALREADY", "return false if already open", "door")
guard~id("GUARD")
mutation~dependsOn("GUARD")
plan~appendStep(mutation)
plan~appendStep(guard)

call assert plan~steps~at(1)~id == "MUTATE", "declared order must remain intact"
validation = plan~validate
call assert validation~valid, "valid dependency graph should validate"
ordered = plan~executionSteps
call assert ordered~at(1)~id == "GUARD", "execution order should put guard before mutation"
call assert ordered~at(2)~id == "MUTATE", "mutation should follow guard"

cycle = .IntentionPlan~new("BAD", "cycle")
a = .IntentionPlanStep~new("A")
a~id("A")
a~dependsOn("B")
b = .IntentionPlanStep~new("B")
b~id("B")
b~dependsOn("A")
cycle~appendStep(a)~appendStep(b)
call assert \cycle~validate~valid, "cycle must fail validation"

missing = .IntentionPlan~new("BAD2", "missing")
x = .IntentionPlanStep~new("X")
x~id("X")
x~dependsOn("NOPE")
missing~appendStep(x)
call assert \missing~validate~valid, "missing dependency must fail validation"

say "PASS test_plan_dependencies"
exit 0

assert: procedure
  use arg ok, message
  if \ok then do
    say "FAIL:" message
    exit 1
  end
  return

::requires "IntentionService.cls"
