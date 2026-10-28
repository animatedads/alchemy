call main
exit 0

main:
  /* Current topology: local Unix, secure remote TLS, ordinary TCP and XTP.
   * XTP is represented as an offer only; this probe never opens an XTP socket.
   */
  offers=.RegisteredSocketOfferProvider~new
  offers~register("queue.control",.SocketNegotiationOffer~new("unix-local",.SocketAddresses~unix("/run/rexxos/queue.sock"),10,"LOCAL",.true,"local service socket","unix"))
  offers~register("queue.control",.SocketNegotiationOffer~new("xtp-direct",.SocketAddresses~xtp("02:11:22:33:44:55"),20,"REMOTE",.true,"XTP route table says direct route exists","xtp"))
  offers~register("queue.control",.SocketNegotiationOffer~new("tls-ip",.SocketAddresses~tls("192.0.2.44",7443,"queue/control"),30,"REMOTE",.true,"TLS endpoint qualified","tls"))
  offers~register("queue.control",.SocketNegotiationOffer~new("tcp-ip",.SocketAddresses~tcp("192.0.2.44",7000),40,"REMOTE",.true,"TCP endpoint qualified","tcp"))

  n=.SocketNegotiator~new
  n~registerOfferProvider(offers)
  port=.SocketIntentionPort~new(n)

  intents=port~discover
  call assert intents~items=2,"generic discovery exposes negotiation/explanation only"

  /* Internal same-host request should take the local Unix socket. */
  req=.SocketNegotiationRequest~new("queue.control",.SocketRole~SENDER,.true,.false,.false,.false)
  scoped=port~discoverFor(req)
  call assert scoped~feasible,"request-scoped discovery is feasible"
  call assert scoped~hasIntention(.SocketIntentionName~OPEN),"OPEN is dynamically exposed for current sender capability"
  sel=port~negotiate(req)
  call assert sel~selected,"ordinary request selected"
  call assert sel~address~scheme="unix","local Unix preferred"

  /* Secure requirement eliminates Unix/XTP/TCP in current capability model. */
  secure=.SocketNegotiationRequest~new("queue.control",.SocketRole~SENDER,.true,.true,.false,.false)
  sel=port~negotiate(secure)
  call assert sel~selected,"secure request selected"
  call assert sel~address~scheme="tls","TLS selected for secure requirement"
  call assert sel~address~securityProfile="queue/control","TLS security profile retained"

  /* Multicast requirement selects the best currently implemented multicast
   * family.  In dev13 the broad XTP family reflects libxtp dev17 and may win
   * on priority; historical XTP profiles retain their original truth. */
  groupOffers=.RegisteredSocketOfferProvider~new
  groupOffers~register("fabric.discovery",.SocketNegotiationOffer~new("ip-multicast",.SocketAddresses~ipMulticast("239.255.42.30",47030),10,"REMOTE",.true,"RFC 3678 IPv4 multicast provider qualified","ip-multicast"))
  groupOffers~register("fabric.discovery",.SocketNegotiationOffer~new("xtp-group",.SocketAddresses~xtp("group:rexxos",.true),5,"REMOTE",.true,"XTP dev17 multicast route qualified","xtp"))
  groupOffers~register("fabric.discovery",.SocketNegotiationOffer~new("tcp-no-group",.SocketAddresses~tcp("198.51.100.7",7000),20,"REMOTE",.true,"ordinary TCP","tcp"))
  ng=.SocketNegotiator~new
  ng~registerOfferProvider(groupOffers)
  pg=.SocketIntentionPort~new(ng)
  groupReq=.SocketNegotiationRequest~new("fabric.discovery",.SocketRole~SENDER,.false,.false,.true,.false)
  sel=pg~negotiate(groupReq)
  call assert sel~selected,"multicast request selected"
  call assert sel~address~scheme="xtp","current XTP dev17 multicast route selected by priority"
  call assert sel~address~multicast,"selected XTP offer is explicitly multicast"

  /* Explicit policy may constrain the schemes Intentions permits. */
  allowed=.array~new; allowed~append("tls")
  constrained=.SocketNegotiationRequest~new("queue.control",.SocketRole~SENDER,.true,.false,.false,.false,allowed)
  sel=port~negotiate(constrained)
  call assert sel~selected,"scheme constrained request selected"
  call assert sel~address~scheme="tls","scheme constraint honoured"

  /* No hard requirement may be silently weakened. */
  impossible=.SocketNegotiationRequest~new("queue.control",.SocketRole~SENDER,.true,.true,.true,.false)
  sel=port~negotiate(impossible)
  call assert sel~status=.SocketNegotiationStatus~NO_OFFER,"incompatible requirements fail closed"
  call assert sel~rejected~items=4,"rejection evidence retained"

  say "PASS socket.intention/0.1"
  say "PASS socket.negotiation/0.1"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::requires "../src/SocketProvider.cls"
::requires "../src/SocketIntentions.cls"
