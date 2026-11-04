parse arg peer
payload='Z'~copies(60000)
n=xtpNativeSendServicePriorityRate(peer,payload,'storage.range.read','static',100,300000)
if n<>60000 then do; say 'FAIL send' n; exit 2; end
say 'PASS sender'
exit 0
::routine xtpNativeSendServicePriorityRate external "library oorexx_xtp_native xtpNativeSendServicePriorityRate"
