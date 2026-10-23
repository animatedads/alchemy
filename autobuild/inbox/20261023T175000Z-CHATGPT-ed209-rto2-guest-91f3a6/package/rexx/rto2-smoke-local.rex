/* Bounded local RTO2 count/capture, no network or scheduler ownership. */
parse arg runId nodeId upper epoch
if runId="" | nodeId="" | upper="" | epoch="" then do
  say "usage: rto2-smoke-local.rex RUN_ID NODE_ID COUNT EPOCH";exit 64
end
if \datatype(upper,"W") | upper<1 | upper>1000 then exit 65
if \datatype(epoch,"W") | epoch<1 then exit 65
if runId~length>80 | verify(runId,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")<>0 then exit 65
if nodeId~length>48 | verify(nodeId,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-")<>0 then exit 65
v=0
do i=1 to upper;v=v+i;end
j=.RTO2CountJob~new("ED209.SMOKE."||runId,nodeId,"AUTO",.nil)
if \j~resolveRole("ACTIVE",epoch,"DIRECTED") then exit 66
seq=j~commitLocalValue(v)
if seq<>1 then exit 67
capt=.AlchemyRTO~capture(j,j~replaySequence,j~committedSequence)
env=capt~document
out=.Directory~new
out["schema"]="rexxos.rto2.smoke.result/1"
out["run_id"]=runId;out["node_id"]=nodeId;out["n"]=upper+0
out["value"]=v;out["role"]=j~resolvedRole;out["epoch"]=j~activationEpoch
out["committed_sequence"]=j~committedSequence;out["committed_value"]=j~committedValue
out["rto2_api"]=env~schema;out["rto2_identity"]=env~root
out["rto2_lifecycle"]=env~lifecycle;out["rto2_state"]=env~objects[env~root]
say .json~toJson(out)
exit 0
::requires "RTO2CountJob.cls"
::requires "AlchemyRTO.cls"
