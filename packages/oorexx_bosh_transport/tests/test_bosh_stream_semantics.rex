call main
exit 0
main:
  http=.FakeHttp~new
  p=.BoshStreamProvider~new(http,.BoshFixedRequestIdSource~new(10001))
  stream=p~connect(.BoshEndpoint~new("https://example.test/bosh","example.test"))
  call assertEq 4,stream~send("<x/>"),"send returns byte count"
  call assertEq 1,stream~pendingBytes>0,"response buffered truthy"
  first=stream~recv(5)
  call assertEq "<repl",first,"partial read"
  call assertEq "y id='1'/>",stream~recv,"tail preserved"
  countAfterSend=http~count
  incoming=stream~recv(4)
  call assertEq "<inc",incoming,"poll partial"
  call assertEq "oming id='2'/>",stream~recv,"poll tail preserved"
  call assertEq countAfterSend+1,http~count,"one HTTP poll only"
  say "PASS BOSH logical stream buffering/no-loss semantics"
  return
assertEq: procedure
  use strict arg expected, actual, label
  if expected<>actual then do; say "FAIL:" label "expected="expected "actual="actual; exit 1; end
  say "PASS" label
  return
::class FakeHttp subclass BoshHttpExchangeProvider
::method init; expose count; count=0
::attribute count get
::method exchange
  expose count
  use strict arg uri, method, headers, body
  count+=1
  if count=1 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind' sid='S1'/>")
  if pos("<x/>",body)>0 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><reply id='1'/></body>")
  return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><incoming id='2'/></body>")
::requires "BoshTransport.cls"
