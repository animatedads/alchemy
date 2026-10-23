collector = .InstrumentationCollector~new(8)
identity = .InstrumentationCodec~identity('alchemy','queue','Q1','ED209A','','QUEUE')
ref = identity['semantic_ref']
do i = 1 to 3
  samples=.Array~of(.InstrumentationCodec~sample(.InstrumentationVocabulary~QUEUE_DEPTH,.InstrumentationMetricKind~GAUGE,'jobs',i*10,'2026-10-09T10:0'||i||':00Z'))
  snap=.InstrumentationCodec~snapshot(identity,.InstrumentationHealth~HEALTHY,samples,'2026-10-09T10:0'||i||':00Z',.Array~new,i)
  pub=.InstrumentationCodec~publication('queue-'||i,'queue-fixture',i,.Array~of(snap),'2026-10-09T10:0'||i||':00Z')
  ignore=collector~accept(pub)
end
read=.InstrumentationReadAuthority~new(collector)
call assertEqual 3, read~historyBySemanticRef(ref)~items, 'history preserved'
series=read~series(ref,.InstrumentationVocabulary~QUEUE_DEPTH)
call assertEqual 3, series~items, 'series projected'
call assertEqual 30, series[3]['value'], 'latest series value'
call assertEqual 1, read~latest~items, 'latest only one service snapshot'
say 'PASS test_instrumentation_history'
exit 0
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return
::requires '../src/InstrumentationIntentions.cls'
