/* test_halfclose_negotiation.rex - requireHalfCloseSend is a hard requirement.
 * Deterministic: offers only, no socket is opened.
 * Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
 */
call main
exit 0

main:
  offers=.RegisteredSocketOfferProvider~new
  /* XTP is given the better priority so that only the hard requirement,
   * not ranking, can explain the UNIX selection. */
  offers~register("gateway.egress",.SocketNegotiationOffer~new("xtp-direct",.SocketAddresses~xtp("02:11:22:33:44:55"),5,"REMOTE",.true,"XTP dev30 route","xtp"))
  offers~register("gateway.egress",.SocketNegotiationOffer~new("unix-local",.SocketAddresses~unix("/run/rexxos/gateway.sock"),50,"LOCAL",.true,"local service socket","unix"))
  n=.SocketNegotiator~new
  n~registerOfferProvider(offers)
  port=.SocketIntentionPort~new(n)

  /* Ten positional arguments: the last is requireHalfCloseSend. */
  need=.SocketNegotiationRequest~new("gateway.egress",.SocketRole~SENDER,.true,.false,.false,.false,.nil,"",.nil,.true)
  call assert need~requireHalfCloseSend==.true,"request keeps requireHalfCloseSend"
  sel=port~negotiate(need)
  call assert sel~selected,"half-close request selected"
  call assert sel~address~scheme="unix","UNIX selected: XTP dev30 cannot half-close"
  call assert rejectedWith(sel,"HALF_CLOSE_REQUIRED"),"XTP rejection reason recorded"

  /* Without the requirement, ordinary ranking is unchanged. */
  plain=.SocketNegotiationRequest~new("gateway.egress",.SocketRole~SENDER,.true,.false,.false,.false)
  call assert plain~requireHalfCloseSend==.false,"existing six-argument call defaults to false"
  sel=port~negotiate(plain)
  call assert sel~selected,"ordinary request selected"
  call assert sel~address~scheme="xtp","without the requirement the better-priority XTP offer wins"

  /* Only XTP offered: the requirement fails closed with NO_OFFER. */
  xtpOnly=.RegisteredSocketOfferProvider~new
  xtpOnly~register("gateway.egress",.SocketNegotiationOffer~new("xtp-direct",.SocketAddresses~xtp("02:11:22:33:44:55"),5,"REMOTE",.true,"XTP dev30 route","xtp"))
  nx=.SocketNegotiator~new
  nx~registerOfferProvider(xtpOnly)
  sel=.SocketIntentionPort~new(nx)~negotiate(need)
  call assert sel~status=.SocketNegotiationStatus~NO_OFFER,"half-close requirement never silently weakened"

  say "PASS socket.halfclose/0.1 negotiation"
  return

rejectedWith: procedure
  use strict arg selection, reason
  /* SocketNegotiator records each rejection as a Directory with "reason". */
  do item over selection~rejected
    if item["reason"]=reason then return .true
  end
  return .false

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::requires "SocketProvider.cls"
::requires "SocketIntentions.cls"
