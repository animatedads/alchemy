/* Extracts an application subject from a semantic Wire event.
   No observation, outcome, timing, source protocol, renderer, or ML policy lives here. */
::class WireEventSubjectProjection public
::method init
  expose contextKey
  use strict arg contextKey = "identity"
::method subjectFor
  expose contextKey
  use strict arg event
  value = event~context[contextKey]
  return .WireSubjectRef~new(value)
::requires "WireSubjectRef.cls"
