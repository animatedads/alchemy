parse source . . testHere
root = filespec("L", testHere)
packageRoot = root
if packageRoot~right(6) = "tests/" then packageRoot = packageRoot~left(packageRoot~length - 6)
tmp = "/tmp/llmpa-ability-worker-test-" || random(10000,99999)
address command "rm -rf" tmp
address command "mkdir -p" tmp
plans = .LlmPaPlanManager~new(.LlmPaPlanStore~new(tmp || "/plans.journal"))
made = plans~create("Worker ability plan", "prove Queue-backed named ability dispatch")
call must made~ok, "create plan"
continuity = .LlmPaContinuityBrief~new(tmp || "/continuity.brief")
call must continuity~publish("worker projection", "test")~ok, "publish continuity"
ctx = .LlmPaAbilityContext~new
ignore = ctx~setService("plans", plans)
ignore = ctx~setService("continuity", continuity)
reg = .LlmPaAbilityRegistry~new(packageRoot || "/abilities.d", ctx)
call must reg~load~ok, "registry load"
ignore = ctx~setService("ability_registry", reg)

req = .directory~new
req["schema"] = "llm.pa.request/0.1"
req["request_id"] = "worker-ability-1"
req["command"] = "ability_invoke"
req["arg1"] = "plan.current"
req["arg2"] = "{}"
req["submitted_by"] = "test"
req["reply_to"] = "LLMPA.REPLY"
req["created_at"] = .LlmPaUtil~timestamp
binding = .FakeAbilityBinding~new(req)
worker = .LlmPaWorker~new(binding, .nil, .nil, "test-model", .nil, .nil, .nil, continuity, plans, .nil, .nil, .nil, .nil, reg)
out = worker~processOne
call must out~ok, "worker result"
reply = out~value
call must reply["kind"] = "ABILITY", "worker ability kind"
call must reply["ability_execution"]["ability"]["ability_id"] = "plan.current", "worker canonical ability"
call must reply["ability_execution"]["result"]["plan"]["title"] = "Worker ability plan", "worker plan result"

req2 = .LlmPaUtil~copyDirectory(req)
req2["request_id"] = "worker-ability-2"
req2["command"] = "ability_catalogue"
req2["arg1"] = "package"
req2["arg2"] = ""
binding2 = .FakeAbilityBinding~new(req2)
worker2 = .LlmPaWorker~new(binding2, .nil, .nil, "test-model", .nil, .nil, .nil, continuity, plans, .nil, .nil, .nil, .nil, reg)
out2 = worker2~processOne
call must out2~ok, "worker catalogue result"
call must out2~value["ability_execution"]["result"]["count"] = 3, "worker catalogue filter"

address command "rm -rf" tmp
say "PASS test_ability_worker"
exit 0

::class FakeAbilityPackage public
::attribute payload get
::method init
  expose payload
  use arg payloadArg
  payload = payloadArg

::class FakeAbilityBinding public
::method init
  expose request
  use arg requestArg
  request = requestArg
::method claimRequest
  expose request
  return .LlmPaResult~success(.FakeAbilityPackage~new(request))
::method completeRequest
  use arg package, reply
  return .LlmPaResult~success(reply)

::routine must
  use arg ok, label
  if \ok then do; say "FAIL" label; exit 1; end
return

::requires "LlmPaWorker.cls"
::requires "LlmPaAbility.cls"
::requires "LlmPaPlan.cls"
::requires "LlmPaContinuity.cls"
