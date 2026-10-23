collector = .InstrumentationCollector~new(16)
service = .ServiceFixture~new('HERCULES-ED209C')
identity = .InstrumentationCodec~identity('alchemy','hercules','ED209C','ED209C','','HERCULES')
ref = identity['semantic_ref']
bindings = .InstrumentationSemanticBindingRegistry~new
bindings~register(service, ref, .Array~of('HERCULES-ED209C'))

samples = .Array~new
samples~append(.InstrumentationCodec~sample(.InstrumentationVocabulary~BYTES_IN_TOTAL,.InstrumentationMetricKind~COUNTER,'bytes',128,'2026-10-09T10:00:00Z'))
s1 = .InstrumentationCodec~snapshot(identity,.InstrumentationHealth~HEALTHY,samples,'2026-10-09T10:00:00Z',.Array~new,1)
p1 = .InstrumentationCodec~publication('pub-1','fixture',1,.Array~of(s1),'2026-10-09T10:00:00Z')
r1 = collector~accept(p1)
call assertEqual 'OK', r1['status'], 'publication accepted'

provider = .InstrumentationIntentionProvider~new(collector, bindings)
surface = provider~discover(.Directory~new)
call assertEqual .false, surface['mutating'], 'surface is read-only'
call assertEqual 1, surface['snapshots']~items, 'latest snapshot discovered'
assessment = provider~assessRelevance('show telemetry health and metrics for HERCULES-ED209C', surface, .Directory~new)
call assertEqual .true, assessment~relevant, 'instrumentation request relevant'
call assertEqual 'INSTRUMENTATION', assessment~authority, 'authority preserved'
call assertEqual 1, assessment~evidence['objects']~items, 'bound authoritative object retained'
call assertTrue assessment~evidence['objects'][1] == service, 'object identity retained'
call assertEqual .InstrumentationHealth~HEALTHY, assessment~evidence['snapshots'][1]['health'], 'health retained'

surface['snapshots'][1]['health'] = 'CORRUPTED'
fresh = collector~latestBySemanticRef(ref)
call assertEqual .InstrumentationHealth~HEALTHY, fresh['health'], 'collector evidence is detached'

s2 = .InstrumentationCodec~snapshot(identity,.InstrumentationHealth~DEGRADED,.Array~new,'2026-10-09T10:01:00Z',.Array~new,2)
p2 = .InstrumentationCodec~publication('pub-2','fixture',2,.Array~of(s2),'2026-10-09T10:01:00Z')
ignore = collector~accept(p2)
surface2 = provider~discover(.Directory~new)
a2 = provider~assessRelevance('show telemetry health and metrics for HERCULES-ED209C', surface2, .Directory~new)
call assertEqual .InstrumentationHealth~DEGRADED, a2~evidence['snapshots'][1]['health'], 'fresh publication replaces stale latest state'

say 'PASS test_instrumentation_intentions'
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do; say 'FAIL:' label; exit 1; end
return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return

::class ServiceFixture
::method init
  use arg id
  self~id=id; self~name=id; self~aliases=.Array~new
::attribute id
::attribute name
::attribute aliases
::requires '../src/InstrumentationIntentions.cls'
