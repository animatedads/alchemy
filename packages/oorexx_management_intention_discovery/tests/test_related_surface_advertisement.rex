/* Related objects advertise specialist intention surfaces for this exploration.
 * Management neither understands nor permanently registers those domains. */
host = .MachineFixture~new('ED209C')
guest = .MachineFixture~new('ED209Z')
hercules = .ServiceFixture~new('HERCULES-ED209C', host)
network = .NetworkFixture~new('ED209C-NET')

guest~relations = .Array~of(.ManagementRelationship~new('r1', 'GUEST_OF', guest, hercules, 'HERCULES', 'guest mapping'))
hercules~relations = .Array~of(.ManagementRelationship~new('r2', 'RUNS_ON', hercules, host, 'HERCULES', 'host mapping'))
host~relations = .Array~of(.ManagementRelationship~new('r3', 'USES_NETWORK', host, network, 'MACHINE', 'network mapping'))

/* These specialists are owned by the related objects, not by Management. */
herculesProvider = .OpaqueSpecialistProvider~new('hercules.intentions/0.1', 'HERCULES', 'HERCULES', hercules)
networkProvider = .OpaqueSpecialistProvider~new('network.intentions/0.1', 'NETWORK', 'NETWORK', network)
hercules~sources = .Array~of(.ManagementSelfAssessingIntentionSurfaceSource~new('hercules.management', herculesProvider))
network~sources = .Array~of(.ManagementSelfAssessingIntentionSurfaceSource~new('network.management', networkProvider))

registry = .MachineRegistry~new(.Array~of(host, guest))
machineProvider = .ManagedMachineIntentionProvider~new(registry)
intentions = .ManagementIntentionDirectory~new
intentions~registerSource(.ManagementSelfAssessingIntentionSurfaceSource~new('machine.management', machineProvider))
call assertEqual 1, intentions~sources~items, 'only machine is globally registered'

objects = .AllObjects~new(.Array~of(host, guest, hercules, network))
relations = .ManagementRelationshipDirectory~new
relations~registerSource(.ManagementRelationshipProviderSource~new('object.relationships', .ObjectPublishedRelationshipProvider~new(objects)))
explorer = .ManagementIntentionExplorer~new(intentions, relations)

/* The request starts with a machine match but also mentions specialist domains.
 * Traversal discovers those objects, which advertise their own surfaces. */
x = explorer~explore('what is ED209Z and is HERCULES network healthy', .Directory~new, 3)
call assertEqual 1, x~resolution~relevantCandidates~items, 'base resolution remains machine only'
call assertEqual 2, x~relevantAdvertisedCandidates~items, 'two related specialist surfaces become relevant'
call assertTrue selfHasSource(x~relevantAdvertisedCandidates, 'hercules.management'), 'Hercules specialist advertised'
call assertTrue selfHasSource(x~relevantAdvertisedCandidates, 'network.management'), 'network specialist advertised'
call assertEqual 1, intentions~sources~items, 'advertised specialists were not globally registered'

/* Dynamic advertisement is per-turn. Remove the network advertisement and the
 * next exploration must not retain it. */
network~sources = .Array~new
x2 = explorer~explore('what is ED209Z and is HERCULES network healthy', .Directory~new, 3)
call assertEqual 1, x2~relevantAdvertisedCandidates~items, 'stale related surface not retained'
call assertTrue selfHasSource(x2~relevantAdvertisedCandidates, 'hercules.management'), 'remaining specialist still present'

say 'PASS test_related_surface_advertisement'
exit 0

selfHasSource: procedure
  use arg candidates, wanted
  do c over candidates
    if c~sourceId == wanted then return .true
  end
  return .false

assertTrue: procedure
  use arg condition, label
  if \condition then do; say 'FAIL:' label; exit 1; end
return
assertEqual: procedure
  use arg expected, actual, label
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
  use arg id, host
  self~id=id; self~name=id; self~kind='HERCULES'; self~host=host; self~aliases=.Array~new; self~relations=.Array~new; self~sources=.Array~new
::attribute id
::attribute name
::attribute kind
::attribute host
::attribute aliases
::attribute relations
::attribute sources
::method managementRelationships
  use arg context=.nil
  return self~relations
::method managementIntentionSources
  use arg context=.nil
  return self~sources

::class NetworkFixture
::method init
  use arg id
  self~id=id; self~name=id; self~relations=.Array~new; self~sources=.Array~new
::attribute id
::attribute name
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

/* Test specialist whose vocabulary/object semantics are deliberately outside Management. */
::class OpaqueSpecialistProvider
::method init
  use arg providerId, authority, cue, object
  self~providerIdValue=providerId; self~authorityValue=authority; self~cue=cue; self~object=object; self~generation=0
::attribute providerIdValue
::attribute authorityValue
::attribute cue
::attribute object
::attribute generation
::method discover
  use arg context=.nil
  self~generation += 1
  s=.Directory~new
  s['provider']=self~providerIdValue; s['authority']=self~authorityValue; s['generation']=self~generation; s['object']=self~object; s['mutating']=.false
  return s
::method assessRelevance
  use arg request, surface, context=.nil
  matched = pos(self~cue, translate(request)) > 0
  evidence=.Directory~new; evidence['objects']=.Array~of(self~object); evidence['surface']=surface
  if matched then return .ManagementRelevanceAssessment~new(.true, 90, self~authorityValue, 'SPECIALIST_MATCH', evidence)
  return .ManagementRelevanceAssessment~new(.false, 0, self~authorityValue, 'SPECIALIST_UNKNOWN', evidence)

::requires '../src/ManagementIntentionDiscovery.cls'
::requires '../src/MachineServiceIntentions.cls'
