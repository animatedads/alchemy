/* Minimal dev2 seam example: ask for a specialist that promises source-object evidence. */
subject = .ExampleSubject~new("authoritative domain object")
solver = .ScientificSolverProvider~new

fast = .ScientificSolverCapability~new("FAST_SUMMARY", "ML", .EchoExpert~new, 100)
fast~tag("EVIDENCE_POLICY", "SUMMARY_ONLY")
solver~registerCapability(fast)

traceable = .ScientificSolverCapability~new("TRACEABLE_EXPERT", "ML", .EchoExpert~new, 50)
traceable~tag("EVIDENCE_POLICY", "SOURCE_OBJECTS")
solver~registerCapability(traceable)

request = .ScientificSolverRequest~new("ML", "analyse this", subject)
request~require("EVIDENCE_POLICY", "SOURCE_OBJECTS")
answer = solver~solve(request)

say answer~status answer~capability
say "registry revision=" answer~selection~registryRevision
say "same object=" (answer~value == subject)
exit 0

::class ExampleSubject public
::method init
  expose label
  use strict arg label
::attribute label get

::class EchoExpert public
::method available
  use strict arg request
  return .true
::method solve
  use strict arg request
  return request~subject

::requires "ScientificSolverProvider.cls"
