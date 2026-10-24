a=.SocketAddresses~norm('239.255.42.2',47002,'eth2','',2,'norm.membership')

explicit=.FakeNormMembership~new('EXPLICIT')
l=.NormProviderListener~new(a,11,explicit,.false)
call assert l~descriptor=44,'listener descriptor uses membership'
c=l~accept
call assert c<>.nil,'listener accepts membership object'
call assert c~recv(64)='EXPLICIT','accepted payload preserved'
call assert l~close=0,'explicit listener closes'
call assert explicit~leaveCount=0,'explicit membership survives listener close'
call assert explicit~joined,'explicit membership still joined'
call assert explicit~leave=0,'explicit membership leave succeeds'
call assert explicit~leaveCount=1,'explicit membership leaves once'

implicit=.FakeNormMembership~new('IMPLICIT')
l2=.NormProviderListener~new(a,11,implicit,.true)
call assert l2~close=0,'implicit listener closes'
call assert implicit~leaveCount=1,'implicit membership leaves with listener'

say 'PASS NORM listener/membership lifetime separation'
exit 0

assert: procedure
  use strict arg ok, why
  if \ok then do
    say 'FAIL' why
    exit 1
  end
  return

::class FakeNormMembership
::method init
  expose payload joined leaveCount
  use strict arg payload
  joined=.true; leaveCount=0
::attribute leaveCount get
::method joined
  expose joined
  return joined
::method descriptor
  return 44
::method receive
  expose payload joined
  if \joined then return .nil
  return payload
::method leave
  expose joined leaveCount
  leaveCount+=1
  joined=.false
  return 0

::requires 'SocketProvider.cls'
::requires 'NormSocketProvider.cls'
