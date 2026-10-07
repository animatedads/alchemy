call main
exit 0

main:
  native=.Inet6Address~new("::1",0)
  address=.Inet6SocketAddress~new(native,"loopback")

  call assert address~scheme="tcp","semantic scheme remains TCP"
  call assert address~transport="TCP6","provider binding key is TCP6"
  call assert address~addressFamily="INET6","family is INET6"
  call assert address~nativeAddress == native,"exact Inet6Address object retained"
  call assert address~host="::1","host comes from native object"
  call assert address~family~capabilities~stream,"TCP6 is stream capable"
  call assert \address~family~capabilities~multicast,"TCP6 not multicast"

  say "PASS rxsock6 Socket Provider object contract"
  return

assert:
  use strict arg ok,label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  return

::requires "RxSock6SocketBinding.cls"
