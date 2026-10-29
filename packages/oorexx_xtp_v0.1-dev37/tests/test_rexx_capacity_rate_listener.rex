parse arg peer
h=xtpNativeListenerOpenServices(peer,3000,'storage.range.read')
say 'READY'
data=xtpNativeListenerReceive(h)
service=xtpNativeListenerLastService(h)
call xtpNativeListenerClose h
if service<>'storage.range.read' | length(data)<>60000 then do; say 'FAIL'; exit 2; end
say 'PASS listener'
exit 0
::routine xtpNativeListenerOpenServices external "library oorexx_xtp_native xtpNativeListenerOpenServices"
::routine xtpNativeListenerReceive external "library oorexx_xtp_native xtpNativeListenerReceive"
::routine xtpNativeListenerLastService external "library oorexx_xtp_native xtpNativeListenerLastService"
::routine xtpNativeListenerClose external "library oorexx_xtp_native xtpNativeListenerClose"
