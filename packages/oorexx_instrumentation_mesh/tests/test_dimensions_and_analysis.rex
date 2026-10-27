#!/usr/bin/env rexx
say 'INSTRUMENTATION DIMENSION / USAGE TEST START'

identity=.InstrumentationCodec~identity('alchemy','ldap-identity','peer-a','ed209a','','LDAP_IDENTITY')
emitter=.InstrumentationEmitter~new(identity)
emitter~setHealth(.InstrumentationHealth~HEALTHY)
peerA=.directory~new; peerA['peer_id']='peer-a'; peerA['status']='OK'
peerB=.directory~new; peerB['peer_id']='peer-b'; peerB['status']='OK'

ignore=emitter~counterAdd('identity.replication.acks.total',1,'count',peerA)
ignore=emitter~counterAdd('identity.replication.acks.total',1,'count',peerB)
ignore=emitter~counterAdd('identity.replication.acks.total',1,'count',peerA)
call assertEq emitter~counterValue('identity.replication.acks.total',peerA),2,'peer A counter retained independently'
call assertEq emitter~counterValue('identity.replication.acks.total',peerB),1,'peer B counter retained independently'

registry=.InstrumentationRegistry~new
registry~register('identity',emitter)
service=.InstrumentationService~new(registry)
collector=.InstrumentationCollector~new(8)
collectorService=.InstrumentationCollectorService~new(collector)
transport=.InstrumentationLocalCollectorTransport~new(collectorService,'ed209a')
publisher=.InstrumentationPublisher~new('publisher-ed209a',service,transport,'collector')
call assertTrue publisher~publish('2026-10-09T20:00:00Z')~ok,'first dimensional publication'

ignore=emitter~counterAdd('identity.replication.acks.total',3,'count',peerA)
ignore=emitter~counterAdd('identity.replication.acks.total',2,'count',peerB)
call assertTrue publisher~publish('2026-10-09T20:00:10Z')~ok,'second dimensional publication'

ref=.InstrumentationCodec~semanticRef(identity)
allSeries=collector~series(ref,'identity.replication.acks.total')
call assertEq allSeries~items,4,'nil dimensions select all dimensional series'
selector=.directory~new; selector['semantic_ref']=ref
query=.InstrumentationCodec~query('dim-series',selector,.array~of('identity.replication.acks.total'),'','',0,'SERIES',10)
reply=collectorService~handleFrom('noc-ui',query)
call assertEq reply['status'],'OK','remote dimensional series query'
call assertEq reply['payload'][1]['points']~items,4,'remote series preserves all dimensions'

seriesA=collector~series(ref,'identity.replication.acks.total',peerA)
call assertEq seriesA~items,2,'explicit dimension filter'
call assertEq seriesA[1]['value'],2,'peer A first value'
call assertEq seriesA[2]['value'],5,'peer A second value'

analyzer=.InstrumentationUsageAnalyzer~new(collector)
usage=analyzer~counterUsage(ref,'identity.replication.acks.total',0,10)
call assertEq usage~items,2,'usage grouped by dimensions'
ua=findUsage(usage,'peer-a')
ub=findUsage(usage,'peer-b')
call assertEq ua['delta'],3,'peer A reset-aware delta'
call assertEq ub['delta'],2,'peer B reset-aware delta'
call assertEq ua['per_second'],0.3,'peer A rate from supplied elapsed time'

say 'PASS dimensional counters, wildcard series and usage analysis'
exit 0

findUsage: procedure
  use arg usage,peerId
  do item over usage
    if item['dimensions']['peer_id']=peerId then return item
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

::requires 'src/InstrumentationMesh.cls'
::requires 'src/InstrumentationAnalysis.cls'
