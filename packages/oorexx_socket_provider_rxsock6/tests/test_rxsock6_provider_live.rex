/* Real IPv6 SocketProvider qualification. */
call main
exit 0

main:
  ap=.RegisteredSocketAddressProvider~new
  listenerAddress=.RxSock6AddressFactory~tcp("::1",0,"ipv6.loop")
  ap~register("ipv6.loop",listenerAddress,.SocketRole~LISTENER)

  provider=.SocketProvider~new(ap)
  provider~registerBinding("TCP6",.RxSock6SocketBinding~new)

  listener=provider~listener("ipv6.loop",4)
  if listener=.nil then call fail "listener acquisition"

  boundNative=listener~raw~getSockName
  if boundNative=.nil then call fail "getSockName"

  connectAddress=.RxSock6AddressFactory~fromNative(boundNative,"ipv6.loop")
  ap~register("ipv6.loop",connectAddress,.SocketRole~SENDER)

  worker=.ProviderServerWorker~new
  started=worker~start(listener)
  call assert started,"server worker started"

  call SysSleep .1
  client=provider~sender("ipv6.loop")
  if client=.nil then call fail "sender acquisition"

  if client~sendAll("PING")<>4 then call fail "send"
  response=client~recv(4)
  if response<>"PONG" then call fail "response"

  call assert client~address~nativeAddress~family="AF_INET6","selected connection retains AF_INET6 address"

  client~close

  do i=1 to 100 while \worker~done
    call SysSleep .02
  end
  call assert worker~done,"server worker completed"
  call assert worker~ok,"server worker received and replied"

  listener~close

  say "PASS real SocketProvider -> RxSock6 IPv6 TCP listener/sender"
  return

assert:
  use strict arg ok,label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  return

fail:
  use strict arg label
  say "FAIL:" label
  exit 1

::class ProviderServerWorker public
::attribute done get
::attribute ok get

::method init
  expose done ok
  done=.false
  ok=.false

::method start unguarded
  expose done ok
  use strict arg listener
  reply .true
  peer=listener~accept
  if peer=.nil then do
    done=.true
    return
  end
  data=peer~recv(4)
  if data="PING" then do
    sent=peer~sendAll("PONG")
    if sent=4 then ok=.true
  end
  peer~close
  done=.true
  return

::requires "RxSock6SocketBinding.cls"
