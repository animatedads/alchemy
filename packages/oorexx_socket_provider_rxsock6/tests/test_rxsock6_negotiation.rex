call main
exit 0

main:
  offers=.RegisteredSocketOfferProvider~new

  v4=.SocketAddresses~tcp("127.0.0.1",9000,"svc")
  v6=.RxSock6AddressFactory~tcp("::1",9000,"svc")

  offers~register("svc",.SocketNegotiationOffer~new("v4",v4,20,"LOCAL",.true,"IPv4 RxSock","rxsock"))
  offers~register("svc",.SocketNegotiationOffer~new("v6",v6,10,"LOCAL",.true,"IPv6 RxSock6","rxsock6"))

  n=.SocketNegotiator~new
  n~registerOfferProvider(offers)

  request=.SocketNegotiationRequest~new("svc","SENDER",.true,.false,.false,.false)
  selection=n~negotiate(request)

  call assert selection~selected,"TCP semantic request selected"
  call assert selection~address~scheme="tcp","selected scheme remains tcp"
  call assert selection~address~addressFamily="INET6","better current offer may be IPv6"
  call assert selection~address~nativeAddress~isInstanceOf(.Inet6Address),"Inet6Address not flattened"

  say "PASS TCP semantic negotiation across INET and INET6"
  return

assert:
  use strict arg ok,label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  return

::requires "SocketProvider.cls"
::requires "socket6.cls"
::requires "RxSock6SocketBinding.cls"
::requires "SocketIntentions.cls"
