services = .ServiceRegistry~new
queue = .LogicalService~new('queue.control')
discovery = .LogicalService~new('rexxos.discovery')
services~services = .Array~of(queue, discovery)

addresses = .RegisteredSocketAddressProvider~new
addresses~register('queue.control', .SocketAddresses~tls('10.0.0.4', 7443, 'queue/control-prod', 'queue.control'))
addresses~register('rexxos.discovery', .SocketAddresses~xtp('group:rexxos-discovery', .true, 'rexxos.discovery'))

socketAuthority = .SocketProviderTransportAuthority~new(services, addresses)
peer = .PeerRef~new('ED209D')
l3 = .XTPRoute~l3('203.0.113.44', 20)
l4 = .XTPRoute~l4('udp', '203.0.113.44:43601', 30)
xtpAuthority = .XtpAuthority~new(.Array~of(.NetworkXtpPeerObservation~new(peer, .Array~of(l3,l4), l3, 'route-table-generation-7')))
provider = .NetworkTransportIntentionProvider~new(socketAuthority, xtpAuthority)

surface = provider~discover(.Directory~new)
call assertEqual 4, surface['socketObservations']~items, 'listener+sender observations preserved'
call assertEqual 1, surface['xtpObservations']~items, 'peer route observation'

queueSender = findObservation(surface['socketObservations'], queue, 'SENDER')
call assertTrue queueSender \== .nil, 'queue sender found'
call assertTrue queueSender~address == addresses~senderAddress('queue.control'), 'actual SocketAddress preserved by identity'
call assertEqual 'TLS', queueSender~address~transport, 'TLS transport'
call assertTrue queueSender~capabilities~secure, 'TLS secure capability comes from Socket Provider family'

discoverySender = findObservation(surface['socketObservations'], discovery, 'SENDER')
call assertTrue discoverySender~capabilities~multicast, 'XTP multicast capability comes from Socket Provider family'
call assertTrue surface['xtpObservations'][1]~routes[1] == l3, 'actual XTPRoute preserved by identity'
call assertTrue surface['xtpObservations'][1]~bestRoute == l3, 'preferred route comes from XTP authority'

assessment = provider~assessRelevance('why is queue.control using TLS', surface)
call assertTrue assessment~relevant, 'logical service transport request relevant'
call assertTrue containsIdentity(assessment~evidence['objects'], queue), 'service object retained in relevance evidence'

routeAssessment = provider~assessRelevance('what is the best XTP route to ED209D', surface)
call assertTrue routeAssessment~relevant, 'XTP route request relevant'
call assertTrue containsIdentity(routeAssessment~evidence['objects'], peer), 'peer object retained in relevance evidence'

unknown = provider~assessRelevance('show Fred latest failed compile', surface)
call assertTrue \unknown~relevant, 'unrelated domain remains irrelevant'

say 'PASS test_network_transport_intentions'
exit 0

findObservation: procedure
  use arg observations, service, role
  do o over observations
    if o~service == service & o~role == role then return o
  end
  return .nil

containsIdentity: procedure
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

::class LogicalService
::method init
  use arg logicalName
  self~logicalName=logicalName; self~id=logicalName; self~name=logicalName; self~aliases=.Array~new
::attribute logicalName
::attribute id
::attribute name
::attribute aliases

::class ServiceRegistry public subclass NetworkLogicalServiceRegistry
::method init
  self~services=.Array~new
::attribute services
::method discoverServices
  use arg context=.nil
  return self~services

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

::requires '../src/NetworkTransportIntentions.cls'
