identity=.InstrumentationCodec~identity('alchemy','smtp','SMTP1','ED209C','','SMTP')
emitter=.InstrumentationEmitter~new(identity)
emitter~setHealth(.InstrumentationHealth~HEALTHY)
adapter=.SocketTelemetryInstrumentationObserver~new(emitter)

facts=.Directory~new
facts['transport']='TLS'; facts['scheme']='tls'; facts['addressFamily']='INET'; facts['role']='SENDER'
facts['logicalName']='smtp.delivery'; facts['nativeIdentity']='tls://secret.example:443'; facts['securityProfile']='prod-client'
facts['metric']='socket.io.bytes.out'; facts['value']=512
call assertTrue adapter~record(.FakeEvent~new('socket.io.bytes',facts)), 'socket event accepted'

g=.Directory~new; g['transport']='TLS'; g['gauge']='socket.connections.active'; g['delta']=1; g['logicalName']='smtp.delivery'
call assertTrue adapter~record(.FakeEvent~new('socket.acquire.success',g)), 'socket gauge event accepted'

snapshot=emitter~snapshot('2026-10-09T11:00:00Z')
bytes=.nil; active=.nil
do sample over snapshot['samples']
  if sample['name'] == .InstrumentationVocabulary~BYTES_OUT_TOTAL then bytes=sample
  if sample['name'] == 'socket.connections.active' then active=sample
end
call assertTrue bytes <> .nil, 'bytes mapped to common instrumentation vocabulary'
call assertEqual 512, bytes['value'], 'byte value preserved'
call assertEqual 'TLS', bytes['dimensions']['transport'], 'generic transport dimension preserved'
call assertTrue \bytes['dimensions']~hasIndex('logicalName'), 'logical name not propagated'
call assertTrue \bytes['dimensions']~hasIndex('nativeIdentity'), 'native endpoint identity not propagated'
call assertTrue \bytes['dimensions']~hasIndex('securityProfile'), 'security profile not propagated'
call assertEqual 1, active['value'], 'active connection gauge projected'

say 'PASS test_socket_telemetry_mesh_adapter'
exit 0
assertTrue: procedure
  use arg condition, label
  if \condition then do; say 'FAIL:' label; exit 1; end
return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
return
::class FakeEvent
::method init
  use arg name,facts
  self~name=name; self~facts=facts
::attribute name
::attribute facts
::requires '../src/InstrumentationIntentions.cls'
