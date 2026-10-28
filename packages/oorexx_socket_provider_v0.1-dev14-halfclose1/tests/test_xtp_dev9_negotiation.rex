call main
exit 0

main:
  xtpOffers=.XtpDev9SocketOfferProvider~new
  xtpOffers~register("fabric.control","xtp-unicast",.SocketAddresses~xtp("02:11:22:33:44:55"),10,"REMOTE",.true,"libxtp dev9 route available")
  xtpOffers~register("fabric.discovery","xtp-group",.SocketAddresses~xtp("group:rexxos",.true),10,"REMOTE",.true,"historical XTP group address; multicast not implemented by executable profile")

  fallback=.RegisteredSocketOfferProvider~new
  fallback~register("fabric.control",.SocketNegotiationOffer~new("tls-listener",.SocketAddresses~tls("192.0.2.70",7443,"fabric/control"),30,"REMOTE",.true,"TLS listener qualified","tls"))

  n=.SocketNegotiator~new
  n~registerOfferProvider(xtpOffers)
  n~registerOfferProvider(fallback)

  sender=.SocketNegotiationRequest~new("fabric.control",.SocketRole~SENDER,.true,.false,.false,.false)
  sel=n~negotiate(sender)
  call assert sel~selected,"XTP sender selected"
  call assert sel~address~scheme="xtp","sender uses XTP"
  call assert sel~offer~capabilities~sender,"XTP dev9 sender advertised"
  call assert \sel~offer~capabilities~listener,"XTP dev9 listener not advertised"

  listener=.SocketNegotiationRequest~new("fabric.control",.SocketRole~LISTENER,.true,.false,.false,.false)
  sel=n~negotiate(listener)
  call assert sel~selected,"listener falls back"
  call assert sel~address~scheme="tls","XTP rejected for listener and TLS selected"

  onlyXtp=.SocketNegotiator~new
  onlyXtp~registerOfferProvider(xtpOffers)
  sel=onlyXtp~negotiate(listener)
  call assert sel~status=.SocketNegotiationStatus~NO_OFFER,"XTP-only listener fails closed"
  call assert sel~rejected~items=1,"listener rejection retained"
  call assert sel~rejected[1]["reason"]="LISTENER_REQUIRED","listener rejection reason"

  group=.SocketNegotiationRequest~new("fabric.discovery",.SocketRole~SENDER,.true,.false,.true,.false)
  sel=onlyXtp~negotiate(group)
  call assert sel~status=.SocketNegotiationStatus~NO_OFFER,"XTP dev9 multicast fails closed"
  call assert sel~rejected[1]["reason"]="MULTICAST_REQUIRED","executable XTP profile does not advertise multicast"

  badGroup=.SocketNegotiationRequest~new("fabric.control",.SocketRole~SENDER,.true,.false,.true,.false)
  sel=onlyXtp~negotiate(badGroup)
  call assert sel~status=.SocketNegotiationStatus~NO_OFFER,"unicast XTP cannot satisfy multicast request"
  call assert sel~rejected[1]["reason"]="MULTICAST_REQUIRED","XTP current implementation capability fails closed"

  say "PASS XTP dev9 role-specific socket negotiation"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::requires "../src/SocketProvider.cls"
::requires "../src/SocketIntentions.cls"
