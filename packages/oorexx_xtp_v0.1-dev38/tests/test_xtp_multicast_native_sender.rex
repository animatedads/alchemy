a=.SocketAddresses~xtp("MCG",.true,"xtp.multicast")
backend=.XtpSocketBackend~new
s=backend~sender(a)
rc=s~send("native multicast from Rexx")
if rc<>length("native multicast from Rexx") then do
  say "FAIL native multicast sender rc" rc
  exit 1
end
say "PASS native Rexx XTP multicast sender"
exit 0
::requires "XtpSocketProvider.cls"
