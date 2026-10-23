/* Additive RTO2_WORK branch. Requires existing authenticated peer, command, managerName, emitFailure, emitResponse.
 * Do not run standalone; merge into the verified Grid Queue Fabric handler.
 */
if command[1]="RTO2_WORK" then do
  if value("QF_XTP_RTO2_ENABLED",,"ENVIRONMENT")<>"1" then do; call emitFailure peer,"RTO2_WORK_DISABLED",""; exit 0; end
  if peer["principal"]<>"grid-controller" | peer["security_domain"]<>"GRID" then do; call emitFailure peer,"RTO2_AUTHORITY_DENIED",""; exit 0; end
  if command~items<>6 then do; call emitFailure peer,"RTO2_WORK_MALFORMED",""; exit 0; end
  runId=command[3];nodeId=command[4];upper=command[5];epoch=command[6]
  allowedMu=value("GRID_MU_ID",,"ENVIRONMENT")
  actualNode=value("GRID_NODE_ID",,"ENVIRONMENT")
  if allowedMu="" | actualNode="" | managerName<>"GRID.MN."||actualNode~upper then do; call emitFailure peer,"RTO2_NODE_BINDING_UNAVAILABLE",""; exit 0; end
  if peer["source_manager"]<>"GRID.MU."||allowedMu~upper | nodeId<>actualNode then do; call emitFailure peer,"RTO2_CONTROLLER_BINDING_DENIED",""; exit 0; end
  if peer["receiver_channel"]<>"RTO2."||actualNode~upper then do; call emitFailure peer,"RTO2_CHANNEL_DENIED",""; exit 0; end
  if runId="" | runId~length>80 | verify(runId,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")<>0 then do; call emitFailure peer,"RTO2_RUN_INVALID",""; exit 0; end
  if \datatype(upper,"W") | upper<1 | upper>1000 | \datatype(epoch,"W") | epoch<1 then do; call emitFailure peer,"RTO2_WORK_BOUNDS",""; exit 0; end
  total=0
  do i=1 to upper;total=total+i;end
  job=.RTO2CountJob~new("ED209.SMOKE."||runId,nodeId,"AUTO",.nil)
  if \job~resolveRole("ACTIVE",epoch,"DIRECTED") then do; call emitFailure peer,"RTO2_ROLE_DENIED",""; exit 0; end
  sequence=job~commitLocalValue(total)
  if sequence<>1 then do; call emitFailure peer,"RTO2_COMMIT_FAILED",""; exit 0; end
  cap=.AlchemyRTO~capture(job,job~replaySequence,job~committedSequence)
  env=cap~document
  workOut=.Directory~new
  workOut["schema"]="rexxos.rto2.smoke.result/1"
  workOut["run_id"]=runId;workOut["node_id"]=nodeId;workOut["n"]=upper+0
  workOut["value"]=total;workOut["role"]=job~resolvedRole;workOut["epoch"]=job~activationEpoch
  workOut["committed_sequence"]=job~committedSequence;workOut["committed_value"]=job~committedValue
  workOut["rto2_api"]=env~schema;workOut["rto2_identity"]=env~root;workOut["rto2_lifecycle"]=env~lifecycle
  workOut["rto2_state"]=env~objects[env~root]
  response=.QueueRecordCodec~encode("RTO2_WORK_RESULT",.array~of(.QueueXTPTransportBuild~PROTOCOL,.json~toJson(workOut)))
  call emitResponse peer,response
  exit 0
end
