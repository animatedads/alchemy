a1=.FakeAccepted~new('norm://239.1.1.1:47001','A')
a2=.FakeAccepted~new('norm://239.1.1.2:47002','B')
l1=.FakeListener~new(51,.array~of(a1))
l2=.FakeListener~new(52,.array~of(a2))
dispatcher=.EventDispatcher~new
b1=.SocketListenerEventAdapter~new(l1,'membership.one',dispatcher)
b2=.SocketListenerEventAdapter~new(l2,'membership.two',dispatcher)
s1=.Sink~new
s2=.Sink~new
b1~onAccepted(s1,'accepted')
b2~onAccepted(s2,'accepted')
set=.SocketDescriptorSet~new
set~add(b1)
set~add(b2)
call assert set~descriptors~items=2,'two simultaneous descriptors registered'
call assert set~dispatchReady(52)=1,'dispatch second descriptor only'
call assert s1~events~items=0,'first membership untouched'
call assert s2~events~items=1,'second membership delivered'
call assert s2~events[1]~data==a2,'second accepted object preserved'
call assert set~dispatchReady(51)=1,'dispatch first descriptor'
call assert s1~events~items=1,'first membership delivered'
call assert set~remove(52),'remove registration'
call assert set~adapterFor(52)==.nil,'registration removed'
call assert l2~closeCount=0,'descriptor removal does not close provider listener'
say 'PASS simultaneous descriptor registration and independent dispatch'
exit 0

assert: procedure
  use strict arg ok,why
  if \ok then do; say 'FAIL' why; exit 1; end
  return

::class Sink
::method init
  expose events
  events=.array~new
::attribute events get
::method accepted
  expose events
  use strict arg event
  events~append(event)

::class FakeAddress
::method init
  expose value
  use strict arg value
::method canonical
  expose value
  return value

::class FakeAccepted
::method init
  expose address payload
  use strict arg addressText,payload
  address=.FakeAddress~new(addressText)
::attribute address get
::attribute payload get

::class FakeListener
::method init
  expose descriptorValue pending closeCount
  use strict arg descriptorArg,pendingArg
  descriptorValue=descriptorArg
  pending=pendingArg
  closeCount=0
::attribute closeCount get
::method descriptor
  expose descriptorValue
  return descriptorValue
::method tryAccept
  expose pending
  if pending~items=0 then return .nil
  return pending~remove(1)
::method waitReady
  expose pending
  use strict arg timeoutMilliseconds=0
  return pending~items>0
::method close
  expose closeCount
  closeCount+=1
  return 0

::requires "EventRuntime.cls"
::requires "SocketEventRuntimeAdapter.cls"
