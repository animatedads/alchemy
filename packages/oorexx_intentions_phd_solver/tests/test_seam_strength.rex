parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || base || "/../deps/intention_service/src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

subject = .IdentityProbe~new("authoritative subject")
request = .ScientificSolverRequest~new("ML", "analyse this", subject)
request~require("EVIDENCE_POLICY", "SOURCE_OBJECTS")

weak = .ScientificSolverCapability~new("GENERIC_ML", "ML", .ProbeExecutor~new(subject, "weak"), 100)
weak~tag("EVIDENCE_POLICY", "SUMMARY_ONLY")
strong = .ScientificSolverCapability~new("EVIDENCE_ML", "ML", .ProbeExecutor~new(subject, "strong"), 50)
strong~tag("EVIDENCE_POLICY", "SOURCE_OBJECTS")
strong~tag("AUTHORITY", "DOMAIN_SPECIALIST")

provider = .ScientificSolverProvider~new
provider~registerCapability(weak)
provider~registerCapability(strong)
call assertEq 2, provider~capabilityRevision, "revision after registrations"

selection = provider~select(request)
call assertEq "EVIDENCE_ML", selection~selectedName, "hard requirements beat higher priority mismatch"
call assertEq 1, selection~candidates~items, "only matching candidate remains"
call assertEq 2, selection~registryRevision, "selection captures registry revision"

answer = provider~solve(request)
call assertEq "SOLVED", answer~status, "request solved"
call assertEq "EVIDENCE_ML", answer~capability, "correct capability"
if answer~value \== subject then do
  say "FAIL subject identity was not preserved"
  exit 1
end
if answer~selection == .nil then do
  say "FAIL selection evidence missing from result"
  exit 1
end
call assertEq "EVIDENCE_ML", answer~selection~selectedName, "result selection evidence"

replacement = .ScientificSolverCapability~new("EVIDENCE_ML", "ML", .ProbeExecutor~new(subject, "replacement"), 75)
replacement~tag("EVIDENCE_POLICY", "SOURCE_OBJECTS")
provider~registerCapability(replacement)
call assertEq 3, provider~capabilityRevision, "same-name registration is replacement"
call assertEq 2, provider~capabilities~items, "replacement does not duplicate capability"

removed = provider~unregisterCapability("GENERIC_ML")
call assertEq 1, removed, "capability removal"
call assertEq 4, provider~capabilityRevision, "removal increments revision"
call assertEq 1, provider~capabilities~items, "registry reflects removal"

say "PASS test_seam_strength"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class IdentityProbe public
::method init
  expose text
  use strict arg text
::attribute text get

::class ProbeExecutor public
::method init
  expose expected label
  use strict arg expected, label
::method available
  use strict arg request
  return request~subject \== .nil
::method score
  use strict arg request
  return 0
::method explainSelection
  expose label
  use strict arg request
  return "selected " || label || " without flattening subject"
::method solve
  expose expected
  use strict arg request
  if request~subject \== expected then raise syntax 93.900 array("subject identity changed")
  return request~subject

::requires "ScientificSolverProvider.cls"
