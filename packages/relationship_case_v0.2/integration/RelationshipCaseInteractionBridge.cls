/* Optional bridge: Interaction Event remains authoritative for content/privacy. */
::class RelationshipCaseInteractionBridge public
::method fromEvent class
  use arg elementId, event, relationship = "CUSTOMER_INTERACTION", visibility = "INTERNAL"
  if event == .nil then return .RelationshipCaseResult~failure("INTERACTION_EVENT_REQUIRED")
  required = .array~of("EVENTID", "EVENTKIND", "POINTID", "OCCURREDAT", "SEALED")
  do methodName over required
    if event~hasMethod(methodName) = .false then return .RelationshipCaseResult~failure("INTERACTION_EVENT_PROTOCOL_INVALID", methodName)
  end
  if \event~sealed then return .RelationshipCaseResult~failure("INTERACTION_EVENT_NOT_SEALED", event~eventId)
  element = .RelationshipCaseElement~new(elementId, "INTERACTION", event~eventKind, relationship, "INTERACTION_EVENT", event~pointId, "EVIDENCE", event~occurredAt, visibility)
  element~addTag("SOURCE_CONTENT_NOT_COPIED")
  return .RelationshipCaseResult~success(element~seal)
::requires "RelationshipCase.cls"
