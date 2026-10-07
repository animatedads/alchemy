call main
exit 0

main:
  port=39091
  ap=.RegisteredSocketAddressProvider~new
  ap~register("loop",.SocketAddresses~tcp("127.0.0.1",port))
  p=.SocketProvider~new(ap)
  p~registerBinding("TCP",.RxSockTcpBinding~new)
  listener=p~listener("loop",8)
  if listener=.nil then do; say "FAIL TCP listener"; exit 1; end
  worker=.TcpEchoWorker~new
  worker~run(listener)
  call SysSleep .1
  client=p~sender("loop")
  if client=.nil then do; say "FAIL TCP sender"; listener~close; exit 1; end
  if client~sendAll("PING"||"0a"x)<>5 then do; say "FAIL TCP send"; exit 1; end
  answer=client~recv(32)
  client~close; listener~close
  if answer<>"PONG"||"0a"x then do; say "FAIL TCP reply"; exit 1; end
  say "PASS real RxSock TCP provider"
  return
::class TcpEchoWorker public
::method run
  use strict arg listener
  reply
  peer=listener~accept
  if peer=.nil then return
  data=peer~recv(32)
  if data="PING"||"0a"x then ignore=peer~sendAll("PONG"||"0a"x)
  peer~close
  return

::requires "SocketProvider.cls"
::requires "RxSockSocketBinding.cls"
