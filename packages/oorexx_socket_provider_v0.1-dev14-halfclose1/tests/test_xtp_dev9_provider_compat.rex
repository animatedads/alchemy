/* Compile/runtime compatibility with the XTP dev9 ooRexx provider source.
 * No native XTP packet is sent by this test.
 */
call main
exit 0

main:
  a=.SocketAddresses~xtp("02:AA:BB:CC:DD:EE")
  backend=.XtpSocketBackend~new("/bin/true")
  binding=.RexxXtpSocketBinding~new(backend)
  p=.SocketProvider~new(.RegisteredSocketAddressProvider~new)
  p~registerBinding("XTP",binding)
  endpoint=p~senderAt(a)
  call assert endpoint<>.nil,"XTP dev9 sender object constructed through dev4 provider"
  call assert endpoint~address~xtpAddress="02:AA:BB:CC:DD:EE","XTP address preserved"
  endpoint~close
  say "PASS XTP dev9 provider source compatible with Socket Provider dev4"
  return

assert:
  use strict arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::requires "SocketProvider.cls"
::requires "XtpSocketProvider.cls"
