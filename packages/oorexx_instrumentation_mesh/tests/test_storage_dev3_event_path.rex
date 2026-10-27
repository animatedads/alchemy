#!/usr/bin/env rexx
say 'STORAGE DEV3 -> INSTRUMENTATION EVENT PATH TEST START'

identity=.InstrumentationCodec~identity('alchemy','storage','storage-a','ed209a','MI-A1','STORAGE_FABRIC')
storageEvents=.StorageFabricMeshEvents~new(identity)
storageEvents~healthy
registry=.InstrumentationRegistry~new
registry~register('storage',storageEvents)
service=.InstrumentationService~new(registry)
collector=.InstrumentationCollector~new(16)
transport=.InstrumentationLocalCollectorTransport~new(.InstrumentationCollectorService~new(collector),'storage-node')
publisher=.InstrumentationPublisher~new('storage-publisher',service,transport,'noc')

call assertTrue publisher~publish('2026-10-10T14:40:00Z',2000)~ok,'storage healthy baseline accepted'
storageEvents~repairRequired('repair-1','replica_shortfall')
call assertTrue publisher~publish('2026-10-10T14:41:00Z',2060)~ok,'storage degraded observation accepted'
events=collector~eventsHistory
change=findKind(events,'HEALTH_CHANGED')
call assertTrue change<>.nil,'storage health change visible in event timeline'
call assertTrue change['derived'],'storage transition is explicitly observer-derived'
call assertEq change['evidence']['new_health'],'DEGRADED','storage degraded evidence retained'
call assertEq change['subject_ref'],.InstrumentationCodec~semanticRef(identity),'storage semantic subject retained'

say 'PASS current Storage instrumentation dev3 feeds event timeline without changing Storage authority'
exit 0

findKind: procedure
  use arg events,kind
  do event over events
    if event['kind']=kind then return event
  end
  return .nil

assertTrue: procedure
  use arg truth,label
  if truth then return
  say 'FAIL' label
  exit 1

assertEq: procedure
  use arg actual,expected,label
  if actual=expected then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1

::requires 'InstrumentationMesh.cls'
::requires 'StorageInstrumentationMesh.cls'
