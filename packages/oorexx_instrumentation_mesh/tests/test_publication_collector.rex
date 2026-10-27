#!/usr/bin/env rexx
say 'INSTRUMENTATION PUBLICATION / COLLECTOR TEST START'

identity=.InstrumentationCodec~identity('alchemy','queue-fabric','qf-a','ed209a','MI-A1','QUEUE_FABRIC')
emitter=.InstrumentationEmitter~new(identity)
emitter~setHealth(.InstrumentationHealth~HEALTHY)
ignore=emitter~gaugeSet(.InstrumentationVocabulary~QUEUE_DEPTH,3,'messages')
registry=.InstrumentationRegistry~new
registry~register('qf-a',emitter)
service=.InstrumentationService~new(registry)

collector=.InstrumentationCollector~new(8)
consumer=.TestConsumer~new
failingConsumer=.FailingConsumer~new
call assertTrue collector~subscribe(consumer),'consumer subscribed'
call assertTrue collector~subscribe(failingConsumer),'failing consumer subscribed'
collectorService=.InstrumentationCollectorService~new(collector)
transport=.InstrumentationLocalCollectorTransport~new(collectorService,'ed209a')
publisher=.InstrumentationPublisher~new('publisher-ed209a',service,transport,'noc-collector')

p1=publisher~publish('2026-10-08T08:00:00Z')
call assertTrue p1~ok,'first publication accepted'
call assertEq p1~receipt['code'],'ACCEPTED','first receipt code'
call assertEq p1~receipt['accepted'],1,'first accepted snapshot count'
call assertEq consumer~updates,1,'consumer notified'
call assertEq collector~consumerFailures,1,'consumer failure isolated from collector acceptance'

ref=.InstrumentationCodec~semanticRef(identity)
latest=collector~latestBySemanticRef(ref)
call assertTrue latest<>.nil,'latest semantic ref found'
call assertEq metric(latest,.InstrumentationVocabulary~QUEUE_DEPTH),3,'latest queue depth'

/* Returned observations are detached from collector authority. */
latest['health']='FAILED'
latest2=collector~latestBySemanticRef(ref)
call assertEq latest2['health'],'HEALTHY','collector state cannot be mutated by consumer'

ignore=emitter~gaugeSet(.InstrumentationVocabulary~QUEUE_DEPTH,7,'messages')
p2=publisher~publish('2026-10-08T08:00:05Z')
call assertTrue p2~ok,'second publication accepted'
call assertEq consumer~updates,2,'consumer notified twice'
series=collector~series(ref,.InstrumentationVocabulary~QUEUE_DEPTH)
call assertEq series~items,2,'two queue history points'
call assertEq series[1]['value'],3,'first queue history point'
call assertEq series[2]['value'],7,'second queue history point'

/* Exact replay is idempotent; same sequence under another id conflicts. */
replay=collector~accept(p2~publication)
call assertEq replay['status'],'OK','exact replay accepted'
call assertEq replay['code'],'REPLAY','exact replay code'
conflict=.InstrumentationCodec~copyValue(p2~publication)
conflict['publication_id']='other-id'
conflictReply=collector~accept(conflict)
call assertEq conflictReply['code'],'SEQUENCE_CONFLICT','sequence conflict rejected'
stale=collector~accept(p1~publication)
call assertEq stale['code'],'STALE_PUBLICATION','stale publication rejected'

anonymous=collectorService~handleFrom('',p2~publication)
call assertEq anonymous['status'],'DENIED','anonymous publication denied'
call assertEq anonymous['code'],'AUTHENTICATED_PEER_REQUIRED','anonymous publication denial code'

selector=.directory~new; selector['semantic_ref']=ref
q=.InstrumentationCodec~query('latest-q',selector,.array~new,'','',0,'LATEST',1)
qr=collectorService~handleFrom('noc-ui',q)
call assertEq qr['status'],'OK','collector latest query accepted'
call assertEq qr['payload']~items,1,'collector latest query count'
call assertEq metric(qr['payload'][1],.InstrumentationVocabulary~QUEUE_DEPTH),7,'collector latest query value'
seriesQuery=.InstrumentationCodec~query('series-q',selector,.array~of(.InstrumentationVocabulary~QUEUE_DEPTH),'','',0,'SERIES',10)
seriesReply=collectorService~handleFrom('noc-ui',seriesQuery)
call assertEq seriesReply['status'],'OK','collector series query accepted'
call assertEq seriesReply['payload'][1]['points']~items,2,'collector series query point count'
call assertEq seriesReply['payload'][1]['points'][2]['value'],7,'collector series query latest value'

say 'PASS continuous publication, replay fencing, history and consumer projection contract'
exit 0

metric: procedure
  use arg snapshot,name
  do sample over snapshot['samples']
    if sample['name']=name then return sample['value']
  end
  return 'NOT_FOUND'

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

::class TestConsumer public
::attribute updates get
::method init
  expose updates
  updates=0
::method instrumentationUpdated
  expose updates
  use strict arg publication,snapshots
  updates+=1
  return .true

::requires 'src/InstrumentationMesh.cls'

::class FailingConsumer public
::method instrumentationUpdated
  use strict arg publication,snapshots
  raise syntax 88.900 array('projection consumer deliberately failed')
