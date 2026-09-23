parse source . . testHere
root = filespec("L", testHere)
packageRoot = root
if packageRoot~right(6) = "tests/" then packageRoot = packageRoot~left(packageRoot~length - 6)
tmp = "/tmp/llmpa-ability-registry-test-" || random(10000,99999)
address command "rm -rf" tmp
address command "mkdir -p" tmp tmp || "/modules" tmp || "/dupes"

ctx = .LlmPaAbilityContext~new
plans = .LlmPaPlanManager~new(.LlmPaPlanStore~new(tmp || "/plans.journal"))
created = plans~create("Ability registry test plan", "prove current-plan discovery")
call must created~ok, "plan create"
continuity = .LlmPaContinuityBrief~new(tmp || "/continuity.brief")
published = continuity~publish("DONE: registry test prepared; NEXT: invoke named ability", "test")
call must published~ok, "continuity publish"
ignore = ctx~setService("plans", plans)
ignore = ctx~setService("continuity", continuity)
reg = .LlmPaAbilityRegistry~new(packageRoot || "/abilities.d", ctx)
loaded = reg~load
call must loaded~ok, "registry load"
call must loaded~value["count"] >= 6, "built-in ability count"
ignore = ctx~setService("ability_registry", reg)

catalog = reg~invoke("abilities")
call must catalog~ok, "catalog alias invoke"
call must catalog~value["schema"] = "llm.pa.ability.execution/0.1", "execution schema"
call must catalog~value["result"]["schema"] = "llm.pa.ability.catalogue/0.1", "catalog schema"

current = reg~invoke("current-plan")
call must current~ok, "current plan alias"
call must current~value["result"]["plan"]["title"] = "Ability registry test plan", "current plan content"
call must current~value["result"]["authority"] = "DURABLE_PLAN_EVENTS", "plan authority"

handoff = reg~invoke("continuity.current")
call must handoff~ok, "continuity invoke"
call must handoff~value["result"]["authority"] = "PROJECTION_ONLY", "continuity authority label"
call must handoff~value["result"]["brief"]["text"]~pos("registry test") > 0, "continuity text"

/* A new module becomes callable by merely appearing in the directory. */
module = tmp || "/modules/DropIn.cls"
call lineout module, "::class DropInAbility subclass LlmPaAbility public"
call lineout module, "::method abilityId"
call lineout module, " return 'test.dropin'"
call lineout module, "::method version"
call lineout module, " return '0.1.0'"
call lineout module, "::method description"
call lineout module, " return 'drop-in discovery test'"
call lineout module, "::method execute"
call lineout module, " use arg context, request"
call lineout module, " return .LlmPaResult~success('PONG')"
call lineout module, "::requires 'LlmPaAbility.cls'"
call lineout module
reg2 = .LlmPaAbilityRegistry~new(tmp || "/modules", .LlmPaAbilityContext~new)
r2 = reg2~load
call must r2~ok, "drop-in module load"
x = reg2~invoke("test.dropin")
call must x~ok, "drop-in invoke"
call must x~value["result"] = "PONG", "drop-in result"

/* Duplicate identity never becomes last-file-wins. */
do suffix over .array~of("A", "B")
  path = tmp || "/dupes/" || suffix || ".cls"
  call lineout path, "::class Duplicate" || suffix || "Ability subclass LlmPaAbility public"
  call lineout path, "::method abilityId"
  call lineout path, " return 'test.duplicate'"
  call lineout path, "::method version"
  call lineout path, " return '0.1.0'"
  call lineout path, "::method description"
  call lineout path, " return 'duplicate test'"
  call lineout path, "::requires 'LlmPaAbility.cls'"
  call lineout path
end
reg3 = .LlmPaAbilityRegistry~new(tmp || "/dupes", .LlmPaAbilityContext~new)
r3 = reg3~load
call must \r3~ok, "duplicate blocks load"
call must r3~code = "ABILITY_NAME_COLLISION", "duplicate collision code"

/* Structured Response is an injected producer boundary, not reimplemented here. */
ctx4 = .LlmPaAbilityContext~new
ignore = ctx4~setService("structured_response_emitter", .FakeStructuredEmitter~new)
reg4 = .LlmPaAbilityRegistry~new(tmp || "/modules", ctx4)
r4 = reg4~load
call must r4~ok, "emitter registry load"
e4 = reg4~invoke("test.dropin")
call must e4~ok, "emitter invoke"
call must e4~value["adapted"] = "YES", "structured response emitter used"

address command "rm -rf" tmp
say "PASS test_ability_registry"
exit 0

::class FakeStructuredEmitter public
::method emitAbilityExecution
  use arg execution, request
  d = .directory~new
  d["adapted"] = "YES"
  d["execution"] = execution
  return .LlmPaResult~success(d)

::routine must
  use arg ok, label
  if \ok then do; say "FAIL" label; exit 1; end
return

::requires "LlmPaAbility.cls"
::requires "LlmPaPlan.cls"
::requires "LlmPaContinuity.cls"
