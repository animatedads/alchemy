call testCodec
call testSession
call testComposition
say "PASS: BOSH lower-layer logical stream qualification"
exit 0

testCodec:
  ep=.BoshEndpoint~new("https://cm.example.test/http-bind","example.test","en",45,1)
  xml=.BoshBodyCodec~createRequest(1001,ep)
  call assertTrue pos("rid='1001'",xml)>0,"initial RID"
  call assertTrue pos("to='example.test'",xml)>0,"target domain"
  call assertTrue pos("xmlns='http://jabber.org/protocol/httpbind'",xml)>0,"namespace"
  return

testSession:
  http=.FakeHttp~new
  ids=.BoshFixedRequestIdSource~new(9000001)
  ep=.BoshEndpoint~new("https://cm.example.test/http-bind","example.test")
  s=.BoshSession~new(ep,http,ids)
  call assertTrue s~open,"session open"
  call assertEq "S123",s~sid,"sid"
  call assertEq 9000001,s~rid,"initial rid"
  reply=s~send("<payload id='1'/>")
  call assertEq "<reply id='1'/>",reply,"send payload response"
  incoming=s~receive
  call assertEq "<incoming id='2'/>",incoming,"receive payload"
  call assertTrue s~terminate,"terminate"
  call assertEq .BoshState~CLOSED,s~state,"closed state"
  return

testComposition:
  /* The BOSH layer sees an HTTP exchange provider only.  This fake advertises
   * HTTPS carried by XTP to prove the layers compose without BOSH depending on
   * either TLS or XTP classes. */
  http=.FakeHttp~new("HTTPS","XTP")
  p=.BoshStreamProvider~new(http,.BoshFixedRequestIdSource~new(7000001))
  ep=.BoshEndpoint~new("https://cm.example.test/http-bind","example.test")
  stream=p~connect(ep)
  call assertTrue stream<>.nil,"provider connect"
  call assertEq "HTTPS",http~applicationCarrier,"HTTP carrier"
  call assertEq "XTP",http~underlay,"XTP underlay"
  call assertEq 4,stream~send("<x/>") ,"logical send bytes"
  call assertEq "<reply id='1'/>",stream~recv,"send response retained for receive"
  call assertTrue stream~close,"logical close"
  return

assertTrue: procedure
  use strict arg condition, label
  if \condition then do
    say "FAIL:" label
    exit 1
  end
  say "PASS" label
  return

assertEq: procedure
  use strict arg expected, actual, label
  if expected<>actual then do
    say "FAIL:" label "expected="expected "actual="actual
    exit 1
  end
  say "PASS" label
  return

::class FakeHttp subclass BoshHttpExchangeProvider
::method init
  expose count applicationCarrier underlay
  use strict arg applicationCarrier="HTTPS", underlay="TCP"
  count=0
  self~applicationCarrier=applicationCarrier
  self~underlay=underlay
::attribute applicationCarrier get
::attribute applicationCarrier set
::attribute underlay get
::attribute underlay set
::method exchange
  expose count
  use strict arg uri, method, headers, body
  count=count+1
  if count=1 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind' sid='S123' wait='30'/>")
  if pos("type='terminate'",body)>0 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind' type='terminate'/>")
  if pos("<payload",body)>0 | pos("<x/>",body)>0 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><reply id='1'/></body>")
  return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><incoming id='2'/></body>")

::requires "BoshTransport.cls"
