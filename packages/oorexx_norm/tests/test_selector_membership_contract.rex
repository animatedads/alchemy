api=.FakeNormApi~new
meta=.directory~new
meta['rxBufferBytes']=2097152
addr=.SocketAddresses~norm('239.255.42.3',47003,'eth3','198.51.100.3',3,'norm.selector.membership',meta)
ap=.RegisteredSocketAddressProvider~new~register('norm.selector.membership',addr)
s=.SocketSelector~new(ap)
s~registerBinding(.SocketTransportKind~NORM,.RexxNormSocketBinding~new(.NormSocketBackend~new(api)))

m=s~join('norm.selector.membership')
call assert m<>.nil,'selector join'
call assert m~address==addr,'address identity'
call assert m~interfaceName='eth3','interface through membership request'
call assert m~sourceAddress='198.51.100.3','SSM source through membership request'
call assert api~joinCount=1,'one native join'
call assert api~lastInterface='eth3','native interface'
call assert api~lastSource='198.51.100.3','native source'
call assert m~descriptor=88,'native descriptor'

l=s~listenerOn(m)
call assert l<>.nil,'listener on membership'
c=l~accept
call assert c<>.nil,'accept object'
call assert c~recv(1024)='provider-object','received payload'
call assert l~close=0,'listener close'
call assert m~joined,'listener close does not leave membership'
call assert api~leaveCount=0,'native membership retained'
call assert m~leave,'membership leave'
call assert api~leaveCount=1,'native leave once'

say 'PASS SocketSelector -> NORM explicit membership -> listener contract'
exit 0

assert: procedure
  use strict arg ok,why
  if \ok then do; say 'FAIL' why; exit 1; end
  return

::class FakeNormApi
::method init
  expose joinCount leaveCount lastInterface lastSource delivered
  joinCount=0; leaveCount=0; lastInterface=''; lastSource=''; delivered=.false
::attribute joinCount get
::attribute leaveCount get
::attribute lastInterface get
::attribute lastSource get
::method listenerOpen
  expose joinCount lastInterface lastSource delivered
  use strict arg group,port,nodeId,interface,source,loopback,rxBuffer
  joinCount+=1; lastInterface=interface; lastSource=source; delivered=.false
  return 123
::method listenerReceive
  expose delivered
  use strict arg handle
  if delivered then return .nil
  delivered=.true
  return 'provider-object'
::method listenerDescriptor
  use strict arg handle
  return 88
::method listenerClose
  expose leaveCount
  use strict arg handle
  leaveCount+=1
  return 0

::requires 'SocketProvider.cls'
::requires 'NormSocketProvider.cls'
