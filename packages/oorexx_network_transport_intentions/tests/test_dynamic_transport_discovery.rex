service = .LogicalService~new('queue.control')
services = .ServiceRegistry~new(.Array~of(service))
addresses = .RegisteredSocketAddressProvider~new
addresses~register('queue.control', .SocketAddresses~tcp('192.0.2.10',9000,'queue.control'))
xtp = .XtpAuthority~new(.Array~new)
provider = .NetworkTransportIntentionProvider~new(.SocketProviderTransportAuthority~new(services, addresses), xtp)

s1 = provider~discover(.Directory~new)
call assertEqual 'TCP', s1['socketObservations'][1]~address~transport, 'first discovery TCP'

/* Change the authoritative address mapping.  Same provider instance, fresh turn. */
addresses~register('queue.control', .SocketAddresses~xtp('ED209D',.false,'queue.control'))
s2 = provider~discover(.Directory~new)
call assertEqual 'XTP', s2['socketObservations'][1]~address~transport, 'second discovery sees changed transport'
call assertEqual 2, s2['generation'], 'fresh generation'

peer=.PeerRef~new('ED209D')
r4=.XTPRoute~l4('udp','198.51.100.44:43601',30)
xtp~observations=.Array~of(.NetworkXtpPeerObservation~new(peer,.Array~of(r4),r4,'generation-2'))
s3=provider~discover(.Directory~new)
call assertEqual 1, s3['xtpObservations']~items, 'fresh XTP route authority observed'
call assertTrue s3['xtpObservations'][1]~bestRoute == r4, 'authority-selected route preserved'

say 'PASS test_dynamic_transport_discovery'
exit 0

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
