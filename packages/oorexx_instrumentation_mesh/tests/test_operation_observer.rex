#!/usr/bin/env rexx
say 'INSTRUMENTATION OPERATION OBSERVER TEST START'
identity=.InstrumentationCodec~identity('alchemy','deployment','deploy-a','ed209a','','DEPLOYMENT')
observer=.InstrumentationOperationObserver~new(identity)
observer~ready
observer~started('release-42','PREPARE',10,'steps','prepare','2026-10-09T20:15:00Z')
observer~advanced('release-42','DEPLOY',6,10,'steps','six complete','2026-10-09T20:15:05Z')
observer~completed('release-42',10,10,'steps','done','2026-10-09T20:15:10Z')
snap=observer~snapshot('2026-10-09T20:15:10Z')
call assertEq metric(snap,.InstrumentationVocabulary~OPERATION_STARTED_TOTAL),1,'operation started counter'
call assertEq metric(snap,.InstrumentationVocabulary~OPERATION_COMPLETED_TOTAL),1,'operation completed counter'
call assertEq snap['progress']~items,1,'progress retained for consumer'
call assertEq snap['progress'][1]['phase'],'COMPLETED','terminal progress phase'
call assertEq snap['progress'][1]['fraction'],1,'terminal progress fraction'
observer~retire('release-42')
snap2=observer~snapshot('2026-10-09T20:16:00Z')
call assertEq snap2['progress']~items,0,'retired progress removed'
say 'PASS generic deployment/service operation instrumentation'
exit 0

metric: procedure
  use arg snapshot,name
  do sample over snapshot['samples']
    if sample['name']=name then return sample['value']
  end
  return 'NOT_FOUND'

assertEq: procedure
  use arg actual,expected,label
  if actual=expected then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1

::requires 'src/InstrumentationMesh.cls'
::requires 'src/InstrumentationServiceAdapters.cls'
