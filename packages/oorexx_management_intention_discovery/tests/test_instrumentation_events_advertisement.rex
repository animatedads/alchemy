host=.MachineFixture~new('ED209C')
service=.ServiceFixture~new('HERCULES-ED209C')
host~relations=.Array~of(.ManagementRelationship~new('host-service','RUNS_SERVICE',host,service,'SERVICE','service inventory'))
collector=.InstrumentationCollector~new(32)
identity=.InstrumentationCodec~identity('alchemy','hercules','HERCULES-ED209C','ED209C','','HERCULES')
ref=identity['semantic_ref']
bindings=.InstrumentationSemanticBindingRegistry~new
bindings~register(service,ref,.Array~of('HERCULES-ED209C'))
snapshot=.InstrumentationCodec~snapshot(identity,.InstrumentationHealth~HEALTHY,.Array~new,'2026-10-27T15:00:00Z',.Array~new,1)
contexts=.Array~of('change://CHG-42')
e1=.InstrumentationCodec~event('chg-open','CHANGE_WINDOW_OPENED',ref,'CHANGE_AUTHORITY','2026-10-27T15:00:00Z',.InstrumentationEventSeverity~NOTICE,'hercules-maint','','approved',.Array~new,.nil,.nil,.false,'',contexts)
e2=.InstrumentationCodec~event('svc-check','SERVICE_CHECKED',ref,'HERCULES_SERVICE','2026-10-27T15:00:00Z',.InstrumentationEventSeverity~INFO,'hercules-maint','','checked',.Array~new,.nil,.nil,.false,'chg-open',contexts)
e3=.InstrumentationCodec~event('nearby','UNRELATED_NOTICE',ref,'OTHER','2026-10-27T15:00:00Z',.InstrumentationEventSeverity~NOTICE,'','','same time only')
p=.InstrumentationCodec~publication('p1','hercules-publisher',1,.Array~of(snapshot),'2026-10-27T15:00:01Z',1793113201,.Array~new,.Array~of(e1,e2,e3))
call assertEqual 'OK',collector~accept(p)['status'],'publication accepted'
provider=.InstrumentationIntentionProvider~new(collector,bindings)
service~sources=.Array~of(.ManagementSelfAssessingIntentionSurfaceSource~new('instrumentation.management',provider))
machines=.MachineRegistry~new(.Array~of(host))
intentions=.ManagementIntentionDirectory~new
intentions~registerSource(.ManagementSelfAssessingIntentionSurfaceSource~new('machine.management',.ManagedMachineIntentionProvider~new(machines)))
objects=.AllObjects~new(.Array~of(host,service))
relations=.ManagementRelationshipDirectory~new
relations~registerSource(.ManagementRelationshipProviderSource~new('object.relationships',.ObjectPublishedRelationshipProvider~new(objects)))
explorer=.ManagementIntentionExplorer~new(intentions,relations)
context=.Directory~new
context['nowPosixSeconds']=1793113220
x=explorer~explore('what is ED209C and show correlation hercules-maint events',context,3)
call assertEqual 1,x~relevantAdvertisedCandidates~items,'instrumentation specialist transiently relevant'
c=x~relevantAdvertisedCandidates[1]
call assertEqual 3,c~surface['events']~items,'all retained events visible to specialist'
call assertEqual 1,c~surface['correlations']~items,'same-time unrelated event not inferred into correlation'
call assertEqual 2,c~surface['correlations'][1]['event_count'],'explicit correlation only'
call assertEqual 1,c~surface['correlations'][1]['causation_edges']~items,'producer causation retained'
call assertEqual .InstrumentationFreshness~FRESH,c~surface['freshness'][ref]['status'],'fresh publication reported'
call assertEqual .InstrumentationHealth~HEALTHY,c~surface['snapshots'][1]['health'],'health separately healthy'
context['nowPosixSeconds']=1793113400
x2=explorer~explore('what is ED209C and show correlation hercules-maint events',context,3)
c2=x2~relevantAdvertisedCandidates[1]
call assertEqual .InstrumentationFreshness~STALE,c2~surface['freshness'][ref]['status'],'later identical exploration sees stale publication'
call assertEqual .InstrumentationHealth~HEALTHY,c2~surface['snapshots'][1]['health'],'stale telemetry does not become service failure'
call assertEqual 1,intentions~sources~items,'instrumentation specialist remains transient'
say 'PASS test_instrumentation_events_advertisement'
exit 0
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
