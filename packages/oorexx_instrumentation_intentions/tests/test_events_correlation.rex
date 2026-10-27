identity=.InstrumentationCodec~identity('alchemy','deployment','DEPLOY-1','ED209C','','DEPLOYMENT')
ref=identity['semantic_ref']
collector=.InstrumentationCollector~new(32)
contexts=.Array~of('change://CHG-42')
e1=.InstrumentationCodec~event('change-open','CHANGE_WINDOW_OPENED',ref,'CHANGE_AUTHORITY','2026-10-27T15:00:00Z',.InstrumentationEventSeverity~NOTICE,'deploy-42','','approved',.Array~new,.nil,.nil,.false,'',contexts)
e2=.InstrumentationCodec~event('deploy-start','OPERATION_STARTED',ref,'DEPLOYMENT_AUTHORITY','2026-10-27T15:00:00Z',.InstrumentationEventSeverity~INFO,'deploy-42','release-42','start',.Array~new,.nil,.nil,.false,'change-open',contexts)
e3=.InstrumentationCodec~event('same-time','UNRELATED_NOTICE',ref,'OTHER_AUTHORITY','2026-10-27T15:00:00Z',.InstrumentationEventSeverity~NOTICE,'','','same time only')
p=.InstrumentationCodec~publication('p1','fixture',1,.Array~new,'2026-10-27T15:00:01Z',1793113201,.Array~new,.Array~of(e1,e2,e3))
r=collector~accept(p)
call assertEq 'OK',r['status'],'publication accepted'
provider=.InstrumentationIntentionProvider~new(collector)
s=provider~discover(.Directory~new)
call assertEq 3,s['events']~items,'events exposed'
call assertEq 1,s['correlations']~items,'only explicit correlation forms group'
g=s['correlations'][1]
call assertEq 'deploy-42',g['correlation_id'],'correlation retained'
call assertEq 2,g['event_count'],'uncorrelated same-time event excluded'
call assertEq 1,g['causation_edges']~items,'declared causation retained'
call assertTrue g['causation_edges'][1]['resolved_in_retained_group'],'declared cause resolves'
a=provider~assessRelevance('show correlation deploy-42 events',s,.Directory~new)
call assertTrue a~relevant,'correlation request relevant'
call assertEq 1,a~evidence['correlations']~items,'matching correlation evidence retained'
s['events'][1]['kind']='CORRUPTED'
call assertEq 'CHANGE_WINDOW_OPENED',collector~eventsHistory[1]['kind'],'returned event graph detached'
say 'PASS test_events_correlation'
exit 0
assertTrue: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
return
assertEq: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return
::requires '../src/InstrumentationIntentions.cls'
