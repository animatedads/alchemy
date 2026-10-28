call assert .SocketProviderBuild~VERSION='0.1-dev13','dev13 build version'
a=.SocketAddresses~xtp('MERGEPEER')
call assert a~transport=.SocketTransportKind~XTP,'XTP transport retained'
call assert a~family~capabilities~sender,'XTP sender capability'
call assert a~family~capabilities~listener,'XTP listener capability'
call assert \a~family~capabilities~multicast,'XTP multicast remains false'

b=.XtpSocketBackend~new
call assert b~hasMethod('SENDER'),'XTP backend sender access'
call assert b~hasMethod('LISTENER'),'XTP backend listener access'
call assert b~hasMethod('MULTIPATHSENDER'),'XTP backend multipath sender access'
call assert b~hasMethod('MULTIPATHLISTENER'),'XTP backend multipath listener access'

binding=.RexxXtpSocketBinding~new(b)
call assert binding~hasMethod('SENDER'),'generic XTP binding sender'
call assert binding~hasMethod('LISTENER'),'generic XTP binding listener'

addresses=.RegisteredSocketAddressProvider~new
addresses~register('fabric.merge',a)
sockets=.SocketSelector~new(addresses)
sockets~registerBinding('XTP',binding)
call assert sockets~family('fabric.merge')~transport=.SocketTransportKind~XTP,'selector sees merged XTP family'

say 'PASS XTP dev14 provider merge contract'
exit 0

assert: procedure
  use strict arg ok, what
  if \ok then do
    say 'FAIL' what
    exit 1
  end
  return

::requires 'XtpSocketProvider.cls'
