a=.SocketAddresses~norm('239.255.42.9',47009,'eth9','198.51.100.9',77,'spiral.multicast')
ap=.RegisteredSocketAddressProvider~new~register('spiral.multicast',a)
backend=.MembershipTestBackend~new
provider=.SocketSelector~new(ap)
provider~registerBinding(.SocketTransportKind~NORM,.MembershipTestBinding~new(backend))

request=.SocketMulticastMembershipRequest~new(a,'eth9','198.51.100.9','')
m=provider~joinAt(a,request)
call assert m<>.nil,'join returned membership'
call assert m~joined,'membership joined'
call assert m~address==a,'address identity preserved'
call assert m~interfaceName='eth9','interface retained'
call assert m~sourceAddress='198.51.100.9','source retained'
call assert m~descriptor=71,'descriptor delegated'

listener=provider~listenerOn(m,23)
call assert listener<>.nil,'listener attached to membership'
call assert listener~address==a,'listener exact address identity'
call assert listener~close=0,'listener close succeeds'
call assert m~joined,'listener close does not leave explicit membership'
call assert backend~native~leaveCount=0,'listener lifetime independent of membership'
call assert m~leave,'explicit leave succeeds'
call assert \m~joined,'membership left'
call assert backend~native~leaveCount=1,'native leave exactly once'
call assert m~leave,'leave idempotent'
call assert backend~native~leaveCount=1,'idempotent leave does not repeat native operation'
call assert provider~listenerOn(m)=.nil,'left membership cannot open listener'

tcp=.SocketAddresses~tcp('127.0.0.1',47010,'not.multicast')
call assert provider~joinAt(tcp)=.nil,'non-multicast address rejected'

say 'PASS multicast membership lifecycle contract'
exit 0

assert: procedure
  use strict arg ok, why
  if \ok then do
    say 'FAIL' why
    exit 1
  end
  return

::class MembershipTestBackend
::method init
  expose native
  native=.MembershipTestNative~new
::attribute native get
::method join
  expose native
  use strict arg address, request
  return native
::method listenerOn
  use strict arg nativeMembership, address, backlog
  return .MembershipTestListener~new

::class MembershipTestBinding subclass SocketTransportBinding
::method init
  expose backend
  use strict arg backend
  backend=backend
::method listener
  use strict arg address, backlog=32
  return .nil
::method sender
  use strict arg address
  return .nil
::method join
  expose backend
  use strict arg address, request
  return backend~join(address,request)
::method listenerOn
  expose backend
  use strict arg nativeMembership, address, backlog=32
  return backend~listenerOn(nativeMembership,address,backlog)

::class MembershipTestNative
::method init
  expose leaveCount joined
  leaveCount=0; joined=.true
::attribute leaveCount get
::method descriptor
  return 71
::method leave
  expose leaveCount joined
  leaveCount+=1
  joined=.false
  return 0

::class MembershipTestListener
::method accept
  return .nil
::method close
  return 0

::requires 'SocketProvider.cls'
