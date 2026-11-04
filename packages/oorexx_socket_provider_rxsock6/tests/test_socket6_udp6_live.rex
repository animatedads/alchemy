/* Live native IPv6 UDP closure test.
 *
 * This deliberately exercises socket6.cls / rxsock6 directly.  It does not
 * claim that the checked-in historical Socket Provider adapter contains the
 * later dev3 UDP6 provider source.
 */
call main
exit 0

main:
  left=.Socket6~new("SOCK_DGRAM","IPPROTO_UDP")
  right=.Socket6~new("SOCK_DGRAM","IPPROTO_UDP")

  call assert left~string>=0,"left UDP6 socket created"
  call assert right~string>=0,"right UDP6 socket created"

  call assert left~setV6Only(1)=0,"left IPV6_V6ONLY"
  call assert right~setV6Only(1)=0,"right IPV6_V6ONLY"

  call assert left~bind(.Inet6Address~new("::1",0))=0,"left bind ::1"
  call assert right~bind(.Inet6Address~new("::1",0))=0,"right bind ::1"

  leftAddress=left~getSockName
  rightAddress=right~getSockName

  call assert leftAddress<>.nil,"left getsockname"
  call assert rightAddress<>.nil,"right getsockname"
  call assert leftAddress~family="AF_INET6","left address family"
  call assert rightAddress~family="AF_INET6","right address family"
  call assert leftAddress~port>0,"left ephemeral port"
  call assert rightAddress~port>0,"right ephemeral port"

  call assert left~connect(rightAddress)=0,"left connect right"
  call assert right~connect(leftAddress)=0,"right connect left"

  sent=left~send("PING")
  call assert sent=4,"left UDP6 send"
  received=right~recv(4)
  call assert received="PING","right UDP6 receive"

  sent=right~send("PONG")
  call assert sent=4,"right UDP6 send"
  received=left~recv(4)
  call assert received="PONG","left UDP6 receive"

  left~close
  right~close

  say "PASS native socket6.cls UDP6 connected datagram loopback"
  return

assert:
  use strict arg ok,label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  return

::requires "socket6.cls"
