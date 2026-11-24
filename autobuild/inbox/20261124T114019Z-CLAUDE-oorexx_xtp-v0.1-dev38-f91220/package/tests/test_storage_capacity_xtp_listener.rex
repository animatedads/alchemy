parse arg peer
h=xtpNativeListenerOpenServices(peer,5000,'storage.range.read')
say 'READY'
do 2
  data=xtpNativeListenerReceive(h)
  service=xtpNativeListenerLastService(h)
  if service<>'storage.range.read' | length(data)<>60000 then do
    say 'FAIL listener service/data' service length(data)
    call xtpNativeListenerClose h
    exit 2
  end
end
call xtpNativeListenerClose h
say 'PASS listener two transactions'
exit 0
::routine xtpNativeListenerOpenServices external "library oorexx_xtp_native xtpNativeListenerOpenServices"
::routine xtpNativeListenerReceive external "library oorexx_xtp_native xtpNativeListenerReceive"
::routine xtpNativeListenerLastService external "library oorexx_xtp_native xtpNativeListenerLastService"
::routine xtpNativeListenerClose external "library oorexx_xtp_native xtpNativeListenerClose"
