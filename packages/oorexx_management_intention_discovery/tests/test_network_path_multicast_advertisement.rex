/* Management remains domain-blind while a related service advertises the
 * current Network Transport specialist.  The specialist carries NORM/XTP
 * transport objects, independent path evidence and Spiral 1 COTS witnesses. */
host = .MachineFixture~new('ED209C')
peer = .PeerRef~new('ED209D')
replication = .LogicalService~new('replication.multicast')
host~relations = .Array~of(.ManagementRelationship~new('host-service','RUNS_SERVICE',host,replication,'SERVICE','service inventory'))

services = .ServiceRegistry~new(.Array~of(replication))
addresses = .RegisteredSocketAddressProvider~new
normAddress = .SocketAddresses~norm('232.10.10.10',47001,'eth0','192.0.2.7',42,'replication.multicast')
addresses~register('replication.multicast', normAddress)

configuredRoute = .XTPRoute~l3('203.0.113.44',10)
xtp = .XtpAuthority~new(.Array~of(.NetworkXtpPeerObservation~new(peer,.Array~of(configuredRoute),configuredRoute,'route generation 11')))
rawPath = .NetworkPathEvidenceObservation~new(host,peer,3,'raw36','NO_RESPONSE_OR_FILTERED','2026-10-07T01:27:00Z','field matrix','XTP_FIELD_MATRIX')
udpPath = .NetworkPathEvidenceObservation~new(host,peer,4,'udp','PASS','2026-10-07T01:27:01Z','field matrix','XTP_FIELD_MATRIX')
paths = .PathAuthority~new(.Array~of(rawPath,udpPath))
igmpWitness = .NetworkCotsInterfaceObservation~new('RFC 3376','IGMPv3 source-filtered group membership',normAddress,'Socket Provider multicast binding','NORM/native multicast implementation','ACCESS_CONTRACT','spiral-1 witness')
cots = .CotsAuthority~new(.Array~of(igmpWitness))

networkProvider = .NetworkTransportIntentionProvider~new(.SocketProviderTransportAuthority~new(services,addresses),xtp,paths,cots)
networkSource = .ManagementSelfAssessingIntentionSurfaceSource~new('network.transport.management',networkProvider)
replication~sources = .Array~of(networkSource)

machines = .MachineRegistry~new(.Array~of(host))
intentions = .ManagementIntentionDirectory~new
intentions~registerSource(.ManagementSelfAssessingIntentionSurfaceSource~new('machine.management',.ManagedMachineIntentionProvider~new(machines)))
objects = .AllObjects~new(.Array~of(host,replication,peer))
relations = .ManagementRelationshipDirectory~new
relations~registerSource(.ManagementRelationshipProviderSource~new('object.relationships',.ObjectPublishedRelationshipProvider~new(objects)))
relations~registerSource(.ManagementRelationshipProviderSource~new('network.transport.relationships',.NetworkTransportRelationshipProvider~new(networkProvider)))
explorer = .ManagementIntentionExplorer~new(intentions,relations)

x = explorer~explore('show NORM multicast transport and path evidence for replication.multicast on ED209C',.Directory~new,5)
call assertEqual 1, x~resolution~relevantCandidates~items, 'base resolution remains machine only'
call assertEqual 1, x~relevantAdvertisedCandidates~items, 'network specialist advertised transiently'
c = x~relevantAdvertisedCandidates[1]
call assertEqual 'NETWORK_TRANSPORT', c~assessment~authority, 'network authority preserved'
call assertEqual 2, c~surface['pathEvidenceObservations']~items, 'path evidence visible'
call assertEqual 'NO_RESPONSE_OR_FILTERED', c~surface['pathEvidenceObservations'][1]~status, 'ambiguous raw36 evidence retained'
call assertEqual 'PASS', c~surface['pathEvidenceObservations'][2]~status, 'UDP pass retained'
call assertEqual 1, c~surface['cotsInterfaceObservations']~items, 'COTS witness visible'
call assertTrue hasTransport(c~surface['socketObservations'],'NORM'), 'NORM address projected'
call assertTrue hasRelatedIdentity(x~relatedObjects,normAddress), 'NORM SocketAddress is traversable graph object'
call assertTrue hasRelatedIdentity(x~relatedObjects,rawPath), 'path evidence is traversable graph object'
call assertTrue hasRelatedIdentity(x~relatedObjects,peer), 'path target remains authoritative object'
call assertTrue hasRelatedIdentity(x~relatedObjects,igmpWitness), 'COTS witness is traversable graph object'
call assertEqual 1, intentions~sources~items, 'network specialist remains transient'

/* Same objects/request, changed observing authority: a later raw36 probe passes.
 * Management must not retain the earlier ambiguous status. */
rawPath2 = .NetworkPathEvidenceObservation~new(host,peer,3,'raw36','PASS','2026-10-07T14:00:00Z','field matrix rerun','XTP_FIELD_MATRIX')
paths~observations = .Array~of(rawPath2,udpPath)
x2 = explorer~explore('show NORM multicast transport and path evidence for replication.multicast on ED209C',.Directory~new,5)
c2 = x2~relevantAdvertisedCandidates[1]
call assertEqual 'PASS', c2~surface['pathEvidenceObservations'][1]~status, 'fresh path evidence replaces stale observation'

say 'PASS test_network_path_multicast_advertisement'
exit 0

hasTransport: procedure
  use arg observations, transport
  do o over observations
    if o~address~transport == transport then return .true
  end
  return .false
hasRelatedIdentity: procedure
  use arg objects, wanted
  do o over objects
    if o == wanted then return .true
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
::class PathAuthority public subclass NetworkPathEvidenceAuthority
::method init
  use arg observations
  self~observations=observations
::attribute observations
::method discoverPathEvidence
  use arg context=.nil
  return self~observations
::class CotsAuthority public subclass NetworkCotsInterfaceAuthority
::method init
  use arg observations
  self~observations=observations
::attribute observations
::method discoverInterfaces
  use arg context=.nil
  return self~observations
::requires '../src/ManagementIntentionDiscovery.cls'
::requires '../src/MachineServiceIntentions.cls'
::requires 'NetworkTransportIntentions.cls'
