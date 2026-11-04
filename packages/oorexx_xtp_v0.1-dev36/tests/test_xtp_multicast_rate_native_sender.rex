a=.SocketAddresses~xtp("MCRATE",.true,"xtp.multicast.rate")
backend=.XtpSocketBackend~new
s=backend~multicastSender(a,1,.true,256,100,8,.true,.true)
payload=copies("R",4096)
rc=s~send(payload)
if rc<>length(payload) then do
  say "FAIL native multicast RATE sender rc" rc
  exit 1
end
say "PASS native Rexx XTP multicast RATE/BURST sender"
exit 0
::requires "XtpSocketProvider.cls"
