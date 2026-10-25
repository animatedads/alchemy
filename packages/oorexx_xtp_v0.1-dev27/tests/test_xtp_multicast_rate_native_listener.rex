a=.SocketAddresses~xtp("MCRATE",.true,"xtp.multicast.rate")
backend=.XtpSocketBackend~new
listener=backend~multicastListener(a,5000,4096,20,20000,512)
s=listener~accept
bytes=s~recv(8192)
if bytes<>copies("R",4096) then do
  say "FAIL native multicast RATE listener payload" length(bytes)
  exit 1
end
rc=listener~close
say "PASS native Rexx XTP multicast RATE/BURST listener"
exit 0
::requires "XtpSocketProvider.cls"
