a=.SocketAddresses~xtp("MCG",.true,"xtp.multicast")
backend=.XtpSocketBackend~new
listener=backend~listener(a)
s=listener~accept
bytes=s~recv(4096)
if bytes<>"native multicast from Rexx" then do
  say "FAIL native multicast listener payload" bytes
  exit 1
end
rc=listener~close
say "PASS native Rexx XTP multicast listener"
exit 0
::requires "XtpSocketProvider.cls"
