#!/usr/bin/env rexx
say 'INSTRUMENTATION RELATIONSHIP COLLECTOR TEST START'

registry=.InstrumentationRegistry~new
source=.RelationshipFixtureSource~new
registry~register('fixture',source)
service=.InstrumentationService~new(registry)
collector=.InstrumentationCollector~new(8)
collectorService=.InstrumentationCollectorService~new(collector)
transport=.InstrumentationLocalCollectorTransport~new(collectorService,'publisher-a')
publisher=.InstrumentationPublisher~new('publisher-a',service,transport,'collector')

first=publisher~publish('2026-10-10T08:20:00Z',1000)
call assertTrue first~ok,'first publication accepted'
call assertEq first~receipt['accepted_relationship_sets'],1,'relationship set receipt count'
current=collector~latestRelationships
call assertEq current~items,2,'two current relationships'
call assertEq findKind(current,'DEPENDS_ON'),1,'dependency edge present'
call assertEq findKind(current,'TRAFFIC_TO'),1,'traffic edge present'
sets=collector~latestRelationshipSets
call assertEq sets~items,1,'one current complete scope'
call assertTrue sets[1]['complete'],'relationship scope complete'

/* A later complete set is the current authority-owned scope.  The collector
 * does not manufacture a WITHDRAWN edge; history retains the prior complete
 * set so consumers can show the topology change without becoming authority. */
source~advance
second=publisher~publish('2026-10-10T08:21:00Z',1060)
call assertTrue second~ok,'second publication accepted'
current2=collector~latestRelationships
call assertEq current2~items,1,'current relationship scope replaced atomically'
call assertEq findKind(current2,'DEPENDS_ON'),1,'remaining dependency edge'
call assertEq findKind(current2,'TRAFFIC_TO'),0,'removed traffic edge absent from latest complete scope'
history=collector~relationshipSetHistory
call assertEq history~items,2,'both relationship sets retained'
call assertEq history[1]['relationships']~items,2,'old complete scope retained'
call assertEq history[2]['relationships']~items,1,'new complete scope retained'
changes=collector~eventsHistory
call assertEq countEventKind(changes,'RELATIONSHIP_CEASED_VISIBLE'),1,'complete-scope disappearance projected as derived observation event'
change=findEventKind(changes,'RELATIONSHIP_CEASED_VISIBLE')
call assertTrue change['derived'],'relationship visibility event explicitly derived'
call assertEq change['evidence']['source_authority'],'FIXTURE_AUTHORITY','source relationship authority retained as evidence'

selector=.directory~new
selector['kind']='DEPENDS_ON'
query=.InstrumentationCodec~query('r1',selector,.nil,'','',0,'RELATIONSHIPS_LATEST',0)
reply=collector~query(query)
call assertEq reply['status'],'OK','relationship query status'
call assertEq reply['payload']~items,1,'relationship kind selector'

/* Returned graphs are defensive copies. */
copy=current2[1]
copy['kind']='BROKEN'
again=collector~latestRelationships
call assertEq again[1]['kind'],'DEPENDS_ON','collector relationship isolation'

say 'PASS complete relationship scopes retained and queried without topology authority transfer'
exit 0

countEventKind: procedure
  use arg events,kind
  count=0
  do event over events
    if event['kind']=kind then count+=1
  end
  return count

findEventKind: procedure
  use arg events,kind
  do event over events
    if event['kind']=kind then return event
  end
  return .nil

findKind: procedure
  use arg relationships,kind
  count=0
  do relationship over relationships
    if relationship['kind']=kind then count+=1
  end
  return count

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

::class RelationshipFixtureSource
::method init
  expose emitter phase
  identity=.InstrumentationCodec~identity('alchemy','fixture','one','node-a','','FIXTURE')
  emitter=.InstrumentationEmitter~new(identity)
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  phase=1
::method advance
  expose phase
  phase=2
  return self
::method snapshot
  expose emitter
  use strict arg observedAt=''
  return emitter~snapshot(observedAt)
::method relationshipSet
  expose phase
  use strict arg observedAt=''
  relationships=.array~new
  relationships~append(.InstrumentationCodec~relationship('a-b','DEPENDS_ON','service://a','service://b','FIXTURE_AUTHORITY',observedAt))
  if phase=1 then relationships~append(.InstrumentationCodec~relationship('b-c','TRAFFIC_TO','service://b','service://c','FIXTURE_AUTHORITY',observedAt))
  return .InstrumentationCodec~relationshipSet('fixture://topology','FIXTURE_AUTHORITY',.true,relationships,observedAt,phase)

::requires 'InstrumentationMesh.cls'
