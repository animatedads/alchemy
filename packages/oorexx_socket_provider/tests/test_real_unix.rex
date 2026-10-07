call main
exit 0

main:
  path="/tmp/oorexx-socket-provider-"||random(10000,99999)||".sock"
  ap=.RegisteredSocketAddressProvider~new
  ap~register("loop",.SocketAddresses~unix(path))
  p=.SocketProvider~new(ap)
  p~registerBinding("UNIX",.RexxUnixSocketBinding~new)
  listener=p~listener("loop",8)
  if listener=.nil then do; say "FAIL UNIX listener"; exit 1; end
  reply serverThread listener
  call SysSleep .1
  client=p~sender("loop")
  if client=.nil then do; say "FAIL UNIX sender"; listener~close; exit 1; end
  ignore=client~sendAll("PING"||"0a"x)
  answer=client~recv(32)
  client~close; listener~close
  if answer<>"PONG"||"0a"x then do; say "FAIL UNIX reply"; exit 1; end
  say "PASS real Unix Socket provider"
  return
serverThread:
  use strict arg listener
  peer=listener~accept
  if peer=.nil then return
  data=peer~recv(32)
  if data="PING"||"0a"x then ignore=peer~sendAll("PONG"||"0a"x)
  peer~close
  return
::requires "SocketProvider.cls"
::requires "UnixSocketBinding.cls"
