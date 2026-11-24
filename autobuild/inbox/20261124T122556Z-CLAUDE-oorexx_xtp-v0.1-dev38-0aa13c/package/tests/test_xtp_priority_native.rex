parse arg peer payload
if peer='' then exit 2
address=.SocketAddresses~xtp(peer)
backend=.XtpSocketBackend~new
sender=backend~prioritySender(address,'static',7)
if payload='' then payload='rexx-priority'
n=sender~send(payload)
if n<>length(payload) then do; say 'FAIL Rexx priority sender rc='n; exit 3; end
say 'PASS ooRexx priority sender bytes='n
exit 0
::requires "XtpSocketProvider.cls"
