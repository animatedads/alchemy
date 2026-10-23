checks=0
identity=.InstrumentationCodec~identity('test-estate','rpc','instance','node')
emitter=.InstrumentationEmitter~new(identity)
registry=.JsonRpcMethodRegistry~new
registry~register('demo.echo',.EchoHandler~new)
base=.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(registry))
transport=.JsonRpcInstrumentedTransport~new(base,emitter)
client=.JsonRpcClient~new(transport)
reply=client~request('demo.echo',.array~of(3))
call check reply~ok, 'observed transport succeeds'
reply=client~request('missing.method')
call check \reply~ok, 'remote fault stays fault'
call check client~notify('demo.echo'), 'observed notification sent'
call check sampleValue(emitter,.InstrumentationVocabulary~REQUEST_ACCEPTED_TOTAL)==3, 'accepted transmissions'
call check sampleValue(emitter,.InstrumentationVocabulary~REQUEST_COMPLETED_TOTAL)==3, 'completed at transport boundary'
call check sampleValue(emitter,.InstrumentationVocabulary~BYTES_OUT_TOTAL)>0, 'outbound count'
call check sampleValue(emitter,.InstrumentationVocabulary~BYTES_IN_TOTAL)>0, 'inbound count'
call check emitter~gaugeValue(.InstrumentationVocabulary~REQUEST_INFLIGHT)==0, 'no inflight after work'
/* Bad optional instrumentation must not corrupt a completed RPC call. */
broken=.JsonRpcClient~new(.JsonRpcInstrumentedTransport~new(base,.FaultyEmitter~new))
reply=broken~request('demo.echo',.array~of(9))
call check reply~ok & reply~result[1]==9, 'observer errors are non-authoritative'
say 'PASS' checks 'Instrumentation Mesh integration checks'  
exit 0
sampleValue:
  use strict arg emitter, metric
  snap=emitter~snapshot
  do item over snap['samples']
    if item['name']==metric then return item['value']
  end
  return 0
check:
  use strict arg condition, name
  if \condition then do
    say 'FAIL' name
    exit 1
  end
  checks=checks+1
return
::class EchoHandler
::method invoke
  use strict arg name, params, context
  return params
::class FaultyEmitter
::method requestAccepted
  raise syntax 93.900 additional('collector offline')
::method bytesOut
  use strict arg bytes
  raise syntax 93.900 additional('collector offline')
::method bytesIn
  use strict arg bytes
  raise syntax 93.900 additional('collector offline')
::method requestCompleted
  raise syntax 93.900 additional('collector offline')
::method requestFailed
  raise syntax 93.900 additional('collector offline')
::requires 'JsonRpcFabric.cls' 
::requires 'JsonRpcInstrumentation.cls'
::requires 'InstrumentationMesh.cls'
