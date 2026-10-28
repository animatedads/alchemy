/* dev33 ooRexx test, receiving side: a protected one-way message.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: xtpPeer keyFile.  Receives one message of svc.msg and reports how it was protected. */
parse arg peer keyFile
keys = .XtpServiceKeys~new(.array~of(.XtpFileKeySource~new(keyFile)))
o = keys~refresh
handle = xtpNativeListenerOpenServices(peer, 15000, 'svc.msg')
say 'READY'
bytes = xtpNativeListenerReceive(handle)
parse value xtpNativeListenerLastProtection(handle) with protection keyId principal
expected = copies(xrange('00'x, 'ff'x), 400)
if bytes == expected & protection = 'encrypt' & keyId = '00000000000c0de1' then say 'PASS server: 102,400-byte message received byte-exact, protection='protection 'keyId='keyId
else say 'FAIL server: length='length(bytes) 'protection='protection 'keyId='keyId
ignore = xtpNativeListenerClose(handle)
exit 0
::requires 'XtpServiceKeys.cls'
::routine xtpNativeListenerOpenServices external "library oorexx_xtp_native xtpNativeListenerOpenServices"
::routine xtpNativeListenerReceive external "library oorexx_xtp_native xtpNativeListenerReceive"
::routine xtpNativeListenerLastProtection external "library oorexx_xtp_native xtpNativeListenerLastProtection"
::routine xtpNativeListenerClose external "library oorexx_xtp_native xtpNativeListenerClose"
