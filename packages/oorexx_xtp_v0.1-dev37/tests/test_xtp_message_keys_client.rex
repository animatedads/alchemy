/* dev33 ooRexx test, sending side: protected one-way messages follow the
 * service's profile on their own.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: xtpPeer keyFile mpPeer */
parse arg peer keyFile mpPeer
failures = 0
keys = .XtpServiceKeys~new(.array~of(.XtpFileKeySource~new(keyFile)))
o = keys~refresh
if keys~protectionOf('svc.msg') = 'encrypt' then say 'PASS client: svc.msg profile encrypt from the key file'
else do; say 'FAIL client: profile' keys~protectionOf('svc.msg'); failures = failures + 1; end
n = xtpNativeSendService(peer, copies(xrange('00'x, 'ff'x), 400), 'svc.msg')
say 'PASS client: sent with the service profile applied, no protection argument needed'
call SysSleep 0.3
n = xtpNativeMultipathSend(mpPeer, copies(xrange('00'x, 'ff'x), 400), 8192, 2, 1, 'svc.msg')
say 'PASS client: multipath transfer of svc.msg sent over 2 routes, protected chunk by chunk'
/* every key gone: the profile stays, and the next message is refused before sending */
ignore = xtpNativeKeyClearSource('file')
signal on syntax name refused
n = xtpNativeSendService(peer, 'must not be sent in clear', 'svc.msg')
say 'FAIL client: a message was sent with no keys left'
exit 1
refused:
  say 'PASS client: no keys left, the message is refused:' condition('O')['ADDITIONAL']~makeString~left(90)
  if failures = 0 then exit 0
  exit 1
::requires 'XtpServiceKeys.cls'
::routine xtpNativeSendService external "library oorexx_xtp_native xtpNativeSendService"
::routine xtpNativeMultipathSend external "library oorexx_xtp_native xtpNativeMultipathSend"
