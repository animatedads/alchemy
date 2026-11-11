/* POI dev2 semantic tests. Run: rexx tests/test_poi_scene.rex */
::requires '../src/PoiSceneProjection.cls'
p = .PoiSceneProjection~new
call check p~libraryVisible, 'library defaults visible'
o = .PoiSceneObservation~new('obs-1','subject-A','glasgow-central','2028-12-01','DATE_ONLY','media-1','run-1','PENDING','DIRECT_OBSERVATION')
call check p~addObservation(o) = 1, 'observation appended'
call check p~selectRecord('obs-1'), 'existing record selectable'
call check p~selectedObservation~recordId == 'obs-1', 'selection returns record'
call check \p~selectRecord('missing'), 'unknown record rejected'
p~hideLibrary
call check \p~libraryVisible, 'library hidden'
s = p~sceneState
call check s['observations']~items = 1, 'hiding does not delete evidence'
call check s['observations'][1]['evidenceRef'] == 'media-1', 'evidence ref retained'
call check s['observations'][1]['timeResolution'] == 'DATE_ONLY', 'date-only retained'
call check s['observations'][1]['relationClass'] == 'DIRECT_OBSERVATION', 'relation class retained'
p~showLibrary
call check p~libraryVisible, 'library restored'
say 'PASS POI scene semantic tests'
exit 0
check: procedure
  use arg ok, label
  if \ok then do
    say 'FAIL:' label
    exit 1
  end
  return
