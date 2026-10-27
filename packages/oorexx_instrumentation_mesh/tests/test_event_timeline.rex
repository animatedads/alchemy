#!/usr/bin/env rexx
say 'INSTRUMENTATION EVENT TIMELINE TEST START'

identity=.InstrumentationCodec~identity('alchemy','deployment','deploy-a','ed209a','','DEPLOYMENT')
ref=.InstrumentationCodec~semanticRef(identity)
observer=.InstrumentationOperationObserver~new(identity,'DEPLOYMENT_AUTHORITY')
observer~ready
observer~started('release-42','PREPARE',10,'steps','prepare','2026-10-10T14:00:00Z')
observer~completed('release-42',10,10,'steps','done','2026-10-10T14:01:00Z')
registry=.InstrumentationRegistry~new
registry~register('deployment',observer)
service=.InstrumentationService~new(registry)
collector=.InstrumentationCollector~new(16)
transport=.InstrumentationLocalCollectorTransport~new(.InstrumentationCollectorService~new(collector),'deploy-node')
publisher=.InstrumentationPublisher~new('deploy-publisher',service,transport,'noc')

first=publisher~publish('2026-10-10T14:01:00Z',1000)
call assertTrue first~ok,'first event publication accepted'
call assertEq first~receipt['accepted_events'],2,'two source events accepted'
events=collector~eventsHistory
call assertEq events~items,2,'source event history retained'
call assertEq countKind(events,'OPERATION_STARTED'),1,'operation started event retained'
call assertEq countKind(events,'OPERATION_COMPLETED'),1,'operation completed event retained'
call assertEq events[1]['authority'],'DEPLOYMENT_AUTHORITY','source event authority retained'
call assertTrue \events[1]['derived'],'source event is not derived'

/* The source retains a bounded replay journal. A later successful publication
 * may carry the same source events; event-id fencing prevents duplicates. */
second=publisher~publish('2026-10-10T14:02:00Z',1060)
call assertTrue second~ok,'second publication accepted'
call assertEq second~receipt['accepted_events'],0,'replayed source events deduplicated'
call assertEq collector~eventsHistory~items,2,'dedupe keeps history stable'

/* Health transition is collector-derived observation, clearly separated from
 * source authority. */
observer~degraded
third=publisher~publish('2026-10-10T14:03:00Z',1120)
call assertTrue third~ok,'health transition publication accepted'
events3=collector~eventsHistory
call assertEq countKind(events3,'HEALTH_CHANGED'),1,'health evidence change projected as event'
healthEvent=findKind(events3,'HEALTH_CHANGED')
call assertTrue healthEvent['derived'],'health change explicitly derived'
call assertEq healthEvent['authority'],'INSTRUMENTATION_OBSERVER','derived event authority explicit'
call assertEq healthEvent['evidence']['new_health'],'DEGRADED','derived event carries observed health'

selector=.directory~new; selector['operation_id']='release-42'
query=.InstrumentationCodec~query('events-q',selector,.nil,'','',0,'EVENTS_HISTORY',20)
reply=collector~query(query)
call assertEq reply['status'],'OK','events query accepted'
call assertEq reply['payload']~items,2,'operation event selector excludes unrelated derived health event'

/* Array.remove(1) does not compact an ooRexx Array.  Boundaries therefore
 * rebuild a contiguous tail rather than looping on a sparse first slot. */
journal=.InstrumentationEventJournal~new(2)
journal~append(.InstrumentationCodec~event('e1','ONE',ref,'TEST','2026-10-10T14:00:00Z'))
journal~append(.InstrumentationCodec~event('e2','TWO',ref,'TEST','2026-10-10T14:00:01Z'))
journal~append(.InstrumentationCodec~event('e3','THREE',ref,'TEST','2026-10-10T14:00:02Z'))
bounded=journal~events
call assertEq bounded~items,2,'bounded event journal remains contiguous'
call assertEq bounded[1]['event_id'],'e2','bounded event journal drops oldest item'
localHistory=.InstrumentationHistory~new(2)
localHistory~append(observer~snapshot('t1'))
localHistory~append(observer~snapshot('t2'))
localHistory~append(observer~snapshot('t3'))
call assertEq localHistory~all~items,2,'bounded snapshot history remains contiguous'

say 'PASS replay-safe source events, derived observation changes and bounded contiguous history'
exit 0

countKind: procedure
  use arg events,kind
  count=0
  do event over events
    if event['kind']=kind then count+=1
  end
  return count

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
::requires 'InstrumentationServiceAdapters.cls'
