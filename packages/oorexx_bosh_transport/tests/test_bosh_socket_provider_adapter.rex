call main
exit 0
main:
  http=.FakeHttp~new
  bp=.BoshStreamProvider~new(http,.BoshFixedRequestIdSource~new(30001))
  ap=.RegisteredSocketAddressProvider~new
  addr=.BoshSocketAddress~new(.BoshEndpoint~new("https://example.test/bosh","example.test"),"xmpp.logical")
  ap~register("xmpp.logical",addr,.SocketRole~SENDER)
  sockets=.SocketProvider~new(ap)
  sockets~registerBinding("BOSH",.BoshSocketBinding~new(bp))
  c=sockets~sender("xmpp.logical")
  call assert c<>.nil,"SocketProvider selects BOSH sender"
  call assert c~address == addr,"exact BOSH address retained"
  call assert c~sendAll("<x/>")=4,"provider stream write semantics"
  call assert c~recv(5)="<repl","provider partial read"
  call assert c~recv(99)="y/>","provider tail retained"
  call assert c~close,"provider close"
  say "PASS BOSH optional SocketProvider adapter"
  return
assert: procedure
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return
::class FakeHttp subclass BoshHttpExchangeProvider
::method init; expose count; count=0
::method exchange
  expose count
  use strict arg uri, method, headers, body
  count+=1
  if count=1 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind' sid='S3'/>")
  if pos("type='terminate'",body)>0 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'/>")
  if pos("<x/>",body)>0 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><reply/></body>")
  return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'/>")
::requires "BoshSocketProviderAdapter.cls"
