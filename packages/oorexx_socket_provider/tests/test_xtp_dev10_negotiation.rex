call main
exit 0

main:
  xtpOffers=.XtpDev10SocketOfferProvider~new
  xtpOffers~register("fabric.control","xtp-unicast",.SocketAddresses~xtp("peer:ed209b"),10,"REMOTE",.true,"libxtp dev10 native sender/listener")
  xtpOffers~register("fabric.discovery","xtp-group",.SocketAddresses~xtp("group:rexxos",.true),10,"REMOTE",.true,"historical XTP group address; multicast not implemented by executable profile")

  fallback=.RegisteredSocketOfferProvider~new
  fallback~register("fabric.control",.SocketNegotiationOffer~new("tls-fallback",.SocketAddresses~tls("192.0.2.70",7443,"fabric/control"),30,"REMOTE",.true,"TLS qualified","tls"))

  n=.SocketNegotiator~new
  n~registerOfferProvider(xtpOffers)
  n~registerOfferProvider(fallback)

  sender=.SocketNegotiationRequest~new("fabric.control",.SocketRole~SENDER,.true,.false,.false,.false)
  sel=n~negotiate(sender)
  call assert sel~selected,"XTP dev10 sender selected"
  call assert sel~address~scheme="xtp","sender uses XTP"
  call assert sel~offer~capabilities~sender,"XTP dev10 sender advertised"
  call assert sel~offer~capabilities~listener,"XTP dev10 listener advertised"

  listener=.SocketNegotiationRequest~new("fabric.control",.SocketRole~LISTENER,.true,.false,.false,.false)
  sel=n~negotiate(listener)
  call assert sel~selected,"XTP dev10 listener selected"
  call assert sel~address~scheme="xtp","listener now uses XTP rather than TLS fallback"
  call assert sel~offer~providerId="xtp-dev10","listener selection is current XTP implementation"

  group=.SocketNegotiationRequest~new("fabric.discovery",.SocketRole~LISTENER,.true,.false,.true,.false)
  sel=n~negotiate(group)
  call assert sel~status=.SocketNegotiationStatus~NO_OFFER,"XTP dev10 multicast listener fails closed"
  call assert sel~rejected[1]["reason"]="MULTICAST_REQUIRED","current executable XTP profile does not advertise multicast"

  bad=.SocketNegotiationRequest~new("fabric.control",.SocketRole~LISTENER,.true,.false,.true,.false)
  sel=n~negotiate(bad)
  call assert sel~status=.SocketNegotiationStatus~NO_OFFER,"unicast XTP still cannot satisfy multicast listener"
  call assert sel~rejected[1]["reason"]="MULTICAST_REQUIRED","XTP implementation capability remains authoritative"

  /* Historical dev9 profile remains available and still fails closed for listener. */
  old=.XtpDev9SocketOfferProvider~new
  old~register("legacy.control","legacy-xtp",.SocketAddresses~xtp("peer:legacy"),10)
  n2=.SocketNegotiator~new
  n2~registerOfferProvider(old)
  legacy=.SocketNegotiationRequest~new("legacy.control",.SocketRole~LISTENER,.true,.false,.false,.false)
  sel=n2~negotiate(legacy)
  call assert sel~status=.SocketNegotiationStatus~NO_OFFER,"dev9 listener profile remains fenced"
  call assert sel~rejected[1]["reason"]="LISTENER_REQUIRED","dev9 listener rejection remains explicit"

  say "PASS XTP dev10 sender/listener socket negotiation"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::requires "../src/SocketProvider.cls"
::requires "../src/SocketIntentions.cls"
