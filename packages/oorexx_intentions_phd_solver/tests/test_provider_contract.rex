parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || base || "/../deps/intention_service/src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~registerProvider(.DeterministicIntentionProvider~new)
provider = .ScientificSolverProvider~new
provider~install(service)

d = service~input("rent a phd to solve this coupled scientific problem")
call assertEq "CONFIRM", d~status, "scientific request confirms"
d = service~input("yes")
call assertEq "READY", d~status, "scientific request becomes ready"
directive = service~dispatch(d)
call assertEq "COUPLED", directive~domain, "coupled route"
call assertEq "scientific.solver/0.1", directive~provider~contract, "provider contract"
say "PASS test_provider_contract"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::requires "ScientificSolverProvider.cls"
