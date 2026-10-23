call main
exit 0

main:
  http=.CaptureHttp~new
  attrs=.directory~new
  attrs["xmlns:upper"]="urn:example:upper"
  attrs["upper:version"]="1.0"
  p=.BoshStreamProvider~new(http,.BoshFixedRequestIdSource~new(41001))
  stream=p~connect(.BoshEndpoint~new("https://example.test/bind","example.test"),attrs)
  call assertTrue stream<>.nil,"connect with upper binding attributes"
  call assertContains http~bodies[1],"xmlns:upper='urn:example:upper'","opaque namespace attribute"
  call assertContains http~bodies[1],"upper:version='1.0'","opaque version attribute"
  call assertEq "<features/>",stream~recv,"initial response payload retained"

  restart=.directory~new
  restart["upper:restart"]="true"
  incoming=stream~session~exchange("",restart)
  call assertEq "<restarted/>",incoming,"opaque session exchange payload"
  call assertContains http~bodies[2],"upper:restart='true'","opaque restart attribute"

  signal on syntax name reservedCaught
  bad=.directory~new; bad["sid"]="INJECTED"
  ignore=.BoshBodyCodec~sessionRequest(5,"REAL","","",bad)
  signal off syntax
  say "FAIL: reserved attribute replacement not rejected"
  exit 1
reservedCaught:
  signal off syntax
  say "PASS reserved BOSH attribute replacement rejected"
  say "PASS BOSH upper-protocol extension seam"
  return

assertTrue: procedure
  use strict arg condition,label
  if \condition then do; say "FAIL:" label; exit 1; end
  say "PASS" label
  return
assertEq: procedure
  use strict arg expected,actual,label
  if expected<>actual then do; say "FAIL:" label "expected="expected "actual="actual; exit 1; end
  say "PASS" label
  return
assertContains: procedure
  use strict arg haystack,needle,label
  if pos(needle,haystack)=0 then do; say "FAIL:" label "missing="needle; exit 1; end
  say "PASS" label
  return

::class CaptureHttp subclass BoshHttpExchangeProvider
::method init
  expose bodies count
  bodies=.array~new; count=0
::attribute bodies get
::method exchange
  expose bodies count
  use strict arg uri,method,headers,body
  count+=1; bodies~append(body)
  if count=1 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind' sid='U1'><features/></body>")
  return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><restarted/></body>")

::requires "BoshTransport.cls"
