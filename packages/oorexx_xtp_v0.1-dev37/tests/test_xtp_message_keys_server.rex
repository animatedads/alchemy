/* dev33 ooRexx test, receiving side: a protected one-way message.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: xtpPeer keyFile mpPeer.  Receives one message of svc.msg, then (dev34) one
 * multipath transfer of svc.msg over mpPeer's two routes, and reports how each was protected. */
parse arg peer keyFile mpPeer
keys = .XtpServiceKeys~new(.array~of(.XtpFileKeySource~new(keyFile)))
o = keys~refresh
handle = xtpNativeListenerOpenServices(peer, 15000, 'svc.msg')
mp = xtpNativeMultipathListenerOpen(mpPeer, 2, 15000)
say 'READY'
bytes = xtpNativeListenerReceive(handle)
parse value xtpNativeListenerLastProtection(handle) with protection keyId principal
expected = copies(xrange('00'x, 'ff'x), 400)
if bytes == expected & protection = 'encrypt' & keyId = '00000000000c0de1' then say 'PASS server: 102,400-byte message received byte-exact, protection='protection 'keyId='keyId
else say 'FAIL server: length='length(bytes) 'protection='protection 'keyId='keyId
ignore = xtpNativeListenerClose(handle)
bytes = xtpNativeMultipathListenerReceive(mp)
parse value xtpNativeMultipathLastProtection(mp) with protection keyId service
if bytes == expected & protection = 'encrypt' & keyId = '00000000000c0de1' & service = 'svc.msg' then say 'PASS server: multipath transfer over 2 routes received byte-exact, protection='protection 'service='service
else say 'FAIL server: multipath length='length(bytes) 'protection='protection 'keyId='keyId 'service='service
ignore = xtpNativeMultipathListenerClose(mp)
exit 0
::requires 'XtpServiceKeys.cls'
::routine xtpNativeListenerOpenServices external "library oorexx_xtp_native xtpNativeListenerOpenServices"
::routine xtpNativeListenerReceive external "library oorexx_xtp_native xtpNativeListenerReceive"
::routine xtpNativeListenerLastProtection external "library oorexx_xtp_native xtpNativeListenerLastProtection"
::routine xtpNativeListenerClose external "library oorexx_xtp_native xtpNativeListenerClose"
::routine xtpNativeMultipathListenerOpen external "library oorexx_xtp_native xtpNativeMultipathListenerOpen"
::routine xtpNativeMultipathListenerReceive external "library oorexx_xtp_native xtpNativeMultipathListenerReceive"
::routine xtpNativeMultipathLastProtection external "library oorexx_xtp_native xtpNativeMultipathLastProtection"
::routine xtpNativeMultipathListenerClose external "library oorexx_xtp_native xtpNativeMultipathListenerClose"
