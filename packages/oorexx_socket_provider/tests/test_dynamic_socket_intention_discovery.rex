/* test_dynamic_socket_intention_discovery.rex
 * Proves per-turn add/remove/fail-closed discovery.
 */
call main
exit 0

main:
  offers=.RegisteredSocketOfferProvider~new
  negotiator=.SocketNegotiator~new
  negotiator~registerOfferProvider(offers)
  port=.SocketIntentionPort~new(negotiator)
  dynamic=.SocketDynamicIntentionProvider~new(port)

  request=.SocketNegotiationRequest~new("queue.control","SENDER",.true,.false,.false,.false)

  /* Turn 1: Unix is present. */
  unix=.SocketAddresses~unix("/run/rexxos/queue.sock","queue.control")
  offers~register("queue.control",.SocketNegotiationOffer~new("unix-1",unix,10,"LOCAL",.true,"live unix endpoint","unix"))
  snap1=dynamic~discover(request)
  call assert snap1~feasible,"turn 1 feasible"
  call assert snap1~hasIntention(.SocketIntentionName~OPEN),"OPEN discovered when sender feasible"
  g1=snap1~generation

  /* Turn 2: endpoint disappears.  No startup cache may preserve OPEN. */
  call assert offers~remove("queue.control","unix-1"),"remove current offer"
  snap2=dynamic~discover(request)
  call assert snap2~generation>g1,"discovery generation advances"
  call assert \snap2~feasible,"turn 2 fails closed"
  call assert \snap2~hasIntention(.SocketIntentionName~OPEN),"OPEN removed when no current sender exists"

  /* Turn 3: secure TLS appears. */
  tls=.SocketAddresses~tls("192.0.2.44",9443,"queue/prod","queue.control")
  offers~register("queue.control",.SocketNegotiationOffer~new("tls-1",tls,20,"REMOTE",.true,"live tls endpoint","tls"))
  secure=.SocketNegotiationRequest~new("queue.control","SENDER",.true,.true,.false,.false)
  snap3=dynamic~discover(secure)
  call assert snap3~feasible,"turn 3 secure socket feasible"
  call assert snap3~hasIntention(.SocketIntentionName~OPEN),"OPEN rediscovered from current TLS evidence"

  /* Turn 4: same TLS endpoint cannot satisfy multicast. */
  multi=.SocketNegotiationRequest~new("queue.control","SENDER",.true,.true,.true,.false)
  snap4=dynamic~discover(multi)
  call assert \snap4~feasible,"multicast requirement fails closed"
  call assert \snap4~hasIntention(.SocketIntentionName~OPEN),"no false OPEN for incompatible current address"

  say "PASS dynamic per-turn socket intention discovery / add / remove / fail-closed"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::requires "SocketIntentions.cls"
