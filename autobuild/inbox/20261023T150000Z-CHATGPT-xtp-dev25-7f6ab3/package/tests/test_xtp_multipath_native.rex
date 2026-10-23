parse arg peer role payload
if peer='' | role='' then do
  say 'FAIL usage: test_xtp_multipath_native.rex PEER sender|listener [payload]'
  exit 2
end
addr=.SocketAddresses~xtp(peer)
backend=.XtpSocketBackend~new
select
  when role='sender' then do
    if payload='' then payload='rexx-multipath-AAAABBBBCCCCDDDD'
    s=backend~multipathSender(addr,4,2,11)
    n=s~send(payload)
    s~close
    if n<>length(payload) then do; say 'FAIL multipath sender rc='n; exit 3; end
    say 'PASS native Rexx multipath sender bytes='n
  end
  when role='listener' then do
    l=backend~multipathListener(addr,2,0)
    c=l~accept
    if c=.nil then do; say 'FAIL multipath listener accept'; exit 4; end
    got=c~recv(1048576)
    c~close; l~close
    if got<>payload then do
      say 'FAIL multipath listener payload expected='c2x(payload)' got='c2x(got)
      exit 5
    end
    say 'PASS native Rexx multipath listener bytes='length(got)
  end
  otherwise do; say 'FAIL unknown role'; exit 6; end
end
exit 0
::requires "XtpSocketProvider.cls"
