#!/usr/bin/env rexx
call RxFuncAdd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'
call SysLoadFuncs

say 'INSTRUMENTATION MESH TEST START'

identity=.InstrumentationCodec~identity('alchemy','smtp','smtp-a','ed209a','','SMTP')
e=.InstrumentationEmitter~new(identity)
e~setHealth(.InstrumentationHealth~HEALTHY)
e~requestAccepted
junk=e~bytesIn(128)
junk=e~memoryResident(4096)
junk=e~progress('msg-17','DATA',5,10,'messages','2026-10-07T20:00:00Z')
e~requestCompleted
s=e~snapshot('2026-10-07T20:00:01Z')
call assertEq s['schema'],.InstrumentationContract~SNAPSHOT_SCHEMA,'snapshot schema'
call assertEq s['health'],'HEALTHY','health'
call assertEq s['progress'][1]['operation_id'],'msg-17','progress operation'

reg=.InstrumentationRegistry~new
reg~register('smtp-a',e)
h=.InstrumentationHistory~new(4)
svc=.InstrumentationService~new(reg,h)
snapshots=svc~sampleAll('2026-10-07T20:00:02Z')
call assertEq snapshots~items,1,'registry snapshot count'
q=.InstrumentationCodec~query('q-1')
r=svc~handleQuery(q)
call assertEq r['status'],'OK','query status'
call assertEq r['payload']~items,1,'history count'
remoteDenied=svc~handleFrom('',q)
call assertEq remoteDenied['status'],'DENIED','remote query requires authenticated peer'
remoteOk=svc~handleFrom('peer-a',q)
call assertEq remoteOk['status'],'OK','authenticated remote query'

/* Command path must fail closed without a management authority. */
c=.InstrumentationCodec~command('c-1',.directory~new,'reload')
cr=svc~handleCommand('peer-a',c)
call assertEq cr['status'],'DENIED','command denied without authority'
call assertEq cr['code'],'NO_MANAGEMENT_AUTHORITY','authority code'

/* Mutable source state must not be exposed by an old snapshot. */
old=s['identity']['service_id']
identity['service_id']='tampered-source'
call assertEq s['identity']['service_id'],old,'snapshot identity defensive copy'

say 'PASS instrumentation.mesh/0.1 core semantics'
exit 0

assertEq: procedure
  use arg actual,expected,label
  if actual<>expected then do
    say 'FAIL' label 'expected='expected 'actual='actual
    exit 1
  end
  return

::requires 'src/InstrumentationMesh.cls'
