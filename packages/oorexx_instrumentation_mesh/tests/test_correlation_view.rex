#!/usr/bin/env rexx
say 'INSTRUMENTATION CORRELATION VIEW TEST START'

identity=.InstrumentationCodec~identity('alchemy','deployment','deploy-a','ed209a','MI-A1','DEPLOYMENT')
serviceRef=.InstrumentationCodec~semanticRef(identity)
changeRef='change://CHG-42'
correlationId='deploy-42'
contexts=.array~of(changeRef)

changeObserver=.InstrumentationEventObserver~new(identity,'CHANGE_AUTHORITY')
call assertTrue changeObserver~record('change-open','CHANGE_WINDOW_OPENED',.InstrumentationEventSeverity~NOTICE,'2026-10-11T19:00:00Z',correlationId,'','','approved change window',.array~new,contexts),'change event recorded'

ops=.InstrumentationOperationObserver~new(identity,'DEPLOYMENT_AUTHORITY')
ops~ready
ops~started('release-42','PREPARE',4,'steps','start deploy','2026-10-11T19:00:00Z',correlationId,'change-open',contexts)
ops~failed('release-42',2,4,'steps','verification failed','2026-10-11T19:00:00Z',correlationId,'operation:release-42:STARTED',contexts)

/* Same timestamp and subject, but no correlation id: must never be joined by
 * temporal/spatial inference. */
call assertTrue changeObserver~record('nearby-unrelated','UNRELATED_NOTICE',.InstrumentationEventSeverity~NOTICE,'2026-10-11T19:00:00Z','','','','same instant only'),'uncorrelated event recorded'

registry=.InstrumentationRegistry~new
registry~register('change',changeObserver)
registry~register('deployment',ops)
service=.InstrumentationService~new(registry)
collector=.InstrumentationCollector~new(40)
transport=.InstrumentationLocalCollectorTransport~new(.InstrumentationCollectorService~new(collector),'ed209a')
publisher=.InstrumentationPublisher~new('ed209a-correlation',service,transport,'noc')
call assertTrue publisher~publish('2026-10-11T19:00:01Z',1791741601)~ok,'correlated publication accepted'

view=.InstrumentationCorrelationView~new(collector)
groups=view~groups
call assertEq groups~items,1,'only explicit correlation id forms group'
g=groups[1]
call assertEq g['schema'],.InstrumentationContract~CORRELATION_SCHEMA,'correlation schema'
call assertEq g['basis'],'EXPLICIT_CORRELATION_ID','group basis explicit'
call assertEq g['ordering'],'COLLECTOR_ACCEPTANCE_ORDER','ordering is acceptance order'
call assertEq g['correlation_id'],correlationId,'correlation id preserved'
call assertEq g['event_count'],3,'three explicitly correlated events'
call assertEq g['source_event_count'],3,'all source events'
call assertEq g['derived_event_count'],0,'no derived event promoted into group'
call assertEq g['severity'],.InstrumentationEventSeverity~ERROR,'worst presentation severity'
call assertEq g['context_refs']~items,1,'one change context'
call assertEq g['context_refs'][1],changeRef,'change context preserved'
call assertEq g['authorities']~items,2,'two source authorities retained'
call assertEq g['causation_edges']~items,2,'producer supplied causation retained'
call assertTrue g['causation_edges'][1]['resolved_in_retained_group'],'change cause resolves'
call assertTrue g['causation_edges'][2]['resolved_in_retained_group'],'operation cause resolves'
call assertEq g['first_event_id'],g['events'][1]['event_id'],'first id follows collector acceptance order'
call assertEq g['last_event_id'],g['events'][g['events']~items]['event_id'],'last id follows collector acceptance order'

byId=view~byId(correlationId)
call assertEq byId['event_count'],3,'lookup by correlation id'
byContext=view~forContext(changeRef)
call assertEq byContext~items,1,'lookup by explicit context ref'
byService=view~forRefs(.array~of(serviceRef))
call assertEq byService~items,1,'lookup by subject ref'

selector=.directory~new; selector['context_ref']=changeRef
call assertEq collector~eventsHistory(selector,0)~items,3,'event selector matches context ref'

/* Backward compatibility: dev7 event/1 records have no causation_id or
 * context_refs fields.  dev8 accepts them as valid additive-schema input. */
legacy=.InstrumentationCodec~event('legacy-event','LEGACY',serviceRef,'LEGACY_AUTHORITY','2026-10-11T19:00:02Z',.InstrumentationEventSeverity~INFO,'legacy-corr')
legacy~remove('causation_id'); legacy~remove('context_refs')
legacyPublication=.InstrumentationCodec~publication('legacy-pub','legacy-publisher',1,.array~new,'2026-10-11T19:00:02Z',1791741602,.array~new,.array~of(legacy))
legacyReceipt=collector~accept(legacyPublication)
call assertEq legacyReceipt['status'],'OK','dev7 additive event accepted'
call assertEq view~byId('legacy-corr')['event_count'],1,'legacy correlated event remains readable'

say 'PASS explicit correlation/causation/context grouping without temporal inference or authority transfer'
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

::requires 'InstrumentationMesh.cls'
::requires 'InstrumentationServiceAdapters.cls'
::requires 'InstrumentationCorrelation.cls'
