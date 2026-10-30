/* One Queue Fabric request carried by qf-xtp-rpc over native XTP.
 * Input path/source/carrier are supplied by the native helper environment.
 * Peer manifest rows:
 * SOURCE_MANAGER|PRINCIPAL|KEY_ID|KEY_HEX|CARRIER|ALLOWED_SOURCE|RECEIVER_CHANNEL|DEST_QUEUE|SECURITY_DOMAIN
 */
requestFile=value("QF_XTP_REQUEST_FILE",,"ENVIRONMENT")
actualCarrier=value("QF_XTP_CARRIER",,"ENVIRONMENT")~lower
actualSource=value("QF_XTP_SOURCE",,"ENVIRONMENT")~lower
managerName=value("QF_XTP_MANAGER_NAME",,"ENVIRONMENT")
root=value("QF_XTP_ROOT",,"ENVIRONMENT")
manifest=value("QF_XTP_PEERS",,"ENVIRONMENT")
admin=value("QF_XTP_ADMIN",,"ENVIRONMENT")
if admin="" then admin="admin"
if requestFile="" | managerName="" | root="" | manifest="" then exit 64
s=.stream~new(requestFile); s~open("read"); frame=s~charin(,s~chars); s~close
peek=.QueueXTPWire~parse(frame)
if peek==.nil then do; call emitPlainFailure "XTP_FRAME_INVALID"; exit 0; end
if peek["kind"]<>"REQ" then do; call emitPlainFailure "XTP_REQUEST_EXPECTED"; exit 0; end
peer=.nil
f=.stream~new(manifest); f~open("read")
do while f~lines>0
  line=f~linein~strip
  if line="" | line~left(1)="#" then iterate
  parse var line sourceManager "|" principal "|" keyId "|" keyHex "|" carrier "|" allowedSource "|" receiverChannel "|" destQueue "|" securityDomain
  sourceManager=sourceManager~strip; principal=principal~strip; keyId=keyId~strip; keyHex=keyHex~strip~lower
  carrier=carrier~strip~lower; allowedSource=allowedSource~strip~lower; receiverChannel=receiverChannel~strip; destQueue=destQueue~strip; securityDomain=securityDomain~strip
  if sourceManager=peek["source_manager"] & principal=peek["principal"] & keyId=peek["key_id"] then do
    p=.Directory~new; p["source_manager"]=sourceManager; p["principal"]=principal; p["key_id"]=keyId; p["key_hex"]=keyHex
    p["carrier"]=carrier; p["allowed_source"]=allowedSource; p["receiver_channel"]=receiverChannel; p["dest_queue"]=destQueue; p["security_domain"]=securityDomain
    peer=p; leave
  end
end
f~close
if peer==.nil then do; call emitPlainFailure "PEER_NOT_TRUSTED"; exit 0; end
if actualCarrier<>peer["carrier"] then do; call emitFailure peer,"CARRIER_MISMATCH",actualCarrier; exit 0; end
if actualSource<>peer["allowed_source"] then do; call emitFailure peer,"SOURCE_BINDING_MISMATCH",actualSource; exit 0; end
if peek["destination_manager"]<>managerName then do; call emitFailure peer,"DESTINATION_MANAGER_MISMATCH",peek["destination_manager"]; exit 0; end
if peek["receiver_channel"]<>peer["receiver_channel"] then do; call emitFailure peer,"RECEIVER_CHANNEL_MISMATCH",peek["receiver_channel"]; exit 0; end
opened=.QueueXTPWire~open(peer["key_hex"],frame,"REQ")
if \opened~ok then do; call emitFailure peer,opened~code,opened~detail; exit 0; end
plain=opened~value["plaintext"]
command=.QueueRecordCodec~decode(plain)
if command==.nil | command~items<2 | command[2]<>.QueueXTPTransportBuild~PROTOCOL then do; call emitFailure peer,"TRANSPORT_COMMAND_INVALID",""; exit 0; end
/* Only an authenticated, manifest-bound controller may issue bounded RTO2 work.
 * A Queue Fabric delivery ACK does not mean work was executed: this is a
 * distinct authenticated XTP application RPC with a captured RTO2 result.
 */
