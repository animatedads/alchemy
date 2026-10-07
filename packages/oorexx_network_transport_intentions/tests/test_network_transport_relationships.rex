service = .LogicalService~new('queue.control')
services = .ServiceRegistry~new(.Array~of(service))
addresses = .RegisteredSocketAddressProvider~new
addresses~register('queue.control', .SocketAddresses~xtp('ED209D', .false, 'queue.control'))
peer = .PeerRef~new('ED209D')
route = .XTPRoute~l4('udp', '198.51.100.44:43601', 40)
xtp = .XtpAuthority~new(.Array~of(.NetworkXtpPeerObservation~new(peer, .Array~of(route), route, 'xtp evidence')))
provider = .NetworkTransportIntentionProvider~new(.SocketProviderTransportAuthority~new(services, addresses), xtp)
relations = .NetworkTransportRelationshipProvider~new(provider)~discoverRelationships(.Directory~new)
call assertEqual 3, relations~items, 'service address family and XTP route relationships'
call assertTrue hasKind(relations, 'USES_SOCKET_ADDRESS'), 'socket address edge'
call assertTrue hasKind(relations, 'USES_TRANSPORT_FAMILY'), 'family edge'
call assertTrue hasKind(relations, 'HAS_XTP_ROUTE'), 'XTP route edge'
call assertTrue relationTarget(relations, 'HAS_XTP_ROUTE') == route, 'actual XTPRoute relation target preserved'
say 'PASS test_network_transport_relationships'
exit 0

hasKind: procedure
  use arg relations, wanted
  do r over relations
    if r~kind == wanted then return .true
  end
  return .false
relationTarget: procedure
  use arg relations, wanted
  do r over relations
    if r~kind == wanted then return r~toObject
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
  use arg services
  self~services=services
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
