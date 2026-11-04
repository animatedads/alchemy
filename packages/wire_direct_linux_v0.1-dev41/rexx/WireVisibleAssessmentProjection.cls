/* Visible-row assessment projection.
   The application owns assessment production and current-model selection.
   This object only projects sparse, already-produced values onto identities
   supplied by the currently visible range.  It cannot fetch, train or sort. */
::class WireVisibleAssessmentProjection public
::method init
  expose view rowTarget property
  use strict arg view, rowTarget, property = "assessment"
::method projectVisible
  expose view rowTarget property
  use strict arg subjectRefs
  touched = 0
  do subjectRef over subjectRefs
    assessment = view~assessmentForSubject(subjectRef)
    if assessment \== .nil then do
      rowTarget~setRowProperty(subjectRef~string, property, assessment~value)
      touched = touched + 1
    end
  end
  return touched
::method assessmentChanged
  expose view rowTarget property
  use strict arg subjectRef
  assessment = view~assessmentForSubject(subjectRef)
  if assessment == .nil then return .false
  return rowTarget~setRowProperty(subjectRef~string, property, assessment~value)
