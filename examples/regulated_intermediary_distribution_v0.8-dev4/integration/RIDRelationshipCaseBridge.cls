/* Optional bridge: distribution cases can be referenced from the general
 * Relationship Case domain without transferring product/provider authority.
 */
::class RIDRelationshipCaseBridge public
::method distributionCaseElement class
  use arg distributionCase, elementId, relationship = "COORDINATES_WITH", recordedAt = .nil, visibility = "INTERNAL"
  if distributionCase == .nil then raise syntax 88.987 array("distribution case required")
  if \distributionCase~isA(.RIDDistributionCase) then raise syntax 88.987 array("RIDDistributionCase required")
  if recordedAt == .nil then recordedAt = .DateTime~new
  e = .RelationshipCaseElement~new(elementId, "EVIDENCE", "REGULATED_DISTRIBUTION_CASE", relationship, "REGULATED_INTERMEDIARY_DISTRIBUTION", distributionCase~caseId, "WORK_COORDINATION_REFERENCE", recordedAt, visibility)
  e~addTag("PRODUCT_" || distributionCase~productRefId)
  return e~seal
::method providerProgressElement class
  use arg distributionCase, elementId, recordedAt = .nil, visibility = "INTERNAL"
  if distributionCase == .nil then raise syntax 88.987 array("distribution case required")
  if recordedAt == .nil then recordedAt = .DateTime~new
  if distributionCase~providerCaseRef = "" then return .RIDResult~failure("PROVIDER_CASE_NOT_ESTABLISHED")
  e = .RelationshipCaseElement~new(elementId, "EVIDENCE", "PRODUCT_PROVIDER_PROGRESS", "EVIDENCE_FOR", "REGULATED_INTERMEDIARY_DISTRIBUTION", distributionCase~caseId, "PROVIDER_STATUS_REFERENCE", recordedAt, visibility)
  return .RIDResult~success(e~seal)

::requires "RegulatedIntermediaryDistribution.cls"
::requires "RelationshipCase.cls"
