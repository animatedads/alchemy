parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || base || "/../deps/intention_service/src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

provider = .ScientificSolverProvider~new
switch = .AvailabilitySwitch~new
provider~registerCapability(.ScientificSolverCapability~new("LIVE_ML", "ML", switch, 50))
request = .ScientificSolverRequest~new("ML", "analyse model")
call assertEq 0, provider~discover(request)~items, "not available initially"
switch~enabled = .true
call assertEq 1, provider~discover(request)~items, "rediscovered after capability change"
switch~enabled = .false
call assertEq 0, provider~discover(request)~items, "availability change observed without rebuilding provider"
say "PASS test_dynamic_capability_discovery"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class AvailabilitySwitch public
::method init; expose enabled; enabled=.false
::attribute enabled get
::attribute enabled set
::method available; expose enabled; use arg request; return enabled
::method solve; use arg request; return request~subject

::requires "ScientificSolverProvider.cls"
