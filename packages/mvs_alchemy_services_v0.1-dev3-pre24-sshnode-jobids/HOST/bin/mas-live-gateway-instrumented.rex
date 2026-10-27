#!/usr/bin/env rexx
parse arg port stateRoot evidenceFile telemetryFile
if port='' then port=37075
if stateRoot='' then stateRoot='/tmp/mas-live-gateway'
if evidenceFile='' then evidenceFile=stateRoot||'/gateway-log.txt'
if telemetryFile='' then telemetryFile=stateRoot||'/instrumentation.tsv'
call SysMkDir stateRoot
estate=value('MAS_INSTRUMENTATION_ESTATE_ID',,'ENVIRONMENT'); if estate='' then estate='alchemy'
service=value('MAS_INSTRUMENTATION_SERVICE_ID',,'ENVIRONMENT'); if service='' then service='mvs-alchemy'
instance=value('MAS_INSTRUMENTATION_INSTANCE_ID',,'ENVIRONMENT'); if instance='' then instance='ed209z-gateway'
node=value('MAS_INSTRUMENTATION_NODE_ID',,'ENVIRONMENT'); if node='' then node='ED209C'
identity=.InstrumentationCodec~identity(estate,service,instance,node,'','MVS_ALCHEMY')
dims=.directory~new
dims['guest_id']=value('MAS_INSTRUMENTATION_GUEST_ID',,'ENVIRONMENT'); if dims['guest_id']='' then dims['guest_id']='ED209Z'
dims['host_id']=node
metrics=.MasInstrumentationSource~new(identity,dims)
say 'MAS LIVE GATEWAY INSTRUMENTED port='port 'state='stateRoot 'evidence='evidenceFile
server=.MasLiveGateway~new(port,stateRoot,evidenceFile,metrics)
rc=server~serveOnce
snap=metrics~snapshot
call stream telemetryFile,'c','open write replace'
call lineout telemetryFile,'semantic_ref' || '09'x || snap['semantic_ref']
call lineout telemetryFile,'health' || '09'x || snap['health']
do sample over snap['samples']
  dimText=''
  dims=sample['dimensions']
  if dims<>.nil then do k over dims
    if dimText<>'' then dimText||=','
    dimText||=k||'='||dims[k]
  end
  line=sample['name'] || '09'x || sample['kind'] || '09'x || sample['unit'] || '09'x || sample['value'] || '09'x || dimText
  call lineout telemetryFile,line
end
call lineout telemetryFile
say 'MAS LIVE GATEWAY EXIT rc='rc 'telemetry='telemetryFile
exit rc
::requires 'MasLiveGateway.cls'
::requires 'MasInstrumentationAdapter.cls'
::requires 'InstrumentationMesh.cls'
