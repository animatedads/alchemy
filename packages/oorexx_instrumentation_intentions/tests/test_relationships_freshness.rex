identity=.InstrumentationCodec~identity('alchemy','queue','Q1','ED209A','','QUEUE')
ref=identity['semantic_ref']
peer='instrumentation://alchemy/queue/Q2@ED209B'
collector=.InstrumentationCollector~new(16)
snapshot=.InstrumentationCodec~snapshot(identity,.InstrumentationHealth~HEALTHY,.Array~new,'2026-10-27T15:00:00Z',.Array~new,1)
rel=.InstrumentationCodec~relationship('q1-q2','QUEUE_TRAFFIC_TO',ref,peer,'QUEUE_AUTHORITY','2026-10-27T15:00:00Z')
set=.InstrumentationCodec~relationshipSet('queue-peers','QUEUE_AUTHORITY',.true,.Array~of(rel),'2026-10-27T15:00:00Z','1')
p=.InstrumentationCodec~publication('p1','queue-publisher',1,.Array~of(snapshot),'2026-10-27T15:00:00Z',1793113200,.Array~of(set),.Array~new)
call assertEq 'OK',collector~accept(p)['status'],'publication accepted'
context=.Directory~new
context['nowPosixSeconds']=1793113220
context['freshWithinSeconds']=30
context['staleAfterSeconds']=120
provider=.InstrumentationIntentionProvider~new(collector)
s=provider~discover(context)
call assertEq 1,s['relationships']~items,'relationship visible'
call assertEq 'QUEUE_TRAFFIC_TO',s['relationships'][1]['kind'],'relationship authority retained'
call assertEq .InstrumentationFreshness~FRESH,s['freshness'][ref]['status'],'freshness visible independently of health'
context['nowPosixSeconds']=1793113400
s2=provider~discover(context)
call assertEq .InstrumentationHealth~HEALTHY,s2['snapshots'][1]['health'],'stale observation does not rewrite health'
call assertEq .InstrumentationFreshness~STALE,s2['freshness'][ref]['status'],'freshness independently stale'
say 'PASS test_relationships_freshness'
exit 0
assertEq: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return
::requires '../src/InstrumentationIntentions.cls'
