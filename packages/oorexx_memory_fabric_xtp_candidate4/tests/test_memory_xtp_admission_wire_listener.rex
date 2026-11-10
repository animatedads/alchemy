parse arg peer
h=xtpNativeListenerOpenServices(peer,5000,'memory.block.read.mu5')
say 'READY'
do 2
  data=xtpNativeListenerReceive(h)
  service=xtpNativeListenerLastService(h)
  if service<>'memory.block.read.mu5' | length(data)<>60000 then do
    say 'FAIL bad service/bytes' service length(data)
    call xtpNativeListenerClose h
    exit 2
  end
end
call xtpNativeListenerClose h
say 'PASS Memory XTP listener two bounded named-service control transactions'
exit 0
::routine xtpNativeListenerOpenServices external "library oorexx_xtp_native xtpNativeListenerOpenServices"
::routine xtpNativeListenerReceive external "library oorexx_xtp_native xtpNativeListenerReceive"
::routine xtpNativeListenerLastService external "library oorexx_xtp_native xtpNativeListenerLastService"
::routine xtpNativeListenerClose external "library oorexx_xtp_native xtpNativeListenerClose"
