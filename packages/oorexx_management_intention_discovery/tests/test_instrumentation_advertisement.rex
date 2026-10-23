/* A related service advertises Instrumentation Intentions transiently.
 * Management gets fresh Mesh evidence without learning telemetry vocabulary or
 * gaining Instrumentation command authority. */
host = .MachineFixture~new('ED209C')
service = .ServiceFixture~new('HERCULES-ED209C')
host~relations = .Array~of(.ManagementRelationship~new('host-service','RUNS_SERVICE',host,service,'SERVICE','service inventory'))

collector = .InstrumentationCollector~new(16)
identity = .InstrumentationCodec~identity('alchemy','hercules','HERCULES-ED209C','ED209C','','HERCULES')
ref = identity['semantic_ref']
bindings = .InstrumentationSemanticBindingRegistry~new
bindings~register(service, ref, .Array~of('HERCULES-ED209C'))

samples = .Array~of(.InstrumentationCodec~sample(.InstrumentationVocabulary~BYTES_IN_TOTAL,.InstrumentationMetricKind~COUNTER,'bytes',4096,'2026-10-09T12:00:00Z'))
s1 = .InstrumentationCodec~snapshot(identity,.InstrumentationHealth~HEALTHY,samples,'2026-10-09T12:00:00Z',.Array~new,1)
p1 = .InstrumentationCodec~publication('hercules-1','hercules-publisher',1,.Array~of(s1),'2026-10-09T12:00:00Z')
ignore = collector~accept(p1)

instrumentationProvider = .InstrumentationIntentionProvider~new(collector,bindings)
instrumentationSource = .ManagementSelfAssessingIntentionSurfaceSource~new('instrumentation.management',instrumentationProvider)
service~sources = .Array~of(instrumentationSource)

machines = .MachineRegistry~new(.Array~of(host))
intentions = .ManagementIntentionDirectory~new
intentions~registerSource(.ManagementSelfAssessingIntentionSurfaceSource~new('machine.management',.ManagedMachineIntentionProvider~new(machines)))

objects = .AllObjects~new(.Array~of(host,service))
relations = .ManagementRelationshipDirectory~new
relations~registerSource(.ManagementRelationshipProviderSource~new('object.relationships',.ObjectPublishedRelationshipProvider~new(objects)))
relations~registerSource(.ManagementRelationshipProviderSource~new('instrumentation.relationships',.InstrumentationRelationshipProvider~new(instrumentationProvider)))
explorer = .ManagementIntentionExplorer~new(intentions,relations)

x = explorer~explore('what is ED209C and show telemetry health for HERCULES-ED209C',.Directory~new,3)
call assertEqual 1, x~resolution~relevantCandidates~items, 'machine remains only globally resolved specialist'
call assertEqual 1, x~relevantAdvertisedCandidates~items, 'instrumentation specialist discovered transiently'
c = x~relevantAdvertisedCandidates[1]
call assertEqual 'INSTRUMENTATION', c~assessment~authority, 'instrumentation authority retained'
call assertEqual .false, c~surface['mutating'], 'instrumentation intention surface is read-only'
call assertEqual .InstrumentationHealth~HEALTHY, c~surface['snapshots'][1]['health'], 'healthy Mesh snapshot visible'
call assertEqual ref, c~surface['snapshots'][1]['semantic_ref'], 'stable semantic ref retained'
call assertTrue c~assessment~evidence['objects'][1] == service, 'original service object retained in relevance evidence'
call assertTrue hasInstrumentationSnapshot(x~relatedObjects, ref), 'instrumentation snapshot becomes traversable evidence'
call assertEqual 1, intentions~sources~items, 'instrumentation specialist remains transient'

/* Same request after a later publication must see current health. */
s2 = .InstrumentationCodec~snapshot(identity,.InstrumentationHealth~DEGRADED,.Array~new,'2026-10-09T12:05:00Z',.Array~new,2)
p2 = .InstrumentationCodec~publication('hercules-2','hercules-publisher',2,.Array~of(s2),'2026-10-09T12:05:00Z')
ignore = collector~accept(p2)
x2 = explorer~explore('what is ED209C and show telemetry health for HERCULES-ED209C',.Directory~new,3)
c2 = x2~relevantAdvertisedCandidates[1]
call assertEqual .InstrumentationHealth~DEGRADED, c2~surface['snapshots'][1]['health'], 'fresh Mesh publication replaces stale health'

say 'PASS test_instrumentation_advertisement'
exit 0

hasInstrumentationSnapshot: procedure
  use arg objects, semanticRef
  do object over objects
    if object~isA(.Directory) then do
      if object~hasIndex('semantic_ref') then if object['semantic_ref'] == semanticRef then return .true
    end
  end
  return .false
assertTrue: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return

::class MachineFixture
::method init
  use arg id
  self~id=id; self~name=id; self~aliases=.Array~new; self~relations=.Array~new
::attribute id
::attribute name
::attribute aliases
::attribute relations
::method managementRelationships
  use arg context=.nil
  return self~relations

::class ServiceFixture
::method init
  use arg id
  self~id=id; self~name=id; self~aliases=.Array~new; self~relations=.Array~new; self~sources=.Array~new
::attribute id
::attribute name
::attribute aliases
::attribute relations
::attribute sources
::method managementRelationships
  use arg context=.nil
  return self~relations
::method managementIntentionSources
  use arg context=.nil
  return self~sources

::class MachineRegistry
::method init
  use arg objects
  self~objects=objects
::attribute objects
::method discoverMachines
  use arg context=.nil
  return self~objects

::class AllObjects
::method init
  use arg objects
  self~objects=objects
::attribute objects
::method discoverObjects
  use arg context=.nil
  return self~objects

::requires '../src/ManagementIntentionDiscovery.cls'
::requires '../src/MachineServiceIntentions.cls'
::requires 'InstrumentationIntentions.cls'
