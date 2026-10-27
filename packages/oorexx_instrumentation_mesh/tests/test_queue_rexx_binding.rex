#!/usr/bin/env rexx
say 'INSTRUMENTATION QUEUEREXX BINDING TEST START'
mesh=.FakePeerMesh~new
reg=.InstrumentationRegistry~new
svc=.InstrumentationService~new(reg)

c=.InstrumentationQueueRexxBinding~bindClient(mesh,'B','A')
call assertTrue c~ok,'client route binds'
call assertEq mesh~lastService,'INSTRUMENTATION.REQUEST.A','client service route'
call assertEq mesh~lastSecurity,'MANAGEMENT','management security domain'

s=.InstrumentationQueueRexxBinding~bindServer(mesh,'A','A',svc)
call assertTrue s~ok,'server route binds'
call assertEq mesh~lastService,'INSTRUMENTATION.REPLY.A','server service route'

/* Remote query must be transport-authenticated; command remains separately
 * subject to management authority. */
q=.InstrumentationCodec~query('q-remote')
r=svc~handleFrom('',q)
call assertEq r['status'],'DENIED','anonymous remote query denied'
r=svc~handleFrom('peer-a',q)
call assertEq r['status'],'OK','authenticated remote query accepted'
cmd=.InstrumentationCodec~command('cmd-1',.directory~new,'reload')
r=svc~handleFrom('peer-a',cmd)
call assertEq r['status'],'DENIED','command requires management authority'
call assertEq r['code'],'NO_MANAGEMENT_AUTHORITY','command authority failure'

/* Continuous publications use the same authenticated service-route carrier and
 * preserve publication identity as the Queue correlation id. */
transport=.InstrumentationQueueRexxClientTransport~new(mesh,'REMOTE','SEND','REPLY','instrumentation-service')
pub=.InstrumentationCodec~publication('pub-17','publisher-a',17,.array~new,'2026-10-08T08:10:00Z')
call assertEq transport~correlationId(pub),'pub-17','publication request correlation id'
receipt=.InstrumentationCodec~publicationReceipt(pub,'OK','ACCEPTED','',0)
call assertEq s~value~correlationId(receipt),'pub-17','publication receipt correlation id'

say 'PASS QueueRexx instrumentation service-route binding contract'
exit 0

assertTrue: procedure
  use arg truth,label
  if truth then return
  say 'FAIL' label
  exit 1
assertEq: procedure
  use arg actual,expected,label
  if actual=expected then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1

::class FakeResult public
::attribute ok get
::attribute value get
::method init
  expose ok value
  use strict arg v
  ok=.true; value=v

::class FakeQueueManager public
::method grant
  return .FakeResult~new(.true)

::class FakeChannels public
::method queueManager
  return .FakeQueueManager~new

::class FakePeerMesh public
::attribute lastService get
::attribute lastSecurity get
::method init
  expose qm ch
  qm=.FakeQueueManager~new; ch=.FakeChannels~new
::method queueManager
  expose qm
  return qm
::method channels
  expose ch
  return ch
::method listener
  return .nil
::method adminPrincipal
  return 'queue-admin'
::method bindServiceRoute
  expose lastService lastSecurity
  use strict arg peer,service,local,remote,security,principal='queue-admin'
  lastService=service; lastSecurity=security
  d=.directory~new; d['remote_alias']='REMOTE'; d['sender_channel']='SEND'; d['local_queue']=local
  return .FakeResult~new(d)

::requires 'InstrumentationQueueRexx.cls'
