call main
exit 0
main:
  a=.SocketAddresses~xtp("02:AA:BB:CC:DD:EE",.false,"debug.xtp")
  raw=.FakeXtpSocket~new
  ep=.ProviderSocketConnection~new(raw,a)
  stream=ep~asStream
  call assert stream~address == a,"XTP opaque SocketAddress retained"
  call assert stream~write("X"),"XTP-shaped sender exposes WRITE"
  raw~queueRead("Y")
  call assert stream~read(1)="Y","XTP-shaped accepted endpoint exposes READ"
  say "PASS XTP provider endpoint -> standard debug stream shape"
  return
assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return
::class FakeXtpSocket public
::method init
  expose incoming
  incoming=""
::method send
  use strict arg bytes
  return length(bytes)
::method recv
  expose incoming
  use strict arg count
  if incoming="" then return .nil
  out=substr(incoming,1,count); incoming=substr(incoming,count+1)
  return out
::method queueRead
  expose incoming
  use strict arg bytes
  incoming=incoming||bytes
  return self
::method close
  return 0
::requires "SocketProvider.cls"
