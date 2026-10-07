parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 50, 8, .false, .false))
reg = service~register("show orders", .NoopEvent~new, "TEST")
reg~planBuilder(.OrdersPlanBuilder~new)
service~registerPlanTransformer(.ConversationTransformer~new)

d = service~input("show orders")
call assertEq "READY", d~status, "initial ready"
call assertEq "BOB", d~proposedPlan~metadata~at("CUSTOMER"), "initial customer"
call assertEq "ALL", d~proposedPlan~metadata~at("STATUS"), "initial status"
call assertEq "DATE", d~proposedPlan~metadata~at("ORDER"), "initial ordering"
service~dispatch(d)

d = service~input("only pending")
call assertEq "READY", d~status, "transformed ready"
call assertEq "BOB", d~proposedPlan~metadata~at("CUSTOMER"), "unspecified customer retained"
call assertEq "PENDING", d~proposedPlan~metadata~at("STATUS"), "status transformed"
call assertEq "DATE", d~proposedPlan~metadata~at("ORDER"), "unspecified ordering retained"
service~dispatch(d)

d = service~input("same for Jane")
call assertEq "READY", d~status, "second transform ready"
call assertEq "JANE", d~proposedPlan~metadata~at("CUSTOMER"), "customer replaced"
call assertEq "PENDING", d~proposedPlan~metadata~at("STATUS"), "prior transformed status retained"
call assertEq "DATE", d~proposedPlan~metadata~at("ORDER"), "ordering retained again"

say "PASS test_plan_transformations"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class NoopEvent public
::method invoke
  use arg decision
  return decision

::class OrdersPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Show orders")
  plan~sideEffectClass = "READ_ONLY"
  plan~tag("CUSTOMER", "BOB")
  plan~tag("STATUS", "ALL")
  plan~tag("ORDER", "DATE")
  plan~addStep("QUERY", "Query orders", "ORDERS")
  return plan

::class ConversationTransformer public
::method transform
  use arg service, text, prior
  upper = translate(strip(text))
  if upper == "ONLY PENDING" then do
    t = .IntentionPlanTransformation~new(98, "conversation status refinement")
    t~setPlanTag("STATUS", "PENDING")
    return t
  end
  if upper == "SAME FOR JANE" then do
    t = .IntentionPlanTransformation~new(98, "conversation subject substitution")
    t~setPlanTag("CUSTOMER", "JANE")
    return t
  end
  return .nil

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
