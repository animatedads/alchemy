/* PRE24 Instrumentation Mesh adapter smoke test. */
identity=.InstrumentationCodec~identity('qualification','mvs-alchemy','pre24','test-node','','MVS_ALCHEMY')
dims=.directory~new; dims['guest_id']='ED209Z'; dims['host_id']='ED209C'
m=.MasInstrumentationSource~new(identity,dims)
m~serviceHealthy
m~sessionOpened
m~frameReceived(.MasWire~OP_HELLO,48)
m~requestAccepted(.MasWire~OP_HELLO)
m~requestCompleted(.MasWire~OP_HELLO,0)
m~frameSent(.MasWire~OP_HELLO,64)
m~requestAccepted(.MasWire~OP_PING)
m~requestFailed(.MasWire~OP_PING,20)
m~sessionClosed
snap=m~snapshot('2026-10-08T10:00:00Z')
call assert snap['schema']='instrumentation.snapshot/1','snapshot schema'
call assert snap['semantic_ref']='instrumentation://qualification/mvs-alchemy/pre24@test-node','semantic ref'
call assert m~semanticRef=snap['semantic_ref'],'source semantic ref'
call assert metric(snap,'request.accepted.total')=2,'accepted total'
call assert metric(snap,'request.completed.total')=1,'completed total'
call assert metric(snap,'request.failed.total')=1,'failed total'
call assert metric(snap,'request.inflight')=0,'inflight returns zero'
call assert metric(snap,'io.bytes.in.total')=48,'bytes in'
call assert metric(snap,'io.bytes.out.total')=64,'bytes out'
call assert metric(snap,'mas.io.bytes.in.total')=48,'dimensioned bytes in'
call assert metric(snap,'mas.io.bytes.out.total')=64,'dimensioned bytes out'
call assert metric(snap,'mas.sessions.accepted.total')=1,'session accepted'
call assert metric(snap,'mas.sessions.closed.total')=1,'session closed'
call assert metric(snap,'mas.sessions.active')=0,'session active zero'
call assert metric(snap,'mas.frames.received.total')=1,'frames received'
call assert metric(snap,'mas.frames.sent.total')=1,'frames sent'
call assert metric(snap,'mas.protocol.errors.total')=1,'protocol error'
call assert metric(snap,'mas.operation.accepted.total')=2,'operation accepted total'
call assert sampleDim(snap,'mas.frames.received.total','operation')='hello','operation dimension'
call assert sampleDim(snap,'mas.frames.received.total','family')='protocol','family dimension'
call assert sampleDim(snap,'mas.frames.received.total','guest_id')='ED209Z','guest dimension'
cap=m~capability
call assert cap['schema']='instrumentation.capability/1','capability schema'
call assert cap['commands']~items=0,'no instrumentation mutation commands'
say 'MAS PRE24 INSTRUMENTATION MESH: PASS'
exit 0
metric: procedure
  use arg snap,name
  do s over snap['samples']
    if s['name']=name then return s['value']
  end
  return .nil
sampleDim: procedure
  use arg snap,name,key
  do s over snap['samples']
    if s['name']=name then return s['dimensions'][key]
  end
  return .nil
assert: procedure
  use arg ok,label
  if \ok then do; say 'FAIL' label; exit 8; end
  return
::requires '../src/MasWire.cls'
::requires '../src/MasInstrumentationAdapter.cls'
