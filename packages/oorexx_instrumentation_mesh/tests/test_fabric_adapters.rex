#!/usr/bin/env rexx
say 'INSTRUMENTATION FABRIC ADAPTER TEST START'

/* Queue Fabric: real current ObjectQueueManager surface. */
qm=.ObjectQueueManager~new
r=qm~createQueue('WORK','TEMPORARY','MANAGEMENT',0,'queue-admin')
call assertTrue r~ok,'queue created'
r=qm~put('WORK','payload',.nil,'queue-admin')
call assertTrue r~ok,'queue put'
r=qm~createQueue('XMIT','TEMPORARY','MANAGEMENT',0,'queue-admin')
call assertTrue r~ok,'transmission queue created'
qch=.QueueChannelFabric~new('QM-A',qm,.QueueInProcessTransport~new,'queue-admin')
r=qch~defineSenderChannel('SEND-A','XMIT','QM-B','','','',0,'TEMPORARY','queue-admin')
call assertTrue r~ok,'sender channel defined'
r=qch~defineReceiverChannel('RECV-A','QM-B','','TEMPORARY','queue-admin')
call assertTrue r~ok,'receiver channel defined'
qid=.InstrumentationCodec~identity('alchemy','queue-fabric','qf-a','ed209a','','QUEUE_FABRIC')
qsrc=.QueueFabricInstrumentationSource~new(qid,qm,qch)
qs=qsrc~snapshot('2026-10-07T20:30:00Z')
call assertEq metric(qs,.InstrumentationVocabulary~QUEUE_DEPTH,'queue','WORK'),1,'queue depth projected'
call assertEq metric(qs,.InstrumentationVocabulary~QUEUE_COUNT),2,'queue count projected'
call assertEq metric(qs,.InstrumentationVocabulary~QUEUE_CHANNEL_SENT_TOTAL,'channel','SEND-A'),0,'sender counter projected'
call assertEq metric(qs,.InstrumentationVocabulary~QUEUE_CHANNEL_RECEIVED_TOTAL,'channel','RECV-A'),0,'receiver counter projected'

/* Memory Fabric: current v0.1-dev6 public provider registry. */
mf=.MemoryFabricRegistry~new('memory-a')
mp=.MemoryFabricProvider~new('mem-ed209a','MU','mu-a','','site-a','ed209a','',1048576,262144)
call assertTrue mf~registerProvider(mp),'memory provider registered'
mid=.InstrumentationCodec~identity('alchemy','memory-fabric','memory-a','ed209a','mu-a','MEMORY_FABRIC')
msrc=.MemoryFabricInstrumentationSource~new(mid,mf)
ms=msrc~snapshot('2026-10-07T20:30:01Z')
call assertEq metric(ms,.InstrumentationVocabulary~MEMORY_PROVIDER_COUNT),1,'memory provider count'
call assertEq metric(ms,.InstrumentationVocabulary~MEMORY_MANAGED_BYTES),1048576,'memory capacity total'
call assertEq metric(ms,.InstrumentationVocabulary~MEMORY_RESIDENT_BYTES),262144,'memory committed total'
call assertEq metric(ms,.InstrumentationVocabulary~MEMORY_AVAILABLE_BYTES),786432,'memory available total'

/* Storage Fabric: current v0.1-dev21 public manager/workspace surface. */
sm=.StorageManager~new
pool=.StoragePool~new('pool-a','local','/tmp/storage-a','domain-a','WORKSPACE',0,'ed209a','UK')
sm~registerPool(pool)
pool2=.StoragePool~new('pool-b','local','/tmp/storage-b','domain-a','WORKSPACE',0,'ed209a','UK')
sm~registerPool(pool2)
sm~observeCapacity(.StorageCapacityObservation~new('domain-a',2097152,1572864,'2026-10-07T20:30:00Z'))
allocation=sm~workspace~allocate('pool-a',262144,'job-a','alloc-a')
call assertTrue allocation<>.nil,'storage allocation'
obj=.StorageObject~new(.StorageRef~new('obj-1'),'one.bin',10)
sm~catalogue~put(obj)
sid=.InstrumentationCodec~identity('alchemy','storage-fabric','storage-a','ed209a','','STORAGE_FABRIC')
src=.StorageFabricInstrumentationSource~new(sid,sm)
ss=src~snapshot('2026-10-07T20:30:02Z')
call assertEq metric(ss,.InstrumentationVocabulary~STORAGE_CATALOGUE_OBJECTS),1,'storage catalogue count'
call assertEq metric(ss,.InstrumentationVocabulary~STORAGE_POOL_COUNT),2,'storage pool count'
call assertEq metric(ss,.InstrumentationVocabulary~STORAGE_CAPACITY_BYTES),2097152,'shared capacity domain not double counted'
call assertEq metric(ss,.InstrumentationVocabulary~STORAGE_WORKSPACE_RESERVED_BYTES),262144,'storage reserved bytes'
call assertEq metric(ss,.InstrumentationVocabulary~STORAGE_WORKSPACE_AVAILABLE_BYTES),1310720,'storage available bytes'
call assertEq metric(ss,.InstrumentationVocabulary~STORAGE_ALLOCATION_COUNT),1,'storage allocation count'

say 'PASS Queue/Memory/Storage instrumentation adapters'
exit 0

metric: procedure
  use arg snapshot,name,dimKey='',dimValue=''
  do sample over snapshot['samples']
    if sample['name']<>name then iterate
    if dimKey='' then do
      dims=sample['dimensions']
      if dims~items=0 then return sample['value']
      iterate
    end
    dims=sample['dimensions']
    if dims[dimKey]<>.nil then if dims[dimKey]=dimValue then return sample['value']
  end
  return 'NOT_FOUND'

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

::requires 'InstrumentationFabricAdapters.cls'
::requires 'ObjectQueueFabric.cls'
::requires 'ObjectQueueChannels.cls'
::requires 'MemoryFabric.cls'
::requires 'StorageFabric.cls'
