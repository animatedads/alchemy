call main
exit 0

main:
  offers=.RegisteredSocketOfferProvider~new
  addr=.SocketAddresses~tls("203.0.113.9",9443,"peer/service-a")
  offers~register("peer.a",.SocketNegotiationOffer~new("tls-a",addr,10,"REMOTE",.true,"qualified TLS","test"))

  n=.SocketNegotiator~new
  n~registerOfferProvider(offers)

  ap=.RegisteredSocketAddressProvider~new
  sockets=.SocketProvider~new(ap)
  fake=.FakeBinding~new
  sockets~registerBinding("TLS",fake)

  port=.SocketIntentionPort~new(n,sockets)
  req=.SocketNegotiationRequest~new("peer.a",.SocketRole~SENDER,.true,.true)
  openResult=port~open(req)

  call assert openResult~isA(.Directory),"open returns result directory when provider supplied"
  selection=openResult["selection"]
  handle=openResult["handle"]
  call assert selection~selected,"negotiation selected offer"
  call assert handle<>.nil,"socket provider acquired selected family"
  call assert handle~tag="TLS:203.0.113.9:9443","selected address passed to socket provider"
  call assert fake~senderCount=1,"one native acquisition"

  explain=port~explain(selection)
  call assert explain["offerId"]="tls-a","selection explainable"
  call assert pos("securityProfile=peer/service-a",explain["address"])>0,"security profile visible by reference"

  say "PASS Socket Intention -> negotiation -> SocketProvider acquisition"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::class FakeHandle public
::method init
  expose tag
  use strict arg tag
::attribute tag get

::class FakeBinding public subclass SocketTransportBinding
::method init
  expose senderCount
  senderCount=0
::attribute senderCount get
::method sender
  expose senderCount
  use strict arg address
  senderCount+=1
  return .FakeHandle~new(address~transport||":"||address~host||":"||address~port)
::method listener
  use strict arg address, backlog=32
  return .FakeHandle~new(address~transport||":LISTENER")

::requires "../src/SocketProvider.cls"
::requires "../src/SocketIntentions.cls"
