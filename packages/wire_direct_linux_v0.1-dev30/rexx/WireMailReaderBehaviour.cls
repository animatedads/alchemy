/* MailReader composition root for semantic UI behaviour.
 * It coordinates existing projections and an application-supplied interaction
 * boundary.  It does not create InteractionEvent/Observation/Outcome objects,
 * time investigations, train ML, fetch ranges, or own renderer mechanics.
 */
::class WireMailReaderBehaviour public
::method init
  expose subjectProjection selectionProjection interactionBoundary assessmentProjection
  use strict arg subjectProjection, selectionProjection, interactionBoundary = .nil, assessmentProjection = .nil

::method selectionChanged
  expose subjectProjection selectionProjection interactionBoundary assessmentProjection
  use strict arg event
  subjectRef = subjectProjection~subjectFor(event)
  /* The application boundary owns conversion to its existing interaction/evidence objects. */
  if interactionBoundary \== .nil then interactionBoundary~selectionChanged(subjectRef, event)
  selectionProjection~selectionChanged(event)
  /* Existing assessment may decorate the selected visible row; absence is a no-op. */
  if assessmentProjection \== .nil then assessmentProjection~assessmentChanged(subjectRef)
  return subjectRef

::method assessmentChanged
  expose assessmentProjection
  use strict arg subjectRef
  if assessmentProjection == .nil then return .false
  return assessmentProjection~assessmentChanged(subjectRef)
