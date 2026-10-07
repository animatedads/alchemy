parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || base || "/../deps/intention_service/src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

provider = .ScientificSolverProvider~new
executor = .EchoExecutor~new
provider~registerCapability(.ScientificSolverCapability~new("ECHO_MATHS", "MATHS", executor, 100))
subject = .ScientificObject~new("authoritative-object")
context = .ScientificObject~new("context-object")
evidence = .ScientificObject~new("evidence-object")
request = .ScientificSolverRequest~new("MATHS", "solve it", subject, context, evidence)
solvedResult = provider~solve(request)
call assertTrue solvedResult~value == subject, "subject object identity preserved"
call assertTrue solvedResult~evidence == evidence, "evidence object identity preserved"
call assertTrue solvedResult~request~context == context, "context object identity preserved"
say "PASS test_object_preservation"
exit 0

assertTrue: procedure
  use arg ok, label
  if ok then return
  say "FAIL" label
  exit 1

::class ScientificObject public
::method init; expose name; use strict arg name
::attribute name get

::class EchoExecutor public
::method solve
  use strict arg request
  return .ScientificSolverResult~solved(request, "ECHO_MATHS", request~subject, request~evidence, "identity echo")

::requires "ScientificSolverProvider.cls"
