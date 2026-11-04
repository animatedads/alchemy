/* Generic derived-state projection: subject -> assessment resolver -> semantic target.
   The resolver owns assessment/model access. This class never trains, observes, or reorders. */
::class WireAssessmentProjection public
::method init
  expose resolver target property
  use strict arg resolver, target, property = "value"
::method refresh
  expose resolver target property
  use strict arg subjectRef
  value = resolver~valueForSubject(subjectRef)
  target~setProperty(property, value)
