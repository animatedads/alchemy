/* POI evidence inspector: projection only; never upgrades an assertion.
 * All data is supplied by the case authority and media resolver.
 */
::class PoiEvidenceInspector public
::attribute selected get
::method init
  expose selected
  selected = .nil
::method inspect
  expose selected
  use strict arg observation, sourceIntegrity, spatialPrecision, temporalPrecision, identityStatus, methodStatus, contradictionStatus
  if \observation~isA(.PoiSceneObservation) then
    raise syntax 93.914 array ('PoiSceneObservation required')
  result = .directory~new
  result['recordId'] = observation~recordId
  result['subjectId'] = observation~subjectId
  result['placeId'] = observation~placeId
  result['dateExpression'] = observation~dateExpression
  result['timeResolution'] = observation~timeResolution
  result['evidenceRef'] = observation~evidenceRef
  result['methodRunRef'] = observation~methodRunRef
  result['reviewState'] = observation~reviewState
  result['relationClass'] = observation~relationClass
  result['sourceIntegrity'] = sourceIntegrity
  result['spatialPrecision'] = spatialPrecision
  result['temporalPrecision'] = temporalPrecision
  result['identityStatus'] = identityStatus
  result['methodStatus'] = methodStatus
  result['contradictionStatus'] = contradictionStatus
  result['reproducibility'] = 'NOT_EVALUATED'
  result['contactProven'] = .false
  selected = result
  return result
::method clear
  expose selected
  selected = .nil

::requires 'PoiSceneProjection.cls'
