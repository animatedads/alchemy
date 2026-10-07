/* A specialist matches the seed; generic Management traverses published graph. */
host = .ManagedMachineFixture~new('ED209C', 'ed209c')
guest = .ManagedMachineFixture~new('ED209Z', 'ed209z')
hercules = .ManagedServiceFixture~new('HERCULES-ED209C', 'HERCULES', host)
network = .RelatedFixture~new('ED209C-NET')

/* Add domain-published relationship methods via fixture fields. */
guest~relations = .Array~of(.ManagementRelationship~new('g1', 'GUEST_OF', guest, hercules, 'HERCULES_SERVICES', 'guest mapping'))
hercules~relations = .Array~of(.ManagementRelationship~new('g2', 'RUNS_ON', hercules, host, 'HERCULES_SERVICES', 'host mapping'))
host~relations = .Array~of(.ManagementRelationship~new('g3', 'USES_NETWORK', host, network, 'MACHINE_AUTHORITY', 'network mapping'))

machineRegistry = .MutableMachineRegistry~new(.Array~of(host, guest))
serviceRegistry = .MutableServiceRegistry~new(.Array~of(hercules))
machineProvider = .ManagedMachineIntentionProvider~new(machineRegistry)
serviceProvider = .ManagedServiceIntentionProvider~new(serviceRegistry)
intentions = .ManagementIntentionDirectory~new
intentions~registerSource(.ManagementSelfAssessingIntentionSurfaceSource~new('machine.management', machineProvider))
intentions~registerSource(.ManagementSelfAssessingIntentionSurfaceSource~new('service.management', serviceProvider))

objectDiscoverer = .CombinedDiscoverer~new(machineRegistry, serviceRegistry, network)
relationshipProvider = .ObjectPublishedRelationshipProvider~new(objectDiscoverer)
relationshipDirectory = .ManagementRelationshipDirectory~new
relationshipDirectory~registerSource(.ManagementRelationshipProviderSource~new('managed.object.relationships', relationshipProvider))

explorer = .ManagementIntentionExplorer~new(intentions, relationshipDirectory)
x = explorer~explore('what is the state of ED209Z', .Directory~new, 3)
call assertEqual 1, x~resolution~relevantCandidates~items, 'machine specialist owns original request'
call assertTrue x~matchedObjects[1] == guest, 'guest is original matched authoritative object'
call assertEqual 4, x~relatedObjects~items, 'generic graph fans out guest to service host and network'
call assertTrue x~relationshipExpansion~contains(hercules), 'Hercules reached without Management knowing GUEST_OF'
call assertTrue x~relationshipExpansion~contains(host), 'host reached without Management knowing RUNS_ON'
call assertTrue x~relationshipExpansion~contains(network), 'network reached without Management knowing USES_NETWORK'

say 'PASS test_relationship_intention_explorer'
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do; say 'FAIL:' label; exit 1; end
return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return

::class RelatedFixture
::method init
  use arg id
  self~id = id; self~name = id; self~aliases = .Array~new; self~relations = .Array~new
::attribute id
::attribute name
::attribute aliases
::attribute relations
::method managementRelationships
  use arg context=.nil
  return self~relations

::class ManagedMachineFixture
::method init
  use arg id, alias
  self~id = id; self~name = id; self~aliases = .Array~of(alias); self~relations = .Array~new
::attribute id
::attribute name
::attribute aliases
::attribute relations
::method managementRelationships
  use arg context=.nil
  return self~relations

::class ManagedServiceFixture
::method init
  use arg id, kind, host
  self~id = id; self~name = id; self~kind = kind; self~host = host; self~aliases = .Array~new; self~relations = .Array~new
::attribute id
::attribute name
::attribute kind
::attribute host
::attribute aliases
::attribute relations
::method managementRelationships
  use arg context=.nil
  return self~relations

::class MutableMachineRegistry
::method init
  use arg machines
  self~machines = machines
::attribute machines
::method discoverMachines
  use arg context=.nil
  return self~machines

::class MutableServiceRegistry
::method init
  use arg services
  self~services = services
::attribute services
::method discoverServices
  use arg context=.nil
  return self~services

::class CombinedDiscoverer
::method init
  use arg machines, services, network
  self~machines = machines; self~services = services; self~network = network
::attribute machines
::attribute services
::attribute network
::method discoverObjects
  use arg context=.nil
  out = .Array~new
  do o over self~machines~discoverMachines(context); out~append(o); end
  do o over self~services~discoverServices(context); out~append(o); end
  out~append(self~network)
  return out

::requires '../src/ManagementIntentionDiscovery.cls'
::requires '../src/MachineServiceIntentions.cls'
