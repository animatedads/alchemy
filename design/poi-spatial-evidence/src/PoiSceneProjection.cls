/* POI presentation projection dev2. Renderer-neutral semantic payload.
 * No external Time Service calls: unresolved dates stay unresolved.
 */
::class PoiSceneProjection public
::attribute observations get
::attribute libraryVisible get
::attribute selectedRecordId get
::method init
  expose observations libraryVisible selectedRecordId
  observations = .array
  libraryVisible = .true
  selectedRecordId = ''
::method addObservation
  expose observations
  use strict arg observation
  if \observation~isA(.PoiSceneObservation) then
    raise syntax 93.914 array ('PoiSceneObservation required')
  observations~append(observation)
  return observations~items
::method showLibrary
  expose libraryVisible
  libraryVisible = .true
::method hideLibrary
  expose libraryVisible
  libraryVisible = .false
::method selectRecord
  expose observations selectedRecordId
  use strict arg recordId
  do i = 1 to observations~items
    if observations[i]~recordId == recordId then do
      selectedRecordId = recordId
      return .true
    end
  end
  return .false
::method selectedObservation
  expose observations selectedRecordId
  do i = 1 to observations~items
    if observations[i]~recordId == selectedRecordId then return observations[i]
  end
  return .nil
::method sceneState
  expose observations libraryVisible selectedRecordId
  state = .directory~new
  state['kind'] = 'poi.scene.v0.2'
  state['libraryVisible'] = libraryVisible
  state['selectedRecordId'] = selectedRecordId
  state['observations'] = .array~new
  do i = 1 to observations~items
    o = observations[i]
    state['observations']~append(o~semanticState)
  end
  return state

::class PoiSceneObservation public
::attribute recordId get
::attribute subjectId get
::attribute placeId get
::attribute dateExpression get
::attribute timeResolution get
::attribute evidenceRef get
::attribute methodRunRef get
::attribute reviewState get
::attribute relationClass get
::method init
  use strict arg recordId, subjectId, placeId, dateExpression, timeResolution, evidenceRef, methodRunRef, reviewState, relationClass
  self~recordId = recordId
  self~subjectId = subjectId
  self~placeId = placeId
  self~dateExpression = dateExpression
  self~timeResolution = timeResolution
  self~evidenceRef = evidenceRef
  self~methodRunRef = methodRunRef
  self~reviewState = reviewState
  self~relationClass = relationClass
::method semanticState
  state = .directory~new
  state['recordId'] = self~recordId
  state['subjectId'] = self~subjectId
  state['placeId'] = self~placeId
  state['dateExpression'] = self~dateExpression
  state['timeResolution'] = self~timeResolution
  state['evidenceRef'] = self~evidenceRef
  state['methodRunRef'] = self~methodRunRef
  state['reviewState'] = self~reviewState
  state['relationClass'] = self~relationClass
  return state
