call main
exit 0

main:
  address=.SocketAddresses~xtp("GRID.HTTP.API",.false,"api.example")
  resolver=.FakeResolver~new(address)
  provider=.FakeSocketProvider~new
  connector=.ApiSocketProviderConnector~new(provider,resolver)
  url=.ApiUrl~new("https://example.test/resource")
  request=.ApiRequest~new("r1","GET",url~absolute)
  carrier=connector~connect(url,.ApiHttpTransportConfig~new,request,.nil)

  call assertTrue carrier<>.nil,"carrier acquired"
  call assertTrue resolver~lastUrl == url,"resolver receives exact ApiUrl object"
  call assertTrue resolver~lastRequest == request,"resolver receives exact ApiRequest object"
  call assertTrue provider~lastAddress == address,"SocketProvider receives exact SocketAddress object"
  call assertTrue carrier~socketAddress == address,"carrier preserves exact SocketAddress object"

  call assertEq 5,carrier~send("HELLO"),"send byte count"
  call assertEq "HELLO",provider~stream~written,"write delegated through selected stream"
  provider~stream~incoming="WORLD"
  call assertEq 1,carrier~select(.array~of(carrier),.array~new,.array~new,1),"readiness delegated"
  call assertEq "WORLD",carrier~recv(5),"read delegated through selected stream"
  call assertEq 1,provider~stream~raw~pumpCount,"provider-native progress used"

  ignore=carrier~close
  call assertTrue provider~stream~closed,"close delegated"

  missing=.ApiSocketProviderConnector~new(provider,.FakeResolver~new(.nil))
  call assertTrue missing~connect(url,.ApiHttpTransportConfig~new,request,.nil)==.nil,"missing route fails closed"
  call assertEq "SOCKET_ROUTE_UNAVAILABLE",missing~lastError,"missing route error"

  provider2=.FakeSocketProvider~new(.false)
  noReady=.ApiSocketProviderConnector~new(provider2,.FakeResolver~new(address))
  call assertTrue noReady~connect(url,.ApiHttpTransportConfig~new,request,.nil)==.nil,"carrier without readiness fails closed"
  call assertEq "SOCKET_READINESS_UNAVAILABLE",noReady~lastError,"readiness error"
  call assertTrue provider2~stream~closed,"failed carrier is closed"

  say "PASS API Client SocketProvider carrier seam"
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

::class FakeResolver public
::method init
  expose address lastUrl lastRequest
  use strict arg address
  lastUrl=.nil; lastRequest=.nil
::attribute lastUrl get
::attribute lastRequest get
::method resolve
  expose address lastUrl lastRequest
  use strict arg url, request=.nil, session=.nil
  lastUrl=url; lastRequest=request
  return address

::class FakeSocketProvider public
::method init
  expose stream lastAddress readiness
  use strict arg readiness=.true
  stream=.FakeStream~new(readiness)
  lastAddress=.nil
::attribute stream get
::attribute lastAddress get
::method streamSenderAt
  expose stream lastAddress
  use strict arg address
  lastAddress=address
  stream~address=address
  return stream

::class FakeStream public
::method init
  expose raw incoming written closed address
  use strict arg readiness=.true
  if readiness then raw=.FakeRaw~new
  else raw=.FakeNoReadyRaw~new
  incoming=""; written=""; closed=.false; address=.nil
::attribute raw get
::attribute incoming get
::attribute incoming set
::attribute written get
::attribute closed get
::attribute address get
::attribute address set
::method socketAddress
  expose address
  return address
::method write
  expose written closed
  use strict arg bytes
  if closed then return .false
  written=written||bytes
  return .true
::method read
  expose incoming closed
  use strict arg maximumBytes
  if closed then return ""
  if incoming="" then return .nil
  n=maximumBytes
  if n>length(incoming) then n=length(incoming)
  out=left(incoming,n)
  incoming=substr(incoming,n+1)
  return out
::method close
  expose closed
  closed=.true
  return .true

::class FakeRaw public
::method init
  expose pumpCount
  pumpCount=0
::attribute pumpCount get
::method pump
  expose pumpCount
  use strict arg timeoutMs=0
  pumpCount+=1
  return 1

::class FakeNoReadyRaw public
::method noop
  return .true

::requires "ApiClientSocketProviderAdapter.cls"
