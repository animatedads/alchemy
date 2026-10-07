/* Real Socket Provider + XTP object integration through the dev5 related-surface seam.
 * Management begins with a machine intention only.  A related service advertises
 * Network Transport Intentions for this exploration. */
host = .MachineFixture~new('ED209C')
queue = .LogicalService~new('queue.control')
host~relations = .Array~of(.ManagementRelationship~new('host-service', 'RUNS_SERVICE', host, queue, 'SERVICE', 'service inventory'))

services = .ServiceRegistry~new(.Array~of(queue))
addresses = .RegisteredSocketAddressProvider~new
addresses~register('queue.control', .SocketAddresses~tls('10.0.0.4', 7443, 'queue/control-prod', 'queue.control'))
peer = .PeerRef~new('ED209D')
l3 = .XTPRoute~l3('203.0.113.44', 20)
l4 = .XTPRoute~l4('udp', '203.0.113.44:43601', 40)
xtp = .XtpAuthority~new(.Array~of(.NetworkXtpPeerObservation~new(peer, .Array~of(l3,l4), l3, 'route authority generation 1')))
networkProvider = .NetworkTransportIntentionProvider~new(.SocketProviderTransportAuthority~new(services, addresses), xtp)
networkSource = .ManagementSelfAssessingIntentionSurfaceSource~new('network.transport.management', networkProvider)
queue~sources = .Array~of(networkSource)

machines = .MachineRegistry~new(.Array~of(host))
intentions = .ManagementIntentionDirectory~new
intentions~registerSource(.ManagementSelfAssessingIntentionSurfaceSource~new('machine.management', .ManagedMachineIntentionProvider~new(machines)))
call assertEqual 1, intentions~sources~items, 'network transport is not globally registered'

objects = .AllObjects~new(.Array~of(host, queue))
relations = .ManagementRelationshipDirectory~new
relations~registerSource(.ManagementRelationshipProviderSource~new('object.relationships', .ObjectPublishedRelationshipProvider~new(objects)))
/* The network domain may publish its own graph edges without Management interpreting them. */
relations~registerSource(.ManagementRelationshipProviderSource~new('network.transport.relationships', .NetworkTransportRelationshipProvider~new(networkProvider)))
explorer = .ManagementIntentionExplorer~new(intentions, relations)

x = explorer~explore('what transport does queue.control on ED209C use', .Directory~new, 4)
call assertEqual 1, x~resolution~relevantCandidates~items, 'base match is machine only'
call assertEqual 1, x~relevantAdvertisedCandidates~items, 'related service advertises relevant transport specialist'
c = x~relevantAdvertisedCandidates[1]
call assertEqual 'network.transport.management', c~sourceId, 'transport specialist source'
call assertEqual 'NETWORK_TRANSPORT', c~assessment~authority, 'transport authority preserved'
call assertTrue containsIdentity(c~assessment~evidence['objects'], queue), 'logical service preserved by identity'
call assertTrue hasRelatedClass(x~relatedObjects, 'SOCKETADDRESS'), 'SocketAddress becomes graph object'
call assertTrue hasRelatedClass(x~relatedObjects, 'SOCKETFAMILY'), 'SocketFamily becomes graph object'
call assertEqual 1, intentions~sources~items, 'advertised transport source remains transient'

/* Dynamic Socket Provider mapping: same request, same Management objects, new
 * authoritative address.  Fresh exploration must expose the changed transport. */
addresses~register('queue.control', .SocketAddresses~xtp('ED209D', .false, 'queue.control'))
x2 = explorer~explore('what transport does queue.control on ED209C use', .Directory~new, 4)
c2 = x2~relevantAdvertisedCandidates[1]
obs = c2~surface['socketObservations']
call assertTrue hasTransport(obs, 'XTP'), 'fresh exploration sees XTP remap'
call assertTrue \hasTransport(obs, 'TLS'), 'stale TLS mapping not retained'

say 'PASS test_network_transport_advertisement'
exit 0

hasTransport: procedure
  use arg observations, transport
  do o over observations
    if o~address~transport == transport then return .true
  end
  return .false
containsIdentity: procedure
  use arg objects, wanted
  do o over objects
    if o == wanted then return .true
  end
  return .false
hasRelatedClass: procedure
  use arg objects, className
  do o over objects
    if o~class~id == className then return .true
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

::class LogicalService
::method init
  use arg logicalName
  self~logicalName=logicalName; self~id=logicalName; self~name=logicalName; self~aliases=.Array~new; self~relations=.Array~new; self~sources=.Array~new
::attribute logicalName
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
::class ServiceRegistry public subclass NetworkLogicalServiceRegistry
::method init
  use arg services
  self~services=services
::attribute services
::method discoverServices
  use arg context=.nil
  return self~services
::class AllObjects
::method init
  use arg objects
  self~objects=objects
::attribute objects
::method discoverObjects
  use arg context=.nil
  return self~objects
::class PeerRef
::method init
  use arg id
  self~id=id; self~name=id; self~aliases=.Array~new
::attribute id
::attribute name
::attribute aliases
::class XtpAuthority public subclass NetworkXtpRouteAuthority
::method init
  use arg observations
  self~observations=observations
::attribute observations
::method discoverPeerRoutes
  use arg context=.nil
  return self~observations

::requires '../src/ManagementIntentionDiscovery.cls'
::requires '../src/MachineServiceIntentions.cls'
::requires 'NetworkTransportIntentions.cls'
