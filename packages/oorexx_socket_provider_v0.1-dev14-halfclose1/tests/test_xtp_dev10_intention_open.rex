call main
exit 0

main:
  addresses=.RegisteredSocketAddressProvider~new
  sockets=.SocketProvider~new(addresses)
  backend=.FakeXtpBackend~new
  sockets~registerBinding("XTP",.RexxXtpSocketBinding~new(backend))

  offers=.XtpDev10SocketOfferProvider~new
  offers~register("fabric.control","xtp-native",.SocketAddresses~xtp("peer:ed209b"),10)
  n=.SocketNegotiator~new
  n~registerOfferProvider(offers)
  port=.SocketIntentionPort~new(n,sockets)

  req=.SocketNegotiationRequest~new("fabric.control",.SocketRole~LISTENER,.true,.false,.false,.false)
  result=port~open(req,.nil,23)
  sel=result["selection"]
  handle=result["handle"]
  call assert sel~selected,"Intention selected XTP listener"
  call assert handle~tag="XTP-LISTENER:peer:ed209b:23","SocketProvider acquired selected XTP listener"

  req=.SocketNegotiationRequest~new("fabric.control",.SocketRole~SENDER,.true,.false,.false,.false)
  result=port~open(req)
  call assert result["handle"]~tag="XTP-SENDER:peer:ed209b","SocketProvider acquired selected XTP sender"

  say "PASS XTP dev10 Intention -> SocketProvider acquisition"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::class FakeHandle
::method init
  expose tag
  use strict arg tag
::attribute tag get

::class FakeXtpBackend
::method sender
  use strict arg address
  return .FakeHandle~new("XTP-SENDER:"||address~xtpAddress)
::method listener
  use strict arg address, backlog=32
  return .FakeHandle~new("XTP-LISTENER:"||address~xtpAddress||":"||backlog)

::requires "../src/SocketProvider.cls"
::requires "../src/SocketIntentions.cls"
