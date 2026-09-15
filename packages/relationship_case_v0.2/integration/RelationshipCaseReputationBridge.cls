/* Optional bridge: Reputation Feed hypotheses are observations, never bank decisions. */
::class RelationshipCaseReputationBridge public
::method fromHypothesis class
  use arg elementId, hypothesis, relationship = "EXTERNAL_SIGNAL", visibility = "RESTRICTED"
  if hypothesis == .nil then return .RelationshipCaseResult~failure("REPUTATION_HYPOTHESIS_REQUIRED")
  required = .array~of("HYPOTHESISID", "EVENTTYPE")
  do methodName over required
    if hypothesis~hasMethod(methodName) = .false then return .RelationshipCaseResult~failure("REPUTATION_HYPOTHESIS_PROTOCOL_INVALID", methodName)
  end
  if hypothesis~hasMethod("SEALED") then if \hypothesis~sealed then return .RelationshipCaseResult~failure("REPUTATION_HYPOTHESIS_NOT_SEALED", hypothesis~hypothesisId)
  whenObserved = .DateTime~new
  if hypothesis~hasMethod("LASTOBSERVEDAT") then do
    candidate = hypothesis~lastObservedAt
    if candidate <> .nil then whenObserved = candidate
  end
  ref = "REPUTATION_HYPOTHESIS:" || hypothesis~hypothesisId
  element = .RelationshipCaseElement~new(elementId, "EXTERNAL_SIGNAL", hypothesis~eventType, relationship, "REPUTATION_FEED", ref, "OBSERVATION_NOT_DECISION", whenObserved, visibility)
  element~addTag("NO_CORE_BANKING_AUTHORITY")
  element~addTag("ASSERTION_NOT_PROMOTED_TO_FACT")
  return .RelationshipCaseResult~success(element~seal)
::requires "RelationshipCase.cls"