if command[1]="RTO2_WORK" then do
  if value("QF_XTP_RTO2_ENABLED",,"ENVIRONMENT")<>"1" then do; call emitFailure peer,"RTO2_WORK_DISABLED",""; exit 0; end
  if peer["principal"]<>"grid-controller" | peer["security_domain"]<>"GRID" then do; call emitFailure peer,"RTO2_AUTHORITY_DENIED",""; exit 0; end
  if command~items<>6 then do; call emitFailure peer,"RTO2_WORK_MALFORMED",""; exit 0; end
  runId=command[3]; nodeId=command[4]; upper=command[5]; epoch=command[6]
  allowedMu=value("GRID_MU_ID",,"ENVIRONMENT")
  actualNode=value("GRID_NODE_ID",,"ENVIRONMENT")
  if allowedMu="" | actualNode="" | managerName<>"GRID.MN."||actualNode~upper then do; call emitFailure peer,"RTO2_NODE_BINDING_UNAVAILABLE",""; exit 0; end
  if peer["source_manager"]<>"GRID.MU."||allowedMu~upper | nodeId<>actualNode then do; call emitFailure peer,"RTO2_CONTROLLER_BINDING_DENIED",""; exit 0; end
  if peer["receiver_channel"]<>"RTO2."||actualNode~upper then do; call emitFailure peer,"RTO2_CHANNEL_DENIED",""; exit 0; end
  if runId="" | runId~length>80 | verify(runId,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")<>0 then do; call emitFailure peer,"RTO2_RUN_INVALID",""; exit 0; end
  if \datatype(upper,"W") | upper<1 | upper>1000 | \datatype(epoch,"W") | epoch<1 then do; call emitFailure peer,"RTO2_WORK_BOUNDS",""; exit 0; end
  value=0
  do i=1 to upper; value=value+i; end
  job=.RTO2CountJob~new("ED209.SMOKE."||runId,nodeId,"AUTO",.nil)
  if \job~resolveRole("ACTIVE",epoch,"DIRECTED") then do; call emitFailure peer,"RTO2_ROLE_DENIED",""; exit 0; end
  sequence=job~commitLocalValue(value)
  if sequence<>1 then do; call emitFailure peer,"RTO2_COMMIT_FAILED",""; exit 0; end
  cap=.AlchemyRTO~capture(job,job~replaySequence,job~committedSequence)
  env=cap~document
  workOut=.Directory~new
  workOut["schema"]="rexxos.rto2.smoke.result/1"
  workOut["run_id"]=runId; workOut["node_id"]=nodeId; workOut["n"]=upper+0
  workOut["value"]=value;workOut["role"]=job~resolvedRole
  workOut["epoch"]=job~activationEpoch;workOut["committed_sequence"]=job~committedSequence
  workOut["committed_value"]=job~committedValue;workOut["rto2_api"]=env~schema
  workOut["rto2_identity"]=env~root;workOut["rto2_lifecycle"]=env~lifecycle
  workOut["rto2_state"]=env~objects[env~root]
  response=.QueueRecordCodec~encode("RTO2_WORK_RESULT",.array~of(.QueueXTPTransportBuild~PROTOCOL,.json~toJson(workOut)))
  call emitResponse peer,response
  exit 0
end
if command[1]="PROBE" then do
  response=.QueueRecordCodec~encode("HEALTH",.array~of(.QueueXTPTransportBuild~PROTOCOL,"OK",.QueueClock~timestamp))
  call emitResponse peer,response
  exit 0
end
if command[1]<>"DELIVER" | command~items<>3 then do; call emitFailure peer,"DELIVERY_INVALID",""; exit 0; end
codec=.QueueGraphPayloadCodec~new
signal on syntax name decodeFailed
envelope=codec~decode(command[3])
signal off syntax
mgr=.ObjectQueueManager~new(root,codec,admin)
if mgr~queue(peer["dest_queue"])==.nil then do
  cr=mgr~createQueue(peer["dest_queue"],"TEMPORARY",peer["security_domain"],64,admin)
  if \cr~ok then do; call emitFailure peer,cr~code,cr~detail; exit 0; end
  gr=mgr~grant(peer["dest_queue"],peer["principal"],.QueueAccess~PUT,admin)
  if \gr~ok then do; call emitFailure peer,gr~code,gr~detail; exit 0; end
end
fab=.QueueChannelFabric~new(managerName,mgr,.QueueInProcessTransport~new,admin)
rr=fab~defineReceiverChannel(peer["receiver_channel"],peer["source_manager"],peer["principal"],"TEMPORARY",admin)
if \rr~ok & rr~code<>"RECEIVER_CHANNEL_EXISTS" then do; call emitFailure peer,rr~code,rr~detail; exit 0; end
ignore=fab~startReceiverChannel(peer["receiver_channel"],admin)
receive=fab~receiveEnvelope(envelope,peer["receiver_channel"],peer["principal"])
if receive~ok then call updateGridRegistration envelope,peer,actualSource,actualCarrier
okText="0"; if receive~ok then okText="1"
transferId=""; packageId=""; queueName=""; acceptedAt=""; receiptSource=""; duplicateText="0"
receipt=receive~value
if receipt<>.nil then do
  if receipt~hasMethod("TRANSFERID") then transferId=receipt~transferId
  if receipt~hasMethod("PACKAGEID") then packageId=receipt~packageId
  if receipt~hasMethod("QUEUENAME") then queueName=receipt~queueName
  if receipt~hasMethod("ACCEPTEDAT") then acceptedAt=receipt~acceptedAt
  if receipt~hasMethod("SOURCEMANAGER") then receiptSource=receipt~sourceManager
  if receipt~hasMethod("DUPLICATE") then if receipt~duplicate then duplicateText="1"
end
response=.QueueRecordCodec~encode("RESULT",.array~of(.QueueXTPTransportBuild~PROTOCOL,okText,receive~code,receive~detail,transferId,packageId,queueName,acceptedAt,receiptSource,duplicateText))
call emitResponse peer,response
exit 0

decodeFailed:
  signal off syntax
  call emitFailure peer,"ENVELOPE_DECODE_FAILED",""
  exit 0

emitResponse:
  use arg p,plaintext
  h=peek
  response=.QueueXTPWire~response(p["key_hex"],h["correlation"],managerName,h["source_manager"],h["receiver_channel"],h["principal"],h["key_id"],h["nonce"],plaintext)
  call charout ,response
  return

emitFailure:
  use arg p,code,detail
  response=.QueueRecordCodec~encode("RESULT",.array~of(.QueueXTPTransportBuild~PROTOCOL,"0",code,detail,"","","","","","0"))
  call emitResponse p,response
  return

emitPlainFailure:
  use arg code
  /* Before a peer key is known we cannot construct an authenticated Queue Fabric response. */
  call charout ,"UNAUTHENTICATED:"||code
  return

updateGridRegistration:
  use arg env,p,observedSource,observedCarrier
  gridId=value("QF_XTP_GRID_ID",,"ENVIRONMENT")
  muId=value("QF_XTP_GRID_MU_ID",,"ENVIRONMENT")
  snapshotDir=value("QF_XTP_GRID_SNAPSHOT_DIR",,"ENVIRONMENT")
  if gridId="" | muId="" | snapshotDir="" then return
  payload=env~payload
  if payload==.nil | \payload~isA(.Directory) then return
  if payload["schema"]<>"rexxos.grid.registration.message/0.1" then return
  reg=.RexxOSGridRegistration~new(gridId,muId)
  obs=.Directory~new; obs["transport"]="queue.transport/2-over-xtp"; obs["xtp_carrier"]=observedCarrier; obs["observed_source"]=observedSource; obs["queue_fabric_manager"]=p["source_manager"]; obs["observed_state"]="REACHABLE"
  registrationReceipt=reg~registerProfileData(payload["profile"],p["source_manager"],obs)
  if registrationReceipt["state"]<>"REGISTERED" then return
  address system "mkdir -p -- "||quote(snapshotDir)
  nodePath=snapshotDir||"/"||payload["node_id"]||".json"
  tmp=nodePath||".tmp"; out=.stream~new(tmp); out~open("write replace"); out~charout(.json~toJson(registrationReceipt)); out~close
  address system "mv -- "||quote(tmp)||" "||quote(nodePath)
  return

quote:
  use arg x
  return "'"||x~changestr("'","'\\''")||"'"

::requires "ObjectQueueXTPTransport.cls"
::requires "RTO2CountJob.cls"
::requires "AlchemyRTO.cls"
::requires "RexxOSGridRegistration.cls"
::requires "json.cls"
