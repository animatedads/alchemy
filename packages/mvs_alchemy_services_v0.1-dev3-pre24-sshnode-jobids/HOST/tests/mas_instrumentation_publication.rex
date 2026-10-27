/* PRE24: prove MAS snapshots use the real Mesh publication/collector path. */
identity=.InstrumentationCodec~identity('qualification','mvs-alchemy','pre24-publication','test-node','','MVS_ALCHEMY')
dims=.directory~new; dims['guest_id']='ED209Z'; dims['host_id']='ED209C'
source=.MasInstrumentationSource~new(identity,dims)
source~serviceHealthy
source~sessionOpened
source~frameReceived(.MasWire~OP_PING,53)
source~requestAccepted(.MasWire~OP_PING)
source~requestCompleted(.MasWire~OP_PING,0)
source~frameSent(.MasWire~OP_PING,57)
source~sessionClosed
registry=.InstrumentationRegistry~new
registry~register('mas',source)
service=.InstrumentationService~new(registry)
collector=.InstrumentationCollector~new(16)
collectorService=.InstrumentationCollectorService~new(collector)
transport=.InstrumentationLocalCollectorTransport~new(collectorService,'mas-pre24-qualified-peer')
publisher=.InstrumentationPublisher~new('mas-pre24-publisher',service,transport,'local-collector')
result=publisher~publish('2026-10-08T10:05:00Z')
call assert result~ok,'publication accepted'
ref=source~semanticRef
latest=collector~latestBySemanticRef(ref)
call assert latest<>.nil,'collector latest by semantic_ref'
call assert latest['semantic_ref']=ref,'collector semantic_ref preserved'
queryDims=.directory~new; queryDims['operation']='ping'; queryDims['guest_id']='ED209Z'
series=collector~series(ref,'mas.operation.completed.total',queryDims,8)
call assert series~items=1,'collector metric series'
call assert series[1]['value']=1,'collector series value'
call assert series[1]['dimensions']['operation']='ping','collector operation dimension'
call assert series[1]['dimensions']['guest_id']='ED209Z','collector guest dimension'
say 'MAS PRE24 INSTRUMENTATION PUBLICATION: PASS'
exit 0
assert: procedure
  use arg ok,label
  if \ok then do; say 'FAIL' label; exit 8; end
  return
::requires '../src/MasWire.cls'
::requires '../src/MasInstrumentationAdapter.cls'
