parse arg peer role payload
if peer='' | role='' then do
  say 'FAIL usage: test_xtp_dev14_native_merged.rex PEER sender|listener [payload]'
  exit 2
end
addresses=.RegisteredSocketAddressProvider~new
addresses~register('fabric.native',.SocketAddresses~xtp(peer))
sockets=.SocketSelector~new(addresses)
sockets~registerBinding('XTP',.RexxXtpSocketBinding~new(.XtpSocketBackend~new))
select
  when role='sender' then do
    ep=sockets~sender('fabric.native')
    if payload='' then payload='merged native Rexx XTP'
    n=ep~send(payload)
    if n<>length(payload) then do; say 'FAIL sender rc='n; exit 3; end
    say 'PASS merged native sender bytes='n
  end
  when role='listener' then do
    listener=sockets~listener('fabric.native')
    conn=listener~accept
    if conn=.nil then do; say 'FAIL listener accept'; exit 4; end
    got=conn~recv(1048576)
    if got<>payload then do
      say 'FAIL listener payload expected='c2x(payload)' got='c2x(got)
      exit 5
    end
    if conn~recv(1)<>.nil then do; say 'FAIL accepted socket should be drained'; exit 6; end
    conn~close
    listener~close
    say 'PASS merged native listener bytes='length(got)
  end
  otherwise do; say 'FAIL unknown role'; exit 7; end
end
exit 0
::requires 'XtpSocketProvider.cls'
