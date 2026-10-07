call main
exit 0
main:
  address=.SocketAddresses~xtp("debug-peer",.false,"debug.target")
  raw=.FakeTransportSocket~new
  endpoint=.ProviderSocketConnection~new(raw,address)
  stream=endpoint~asStream
  transport=.DebugSocketTransport~new(stream,address)
  call assert transport~socketObject == stream,"Debug preserves exact selected Socket object"
  call assert transport~socketAddress == address,"Debug preserves exact SocketAddress"
  call assert transport~write("HELLO"),"Debug WRITE"
  call assert raw~lastWrite="HELLO","bytes reach native endpoint"
  raw~queueRead("WORLD")
  call assert transport~read(5)="WORLD","Debug READ"
  call assert transport~close,"Debug CLOSE"
  call assert raw~closed,"native endpoint closed"
  say "PASS actual DebugSocketTransport v0.1-dev3 -> SocketStreamAdapter"
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
::requires "DebugSocketTransport.cls"
