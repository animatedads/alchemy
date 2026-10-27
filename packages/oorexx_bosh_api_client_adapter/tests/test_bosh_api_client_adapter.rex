call main
exit 0

main:
  fake=.FakeApiClient~new
  adapter=.BoshApiClientExchangeProvider~new(fake)
  headers=.directory~new
  headers["content-type"]="text/xml; charset=utf-8"
  response=adapter~exchange("https://example.test/http-bind","POST",headers,"<body/>")
  call assertEq 200,response~statusCode,"status mapped"
  call assertEq "<body sid='S1'/>",response~body,"body mapped"
  call assertTrue fake~lastRequest~isA(.ApiRequest),"ApiRequest created"
  call assertEq "POST",fake~lastRequest~method,"method mapped"
  call assertEq "https://example.test/http-bind",fake~lastRequest~url,"url mapped"
  call assertEq "<body/>",fake~lastRequest~body,"body retained"
  call assertTrue fake~lastRequest~headers==headers,"headers object retained"
  call assertEq "HTTP/2",response~metadata["http_version"],"HTTP version evidence retained"
  call assertEq "https://example.test/http-bind",response~metadata["final_url"],"final URL retained"
  call assertEq 1,response~metadata["redirect_count"],"redirect count retained"

  denied=adapter~exchange("http://example.test/http-bind","POST",headers,"<body/>")
  call assertEq 0,denied~statusCode,"cleartext denied before API Client"
  call assertEq "CLEARTEXT_HTTP_DENIED",denied~metadata["api_client_error"],"cleartext denial code"
  call assertEq 1,fake~count,"denied request not dispatched"

  allowed=.BoshApiClientExchangeProvider~new(fake,.nil,"INTERACTIVE",50,1000000,1000000,"",.true)
  ok=allowed~exchange("http://example.test/test","GET",.directory~new,"")
  call assertEq 200,ok~statusCode,"explicit cleartext policy permits test request"
  call assertEq 2,fake~count,"permitted request dispatched"

  bad=adapter~exchange("ftp://example.test/x","GET",.directory~new,"")
  call assertEq "UNSUPPORTED_URI_SCHEME",bad~metadata["api_client_error"],"unsupported scheme rejected"
  call assertEq 2,fake~count,"unsupported request not dispatched"

  say "PASS BOSH API Client adapter shape/policy qualification"
  return

assertEq: procedure
  use strict arg expected,actual,label
  if expected<>actual then do
    say "FAIL:" label "expected="expected "actual="actual
    exit 1
  end
  say "PASS" label
  return

assertTrue: procedure
  use strict arg ok,label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  say "PASS" label
  return

::class FakeApiClient public
::method init
  expose count lastRequest
  count=0
  lastRequest=.nil
::attribute count get
::attribute lastRequest get
::method execute
  expose count lastRequest
  use strict arg request
  count+=1
  lastRequest=request
  h=.directory~new
  h["content-type"]="text/xml"
  return .ApiResponse~new(request~id,200,h,"<body sid='S1'/>",3,"",0,"node-a","session-a",request~url,"HTTP/2",1)

::requires "BoshApiClientAdapter.cls"
