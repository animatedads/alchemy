parse arg iface
if iface='' then iface='lo'

meta=.directory~new
meta['loopback']=.true

a1=.SocketAddresses~norm('239.255.42.71',47071,iface,'',71,'norm.event.one',meta)
a2=.SocketAddresses~norm('239.255.42.72',47072,iface,'',72,'norm.event.two',meta)

addresses=.RegisteredSocketAddressProvider~new
addresses~register('norm.event.one',a1)
addresses~register('norm.event.two',a2)

selector=.SocketSelector~new(addresses)
selector~registerBinding(.SocketTransportKind~NORM, -
  .RexxNormSocketBinding~new(.NormSocketBackend~new(.NormNativeApi~new)))

m1=selector~join('norm.event.one')
m2=selector~join('norm.event.two')
call assert m1<>.nil,'first membership joined'
call assert m2<>.nil,'second membership joined'
call assert m1~descriptor<>m2~descriptor,'memberships have distinct descriptors'

l1=selector~listenerOn(m1)
l2=selector~listenerOn(m2)
call assert l1<>.nil,'first listener'
call assert l2<>.nil,'second listener'

dispatcher=.EventDispatcher~new
e1=.SocketListenerEventAdapter~new(l1,'norm.membership.one',dispatcher)
e2=.SocketListenerEventAdapter~new(l2,'norm.membership.two',dispatcher)
set=.SocketDescriptorSet~new
set~add(e1)
set~add(e2)

sink1=.PayloadSink~new
sink2=.PayloadSink~new
e1~onAccepted(sink1,'accepted')
e2~onAccepted(sink2,'accepted')

/* Give the kernel/libnorm memberships time to settle before transmission. */
address system 'sleep 1'

s1=selector~sender('norm.event.one')
s2=selector~sender('norm.event.two')
call assert s1<>.nil,'first sender'
call assert s2<>.nil,'second sender'

p1='NORM-EVENT-ONE-'||copies('A',4096)
p2='NORM-EVENT-TWO-'||copies('B',4096)
call assert s1~send(p1)=length(p1),'first send length'
call assert s2~send(p2)=length(p2),'second send length'

/* Each adapter is the sole readiness consumer for its listener. */
call assert e1~waitAndDrain(15000,8)>0,'first descriptor delivered'
call assert e2~waitAndDrain(15000,8)>0,'second descriptor delivered'

call assert sink1~payloads~items=1,'first source one event'
call assert sink2~payloads~items=1,'second source one event'
call assert sink1~payloads[1]=p1,'first payload exact'
call assert sink2~payloads[1]=p2,'second payload exact'
call assert sink1~sourceIds[1]='norm.membership.one','first source identity'
call assert sink2~sourceIds[1]='norm.membership.two','second source identity'
call assert sink1~sequences[1]=1,'first independent sequence'
call assert sink2~sequences[1]=1,'second independent sequence'

s1~waitDrained(5000)
s2~waitDrained(5000)
s1~close
s2~close

l1~close
l2~close
call assert m1~joined,'first membership survives listener close'
call assert m2~joined,'second membership survives listener close'
call assert m1~leave,'first explicit leave'
call assert m2~leave,'second explicit leave'

say 'PASS live NORM two-membership Socket/Event Runtime integration'
exit 0

assert: procedure
  use strict arg ok,why
  if \ok then do
    say 'FAIL|'||why
    exit 1
  end
  return

::class PayloadSink
::method init
  expose payloads sourceIds sequences
  payloads=.array~new
  sourceIds=.array~new
  sequences=.array~new
::attribute payloads get
::attribute sourceIds get
::attribute sequences get

::method accepted
  expose payloads sourceIds sequences
  use strict arg event
  socket=event~data
  payload=socket~recv(1048576)
  payloads~append(payload)
  sourceIds~append(event~sourceId)
  sequences~append(event~sequence)

::requires "SocketProvider.cls"
::requires "NormSocketProvider.cls"
::requires "NormNativeBinding.cls"
::requires "EventRuntime.cls"
::requires "SocketEventRuntimeAdapter.cls"
