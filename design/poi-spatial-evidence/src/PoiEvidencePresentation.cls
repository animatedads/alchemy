/* POI Evidence Presentation — ooRexx source candidate dev2.
 * Case truth stays in evidence ledger; this class creates display rows only.
 * No inferred contacts, identity matches, or coordinates.
 */
::class PoiEvidencePresentation public
::method init
  expose ledger
  use strict arg ledger
::method subjectRows
  expose ledger
  use strict arg subjectId
  result = .array
  records = ledger~forSubject(subjectId)
  do i = 1 to records~items
    r = records[i]
    row = .directory
    row~put(r~recordId, 'recordId')
    row~put(r~subjectId, 'subjectId')
    row~put(r~placeId, 'placeId')
    row~put(r~timeExpression, 'timeExpression')
    row~put(r~timeResolution, 'timeResolution')
    row~put(r~evidenceRef, 'evidenceRef')
    row~put(r~assertionStatus, 'assertionStatus')
    row~put(r~methodRunRef, 'methodRunRef')
    row~put('NOT_ASSESSED', 'identityCertainty')
    row~put('NOT_ASSESSED', 'spatialCertainty')
    row~put('NOT_ASSESSED', 'temporalCertainty')
    row~put('NOT_ASSESSED', 'methodQualification')
    result~append(row)
  end
  return result
::method edgeCandidate
  use strict arg left, right
  result = .directory
  result~put('NO_RELATIONSHIP', 'classification')
  result~put('UNQUALIFIED', 'qualification')
  result~put('No contact or identity inference', 'warning')
  if left~candidateWith(right) then
    result~put('TEMPORAL_SPATIAL_CANDIDATE', 'classification')
    result~put('NEEDS_INDEPENDENT_REVIEW', 'qualification')
  end
  return result
::method mediaPanel
  use strict arg visible
  if visible then return 'VISIBLE'
  return 'HIDDEN_PRESENTATION_ONLY'
