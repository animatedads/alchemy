call main
exit 0

main:
  group=.SocketAddresses~ipMulticast('239.255.42.20',47020,'spiral1.ipmcast')
  call assert group~transport=.SocketTransportKind~UDP,'IP multicast transport is UDP'
  call assert group~scheme=.SocketScheme~UDP,'IP multicast scheme is udp'
  call assert group~addressFamily=.SocketAddressFamily~INET,'IP multicast address family is INET'
  call assert group~multicast,'IP multicast endpoint marked multicast'
  call assert group~family~capabilities~multicast,'UDP family advertises multicast capability'
  call assert \group~family~capabilities~stream,'UDP family does not claim stream'

  unicast=.SocketAddresses~udp('192.0.2.20',47020,'spiral1.udp')
  call assert \unicast~multicast,'ordinary UDP endpoint remains unicast'

  request=.SocketMulticastMembershipRequest~new(group,'eth7','198.51.100.7','site-a')
  backend=.FakeIpMulticastBackend~new
  provider=.SocketSelector~new(.RegisteredSocketAddressProvider~new~register('spiral1.ipmcast',group))
  provider~registerBinding(.SocketTransportKind~UDP,.RexxUdpSocketBinding~new(backend))

  membership=provider~joinAt(group,request)
  call assert membership<>.nil,'UDP multicast join returned membership'
  call assert membership~address==group,'exact SocketAddress identity retained'
  call assert membership~interfaceName='eth7','interface retained'
  call assert membership~sourceAddress='198.51.100.7','source filter retained'
  call assert membership~scope='site-a','scope retained'
  call assert backend~joinCount=1,'one backend join'
  call assert membership~descriptor=71,'membership descriptor routed to backend'

  listener=provider~listenerOn(membership)
  call assert listener<>.nil,'listener attached to explicit membership'
  call assert listener~close=0,'listener close succeeds'
  call assert membership~joined,'listener close does not leave membership'
  call assert backend~leaveCount=0,'listener lifetime independent of membership'
  call assert membership~leave,'explicit membership leave succeeds'
  call assert backend~leaveCount=1,'backend leave exactly once'
  call assert provider~listenerOn(membership)=.nil,'left membership cannot create listener'
  call assert provider~joinAt(unicast)=.nil,'unicast UDP cannot be joined as multicast'

  offers=.RegisteredSocketOfferProvider~new
  offers~register('spiral1.group',.SocketNegotiationOffer~new('udp-mcast',group,10,'REMOTE',.true,'RFC 3678 IPv4 multicast provider','ip-multicast'))
  offers~register('spiral1.group',.SocketNegotiationOffer~new('udp-unicast',unicast,5,'REMOTE',.true,'ordinary UDP','udp'))
  negotiator=.SocketNegotiator~new
  negotiator~registerOfferProvider(offers)
  req=.SocketNegotiationRequest~new('spiral1.group',.SocketRole~SENDER,.false,.false,.true)
  selected=negotiator~negotiate(req)
  call assert selected~selected,'multicast UDP offer selected'
  call assert selected~address==group,'selected exact multicast address object'
  call assert selected~rejected~items=1,'unicast UDP rejected for multicast request'
  call assert selected~rejected[1]['reason']='MULTICAST_ADDRESS_REQUIRED','unicast rejection reason retained'

  say 'PASS UDP/IP multicast SocketProvider + membership + negotiation contract'
  return

assert:
  use strict arg ok, why
  if \ok then do
    say 'FAIL' why
    exit 1
  end
  return

::class FakeIpMulticastBackend
::method init
  expose joinCount leaveCount
  joinCount=0; leaveCount=0
::attribute joinCount get
::attribute leaveCount get
::method join
  expose joinCount
  use strict arg address, request
  joinCount+=1
  return .FakeIpMulticastMembership~new(self,address,request)
::method listenerOn
  use strict arg nativeMembership,address,backlog=32
  return .FakeIpMulticastListener~new(nativeMembership,address)
::method listener
  use strict arg address,backlog=32
  return .nil
::method sender
  use strict arg address
  return .nil
::method recordLeave
  expose leaveCount
  leaveCount+=1
  return 0

::class FakeIpMulticastMembership
::method init
  expose owner address request joined
  use strict arg owner,address,request
  joined=.true
::method descriptor
  expose joined
  if joined then return 71
  return -1
::method leave
  expose owner joined
  if \joined then return 0
  joined=.false
  return owner~recordLeave

::class FakeIpMulticastListener
::method init
  expose membership address closed
  use strict arg membership,address
  closed=.false
::method accept
  return .nil
::method close
  expose closed
  closed=.true
  return 0

::requires 'SocketProvider.cls'
::requires 'SocketIntentions.cls'
