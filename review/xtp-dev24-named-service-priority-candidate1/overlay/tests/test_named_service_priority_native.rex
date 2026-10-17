/* Integration regression: named-service FIRST retains configured XTP SORT. */
parse arg peer payload
if peer='' then exit 2
if payload='' then payload='named-priority'
s=.XtpProviderSocket~new(.XtpLogicalPeerAddress~new(peer))
s~service('ssh.management')
s~priority('static',7)
n=s~send(payload)
if n<>length(payload) then do
  say 'FAIL named-priority Rexx sender rc='n
  exit 3
end
say 'PASS ooRexx named service priority sender bytes='n
exit 0
::requires "XtpNamedServices.cls"
