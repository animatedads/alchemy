/* test_dynamic_xtp_capability_refresh.rex */
call main
exit 0

main:
  address=.SocketAddresses~xtp("peer:ed209d",.false,"fabric.discovery")
  request=.SocketNegotiationRequest~new("fabric.discovery","LISTENER",.true,.false,.false,.false)

  /* First turn: historical dev9 bridge => no listener intention. */
  n9=.SocketNegotiator~new
  p9=.XtpDev9SocketOfferProvider~new
  p9~register("fabric.discovery","xtp9",address,10,"LOCAL",.true)
  n9~registerOfferProvider(p9)
  d9=.SocketDynamicIntentionProvider~new(.SocketIntentionPort~new(n9))
  s9=d9~discover(request)
  call assert \s9~feasible,"dev9 listener unavailable"
  call assert \s9~hasIntention(.SocketIntentionName~LISTEN),"dev9 LISTEN hidden"

  /* Next turn/current deployment: dev10 bridge => listener appears. */
  n10=.SocketNegotiator~new
  p10=.XtpDev10SocketOfferProvider~new
  p10~register("fabric.discovery","xtp10",address,10,"LOCAL",.true)
  n10~registerOfferProvider(p10)
  d10=.SocketDynamicIntentionProvider~new(.SocketIntentionPort~new(n10))
  s10=d10~discover(request)
  call assert s10~feasible,"dev10 listener available"
  call assert s10~hasIntention(.SocketIntentionName~LISTEN),"dev10 LISTEN dynamically exposed"

  say "PASS dynamic XTP role capability refresh"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::requires "SocketIntentions.cls"
