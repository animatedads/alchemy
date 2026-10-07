/* Domain-owned machine/service intention surfaces with dynamic object discovery. */

machineA = .ManagedMachineFixture~new('ED209C', 'ed209c')
machineB = .ManagedMachineFixture~new('ED209I', 'ed209i')
serviceA = .ManagedServiceFixture~new('HERCULES-ED209C', 'Hercules', machineA)
serviceB = .ManagedServiceFixture~new('MCP-ED209C', 'MCP', machineA)

machineRegistry = .MutableMachineRegistry~new(.Array~of(machineA, machineB))
serviceRegistry = .MutableServiceRegistry~new(.Array~of(serviceA, serviceB))

machineProvider = .ManagedMachineIntentionProvider~new(machineRegistry)
serviceProvider = .ManagedServiceIntentionProvider~new(serviceRegistry)

directory = .ManagementIntentionDirectory~new
directory~registerSource(.ManagementSelfAssessingIntentionSurfaceSource~new('machine.management', machineProvider))
directory~registerSource(.ManagementSelfAssessingIntentionSurfaceSource~new('service.management', serviceProvider))

snapshot = directory~discover(.Directory~new)
call assertEqual 2, snapshot~entries~items, 'machine and service surfaces discovered'
call assertTrue snapshot~entries[1]~surface['machines'][1] == machineA, 'machine object identity preserved'
call assertTrue snapshot~entries[2]~surface['services'][1] == serviceA, 'service object identity preserved'

r1 = directory~resolve('what is the state of ED209C', .Directory~new)
call assertEqual 1, r1~relevantCandidates~items, 'named machine selects machine surface'
call assertEqual 'machine.management', r1~relevantCandidates[1]~entry~sourceId, 'machine source selected'
call assertTrue r1~relevantCandidates[1]~assessment~evidence['objects'][1] == machineA, 'matched machine retained by identity'

r2 = directory~resolve('is Hercules healthy', .Directory~new)
call assertEqual 1, r2~relevantCandidates~items, 'named service selects service surface'
call assertEqual 'service.management', r2~relevantCandidates[1]~entry~sourceId, 'service source selected'
call assertTrue r2~relevantCandidates[1]~assessment~evidence['objects'][1] == serviceA, 'matched service retained by identity'

r3 = directory~resolve('list machines and services', .Directory~new)
call assertEqual 2, r3~relevantCandidates~items, 'machine and service semantics compose'

/* Per-turn object discovery: remove ED209I, add ED209K without changing provider. */
machineK = .ManagedMachineFixture~new('ED209K', 'ed209k')
machineRegistry~machines = .Array~of(machineA, machineK)
s2 = directory~discover(.Directory~new)
call assertEqual 2, s2~entries[1]~surface['machines']~items, 'machine registry rediscovered'
call assertTrue s2~entries[1]~surface['machines'][2] == machineK, 'new machine visible by identity'
call assertTrue s2~entries[1]~surface['generation'] > snapshot~entries[1]~surface['generation'], 'machine surface generation advanced'

r4 = directory~resolve('state of ED209I', .Directory~new)
call assertEqual 0, r4~relevantCandidates~items, 'removed machine no longer routes by stale identity'
r5 = directory~resolve('state of ED209K', .Directory~new)
call assertEqual 1, r5~relevantCandidates~items, 'new machine routes immediately'

say 'PASS test_machine_service_surfaces'
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do; say 'FAIL:' label; exit 1; end
return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return

::class ManagedMachineFixture
::method init
  use arg id, alias
  self~id = id
  self~name = id
  self~aliases = .Array~of(alias)
::attribute id
::attribute name
::attribute aliases

::class ManagedServiceFixture
::method init
  use arg id, kind, host
  self~id = id
  self~name = id
  self~kind = kind
  self~host = host
  self~aliases = .Array~new
::attribute id
::attribute name
::attribute kind
::attribute host
::attribute aliases

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

::requires '../src/ManagementIntentionDiscovery.cls'
::requires '../src/MachineServiceIntentions.cls'
