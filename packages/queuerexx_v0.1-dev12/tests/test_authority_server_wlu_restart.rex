root="/mnt/data/queuerexx-dev12-authority-server-wlu"
address system "rm -rf "||root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs","locks")
  call SysMkDir root||"/"||dir
end
call SysMkDir root||"/locks/state"

policy=.AllowPolicy~new
wluReq=.QueueWLURequirement~managedDemand("QTEST","AUTHNET",1000000,2000000,2)
submitReq=.QueueSubmitRequest~new("authority-wlu-network",.Array~of("/bin/true"),90,"BATCH",.QueueRunnerKind~DIRECT,"/tmp",wluReq)
submitted=.QueueSubmitService~new(root,policy)~submit(submitReq)
if \submitted~ok then call fail "submit"
record=.QueueStateStore~new(root)~findOne(submitted~qid)
placement=.QueueWLUPlacementRequestAdapter~fromRecord(record,.JobNodeRequirement~new,"FD-WLU-OWNER")

keys=.WLUFastMacKeyRing~new
keys~addKey("k1","00112233445566778899aabbccddeeff")
clock=.WLUTestTimeSource~new(1000000)
ledger=.WLUMemoryLedger~new
wluAuthority=.WLUAuthority~new(keys,ledger,clock)
wluAuthority~addAccount(.WLUAccount~new("acct",10000000))
wluAuthority~addThroughputPool(.WLUThroughputPool~new("pool",2000000))
wluAuthority~bindAccount("QTEST","AUTHNET*","acct")
wluAuthority~bindThroughputPool("QTEST","AUTHNET*","pool")

registry=.NodeCapabilityRegistry~new
if \registry~advertiseCapability(.NodeCapabilityStatement~new("NODE-WLU",1)) then call fail "capability"
if \registry~observeCapacity(.NodeCapacityObservation~new("NODE-WLU",1,7,1000000,1030000,4096,4096,4,2000000,0,0)) then call fail "capacity"
ops=.Array~of("PLAN","ALLOCATE","CHECK","RENEW","RELEASE")

stack1=.QueueRexxAuthorityStack~new(root,registry,.nil,wluAuthority,"QUEUEREXX","queue","QRX-WLU-NET","AUTH-WLU","127.0.0.1",0,"auth-admin",1000000,.TestDigest~new)
b1=stack1~bindClient("FD-WLU","FD-WLU","wire-wlu","k1",copies("44",64),.Array~of("127.0.0.1"),"127.0.0.1",9,"FD.REPLY","FD.RECV.AUTH",ops,"FD-WLU-OWNER")
if \b1~ok then call fail "bind1"
request=makeRequest("WLU-ALLOC-1","FD-WLU","ALLOCATE",placement,.nil,1000000,30000)
options=.table~new; options["persistent"]=.true; options["securityDomain"]="JNA"; options["correlationId"]="WLU-ALLOC-1"
q=stack1~queueManager~put(stack1~requestQueue,request,options,"wire-wlu")
if \q~ok then call fail "enqueue "||q~code||" "||q~detail
server1=.QueueRexxAuthorityServer~new(stack1)
r=server1~start
if \r~ok then call fail "server1 "||r~code||" "||r~detail
lease=stack1~ownership~current(submitted~qid,1000001)
if lease==.nil then call fail "WLU placement missing"
if lease~reservationRef="" then call fail "reservationRef missing"
if \stack1~allocator~hasAdmission(lease) then call fail "admission proof missing"
if \stack1~allocator~verifyLease(lease,placement,1000001) then call fail "lease rejected before restart"
ignore=server1~stop

/* Reconstruct the complete authority with the same WLU Authority.  JTN's
 * durable snapshot must restore ownership plus authenticated admission proof. */
stack2=.QueueRexxAuthorityStack~new(root,registry,.nil,wluAuthority,"QUEUEREXX","queue","QRX-WLU-NET","AUTH-WLU","127.0.0.1",0,"auth-admin",1000001,.TestDigest~new)
b2=stack2~bindClient("FD-WLU","FD-WLU","wire-wlu","k1",copies("44",64),.Array~of("127.0.0.1"),"127.0.0.1",9,"FD.REPLY","FD.RECV.AUTH",ops,"FD-WLU-OWNER")
if \b2~ok then call fail "bind2"
restored=stack2~ownership~current(submitted~qid,1000001)
if restored==.nil | restored~placementId<>lease~placementId | restored~ownershipEpoch<>lease~ownershipEpoch then call fail "ownership restore"
if \stack2~allocator~hasAdmission(restored) then call fail "WLU admission proof did not restore"
if \stack2~allocator~verifyLease(restored,placement,1000001) then call fail "restored WLU lease rejected"
state=wluAuthority~reservationState(restored~reservationRef)
if \state~ok | state~value<>.WLUReservationState~ACTIVE then call fail "WLU reservation not active after authority restart"

/* Network CHECK uses the reconstructed authority, not copied lease fields. */
checkReq=makeRequest("WLU-CHECK-1","FD-WLU","CHECK",placement,restored,1000001,0)
q2=stack2~queueManager~put(stack2~requestQueue,checkReq,options,"wire-wlu")
if \q2~ok then call fail "check enqueue "||q2~code||" "||q2~detail
server2=.QueueRexxAuthorityServer~new(stack2)
r2=server2~start
if \r2~ok then call fail "server2 "||r2~code||" "||r2~detail
ignore=server2~stop

say "PASS QueueRexx dev12 WLU-backed authority server restart: network ALLOCATE commits WLU reservation, JTN ownership/admission proof restores, exact lease remains verifiable and network CHECK is served from reconstructed authority"
exit 0

makeRequest: procedure
  use arg requestId,clientId,operation,placement,lease,now,duration
  d=.table~new; d["schema"]=.JobNodeNetworkBuild~REQUEST_SCHEMA; d["api"]=.JobNodeNetworkBuild~API
  d["requestId"]=requestId; d["clientId"]=clientId; d["operation"]=operation
  d["placementRequest"]=.JobNodeNetworkCodec~encodePlacementRequest(placement); d["lease"]=.JobNodeNetworkCodec~encodeLease(lease)
  d["nowEpochMs"]=now; d["leaseDurationMs"]=duration
  return d

fail: procedure
  parse arg message
  say "FAIL" message
  exit 1

::class AllowPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::class TestDigest public
::method digest
  use strict arg text
  return c2x(text~string)

::requires "QueueRexxAuthority.cls"
