/* Relationship discovery/traversal is domain-published and Management-generic. */

host = .MachineFixture~new('ED209C')
hercules = .ServiceFixture~new('HERCULES-ED209C', 'HERCULES')
guest = .MachineFixture~new('ED209Z')
network = .NetworkFixture~new('ED209C-NET')

/* Relationships are authored by the domain objects, not Management. */
hercules~relations = .Array~of( -
  .ManagementRelationship~new('r1', 'RUNS_ON', hercules, host, 'HERCULES_SERVICES', 'service host'), -
  .ManagementRelationship~new('r2', 'HOSTS', hercules, guest, 'HERCULES_SERVICES', 'guest facade'))
host~relations = .Array~of( -
  .ManagementRelationship~new('r3', 'USES_NETWORK', host, network, 'MACHINE_AUTHORITY', 'host network'))

objects = .MutableObjectDiscoverer~new(.Array~of(host, hercules, guest, network))
provider = .ObjectPublishedRelationshipProvider~new(objects)
source = .ManagementRelationshipProviderSource~new('object.relationships', provider)
relationships = .ManagementRelationshipDirectory~new
relationships~registerSource(source)

s1 = relationships~discover(.Directory~new)
call assertEqual 3, s1~entries~items, 'three authored relationships discovered'
r1entry = findRelationship(s1, 'r1')
call assertTrue r1entry \== .nil, 'r1 relationship found'
call assertTrue r1entry~relationship~fromObject == hercules, 'from object identity preserved'
call assertTrue r1entry~relationship~toObject == host, 'to object identity preserved'
call assertEqual 'RUNS_ON', r1entry~relationship~kind, 'relationship kind preserved verbatim'
call assertEqual 'HERCULES_SERVICES', r1entry~relationship~authority, 'relationship authority preserved'

/* Traversal follows connectivity but does not manufacture reverse edges. */
e1 = relationships~expand(.Array~of(guest), .Directory~new, 3)
call assertEqual 4, e1~objects~items, 'guest reaches service host and network'
call assertTrue e1~contains(guest), 'seed retained'
call assertTrue e1~contains(hercules), 'guest reaches Hercules'
call assertTrue e1~contains(host), 'guest reaches host through Hercules'
call assertTrue e1~contains(network), 'guest reaches host network'
call assertEqual 0, e1~depthOf(guest), 'guest depth'
call assertEqual 1, e1~depthOf(hercules), 'Hercules depth'
call assertEqual 2, e1~depthOf(host), 'host depth'
call assertEqual 3, e1~depthOf(network), 'network depth'
call assertEqual 3, e1~edges~items, 'only authored edges retained'

e2 = relationships~expand(.Array~of(guest), .Directory~new, 1)
call assertEqual 2, e2~objects~items, 'depth bound stops at Hercules'
call assertTrue \e2~contains(host), 'host not reached beyond bound'

/* Fresh discovery: removing a relationship changes the next traversal. */
host~relations = .Array~new
e3 = relationships~expand(.Array~of(guest), .Directory~new, 3)
call assertEqual 3, e3~objects~items, 'removed network relation is not stale'
call assertTrue \e3~contains(network), 'network disappears after authority removes edge'

say 'PASS test_relationship_discovery'
exit 0


findRelationship: procedure
  use arg snapshot, wanted
  do entry over snapshot~entries
    if entry~relationship~id == wanted then return entry
  end
  return .nil

assertTrue: procedure
  use arg condition, label
  if \condition then do; say 'FAIL:' label; exit 1; end
return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return

::class RelationshipObject
::method init
  use arg id
  self~id = id
  self~name = id
  self~aliases = .Array~new
  self~relations = .Array~new
::attribute id
::attribute name
::attribute aliases
::attribute relations
::method managementRelationships
  use arg context=.nil
  return self~relations

::class MachineFixture subclass RelationshipObject
::class ServiceFixture subclass RelationshipObject
::method init
  use arg id, kind
  self~init:super(id)
  self~kind = kind
::attribute kind
::class NetworkFixture subclass RelationshipObject

::class MutableObjectDiscoverer
::method init
  use arg objects
  self~objects = objects
::attribute objects
::method discoverObjects
  use arg context=.nil
  return self~objects

::requires '../src/ManagementIntentionDiscovery.cls'
