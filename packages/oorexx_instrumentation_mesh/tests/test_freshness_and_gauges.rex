#!/usr/bin/env rexx
say 'INSTRUMENTATION FRESHNESS / DIMENSIONAL GAUGE TEST START'

identity=.InstrumentationCodec~identity('alchemy','nosqlserver','db-a','ed209a','MI-A1','DATABASE')
emitter=.InstrumentationEmitter~new(identity)
emitter~setHealth(.InstrumentationHealth~HEALTHY)
selectDims=.directory~new; selectDims['operation']='SELECT'
updateDims=.directory~new; updateDims['operation']='UPDATE'
ignore=emitter~gaugeSeriesSet('database.query.duration_seconds',0.25,'seconds',selectDims,.InstrumentationMetricKind~DISTRIBUTION)
ignore=emitter~gaugeSeriesSet('database.query.duration_seconds',0.75,'seconds',updateDims,.InstrumentationMetricKind~DISTRIBUTION)
call assertEq emitter~gaugeValue('database.query.duration_seconds',selectDims),0.25,'SELECT gauge retained independently'
call assertEq emitter~gaugeValue('database.query.duration_seconds',updateDims),0.75,'UPDATE gauge retained independently'

registry=.InstrumentationRegistry~new
registry~register('db',emitter)
service=.InstrumentationService~new(registry)
collector=.InstrumentationCollector~new(8)
collectorService=.InstrumentationCollectorService~new(collector)
transport=.InstrumentationLocalCollectorTransport~new(collectorService,'ed209a')
publisher=.InstrumentationPublisher~new('publisher-ed209a',service,transport,'collector')

published=publisher~publish('2026-10-10T07:00:00Z',1791615600)
call assertTrue published~ok,'publication with authoritative POSIX second accepted'
ref=.InstrumentationCodec~semanticRef(identity)
series=collector~series(ref,'database.query.duration_seconds')
call assertEq series~items,2,'collector retains both dimensional gauges'

freshness=.InstrumentationFreshnessAssessor~new(collector)
fresh=freshness~assess(ref,1791615615,30,120)
call assertEq fresh['status'],.InstrumentationFreshness~FRESH,'15 second publication is fresh'
call assertEq fresh['age_seconds'],15,'freshness age retained'
late=freshness~assess(ref,1791615660,30,120)
call assertEq late['status'],.InstrumentationFreshness~LATE,'60 second publication is late'
stale=freshness~assess(ref,1791615801,30,120)
call assertEq stale['status'],.InstrumentationFreshness~STALE,'201 second publication is stale'
future=freshness~assess(ref,1791615599,30,120)
call assertEq future['status'],.InstrumentationFreshness~UNKNOWN,'future publication time is not trusted'
call assertEq future['code'],'PUBLICATION_TIME_IN_FUTURE','future time reason explicit'

identity2=.InstrumentationCodec~identity('alchemy','smtp','smtp-a','ed209a','MI-A1','SMTP')
emitter2=.InstrumentationEmitter~new(identity2)
registry2=.InstrumentationRegistry~new; registry2~register('smtp',emitter2)
service2=.InstrumentationService~new(registry2)
publisher2=.InstrumentationPublisher~new('publisher-no-clock',service2,transport,'collector')
call assertTrue publisher2~publish('2026-10-10T07:00:00Z')~ok,'publication without numeric time remains valid'
unknown=freshness~assess(.InstrumentationCodec~semanticRef(identity2),1791615615,30,120)
call assertEq unknown['status'],.InstrumentationFreshness~UNKNOWN,'missing numeric time yields unknown freshness'
call assertEq unknown['code'],'NO_AUTHORITATIVE_PUBLICATION_TIME','missing time reason explicit'

say 'PASS dimensional gauges and authority-neutral publication freshness'
exit 0

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
