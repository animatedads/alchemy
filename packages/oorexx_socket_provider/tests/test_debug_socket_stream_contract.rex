call main
exit 0
main:
  address=.SocketAddresses~tls("192.0.2.77",9443,"debug/prod","debug.target")
  raw=.FakeTransportSocket~new
  endpoint=.ProviderSocketConnection~new(raw,address)
  stream=endpoint~asStream
  call assert stream~socketAddress == address,"exact SocketAddress object identity preserved"
  call assert stream~write("ABC"),"WRITE delegates successfully"
  call assert raw~lastWrite="ABC","WRITE bytes unchanged"
  raw~queueRead("DEFG")
  call assert stream~read(2)="DE","first READ"
  call assert stream~read(2)="FG","second READ"
  call assert stream~pump(5),"PUMP safe fallback"
  call assert stream~close,"CLOSE returns boolean success"
  call assert \stream~isOpen,"stream closed"
  call assert raw~closed,"underlying endpoint closed"
  say "PASS debug selected-Socket READ/WRITE object contract"
  say "PASS exact SocketAddress identity preserved"
  return
assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return
::class FakeTransportSocket public
::method init
  expose lastWrite incoming closed
  lastWrite=""; incoming=""; closed=.false
::attribute lastWrite get
::attribute closed get
::method send
  expose lastWrite closed
  use strict arg bytes
  if closed then return -1
  lastWrite=bytes
  return length(bytes)
::method recv
  expose incoming closed
  use strict arg count
  if closed | incoming="" then return .nil
  n=count
  if n>length(incoming) then n=length(incoming)
  out=substr(incoming,1,n); incoming=substr(incoming,n+1)
  return out
::method queueRead
  expose incoming
  use strict arg bytes
  incoming=incoming||bytes
  return self
::method close
  expose closed
  closed=.true
  return 0
::requires "SocketProvider.cls"
