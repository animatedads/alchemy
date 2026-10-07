probe = .Probe~new
registry = .DFAutoTaskRegistry~new
registry~add(.DFAutoTask~new("A", "AFTER_SOURCE_CHANGE", "probe", probe, "run"))
registry~add(.DFAutoTask~new("B", "BEFORE_STAGE_ACCEPTANCE", "other"))
results = registry~runTrigger("AFTER_SOURCE_CHANGE")
call assertEqual 1, results~items, "result count"
call assertEqual 1, results[1]~ok, "task ok"
call assertEqual "ran", results[1]~detail, "task result"
call assertEqual 1, registry~tasksFor("before_stage_acceptance")~items, "trigger case insensitive"
say "PASS test_autotasks"
exit 0
assertEqual: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return
::class Probe
::method run
  return "ran"
::requires "DevelopmentFloor.cls"
