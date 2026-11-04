/* Thin port to the existing Interaction Event capture authority.
 * This class deliberately does not construct InteractionEvent, InteractionLink,
 * observations, outcomes, or assessments. Their owning packages do that.
 */
::class WireInteractionCapturePort public
::method init
  expose library
  use strict arg library
  if library == .nil then raise syntax 88.900 array("WIRE_INTERACTION_LIBRARY_REQUIRED")

::method capture
  expose library
  use strict arg sealedEvent
  if sealedEvent == .nil then raise syntax 88.900 array("WIRE_INTERACTION_EVENT_REQUIRED")
  return library~captureEvent(sealedEvent)

::method link
  expose library
  use strict arg interactionLink
  if interactionLink == .nil then raise syntax 88.900 array("WIRE_INTERACTION_LINK_REQUIRED")
  return library~addLink(interactionLink)

::method assessmentsFor
  expose library
  use strict arg eventId
  return library~assessmentsFor(eventId)
