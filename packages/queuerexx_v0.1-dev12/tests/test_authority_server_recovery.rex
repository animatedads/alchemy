root="/mnt/data/queuerexx-dev12-authority-server-recovery"
address system "rm -rf "||root
call SysMkDir root
registry=.NodeCapabilityRegistry~new
if \registry~advertiseCapability(.NodeCapabilityStatement~new("NODE-SERVER",1)) then call fail "capability"
if \registry~observeCapacity(.NodeCapacityObservation~new("NODE-SERVER",1,1,1000,20000,8192,8192,8,4000000,0,0)) then call fail "capacity"
ops=.Array~of("PLAN","ALLOCATE","CHECK","RENEW","RELEASE")
key=copies("22",64)
placement=.JobPlacementRequest~new("JOB-RECOVERED-NETWORK-1",.JobNodeRequirement~new,"FD-OWNER",1000,1000)
request=makeRequest("RECOVERED-ALLOCATE-1","FD-A","ALLOCATE",placement,.nil,1100,5000)
options=.table~new; options["persistent"]=.true; options["securityDomain"]="JNA"; options["correlationId"]="RECOVERED-ALLOCATE-1"

/* Process 1: the exact network1 request is durable before the authority
 * process disappears.  No placement has yet occurred. */
stack1=.QueueRexxAuthorityStack~new(root,registry,.nil,.nil,"QUEUEREXX","queue","QRX-SERVER-RECOVERY","AUTH-SERVER","127.0.0.1",0,"auth-admin",1000,.TestDigest~new)
b1=stack1~bindClient("FD-A","FD-A","wire-a","k1",key,.Array~of("127.0.0.1"),"127.0.0.1",9,"FD.REPLY","FD.RECV.AUTH",ops,"FD-OWNER")
if \b1~ok then call fail "bind1 "||b1~code||" "||b1~detail
q=stack1~queueManager~put("JNA.REQUEST",request,options,"wire-a")
if \q~ok then call fail "durable enqueue "||q~code||" "||q~detail
if stack1~ownership~current(placement~jobId,1100)<>.nil then call fail "request mutated before service"

/* Process 2: restore allocator first, then drain the durable network request
 * before accepting new transport.  The reply peer is deliberately offline;
 * exact response remains in its durable service xmit queue and must not block
 * authority startup. */
stack2=.QueueRexxAuthorityStack~new(root,registry,.nil,.nil,"QUEUEREXX","queue","QRX-SERVER-RECOVERY","AUTH-SERVER","127.0.0.1",0,"auth-admin",1200,.TestDigest~new)
b2=stack2~bindClient("FD-A","FD-A","wire-a","k1",key,.Array~of("127.0.0.1"),"127.0.0.1",9,"FD.REPLY","FD.RECV.AUTH",ops,"FD-OWNER")
if \b2~ok then call fail "bind2 "||b2~code||" "||b2~detail
server2=.QueueRexxAuthorityServer~new(stack2)
started=server2~start
if \started~ok then call fail "server start "||started~code||" "||started~detail
current=stack2~ownership~current(placement~jobId,1200)
if current==.nil then call fail "recovered request not allocated"
if current~nodeId<>"NODE-SERVER" | current~ownershipEpoch<>1 then call fail "recovered authority lease"
if stack2~allocator~sequenceValue<>1 then call fail "allocator sequence"
prior=stack2~networkLedger~lookup("RECOVERED-ALLOCATE-1")
if prior==.nil | prior["response"]["code"]<>"PLACED" then call fail "network ledger missing"
binding=b2~value["binding"]
xmit=stack2~channels~senderChannel(binding~senderChannel)~transmissionQueue
if stack2~queueManager~queue(xmit)~totalDepth<1 then call fail "offline reply not durable"
ignore=server2~stop

/* Process 3: exact requestId/content replay after another process restart must
 * replay the recorded response and never advance allocator ownership. */
stack3=.QueueRexxAuthorityStack~new(root,registry,.nil,.nil,"QUEUEREXX","queue","QRX-SERVER-RECOVERY","AUTH-SERVER","127.0.0.1",0,"auth-admin",1300,.TestDigest~new)
b3=stack3~bindClient("FD-A","FD-A","wire-a","k1",key,.Array~of("127.0.0.1"),"127.0.0.1",9,"FD.REPLY","FD.RECV.AUTH",ops,"FD-OWNER")
if \b3~ok then call fail "bind3"
q3=stack3~queueManager~put("JNA.REQUEST",request,options,"wire-a")
if \q3~ok then call fail "replay enqueue"
server3=.QueueRexxAuthorityServer~new(stack3)
started3=server3~start
if \started3~ok then call fail "server3 start "||started3~code||" "||started3~detail
current3=stack3~ownership~current(placement~jobId,1300)
if current3==.nil | current3~placementId<>current~placementId | current3~ownershipEpoch<>1 then call fail "replay changed placement"
if stack3~allocator~sequenceValue<>1 then call fail "replay advanced allocator"
prior3=stack3~networkLedger~lookup("RECOVERED-ALLOCATE-1")
if prior3==.nil | prior3["response"]["placementId"]<>.nil then nop /* data owns it */
if prior3["response"]["data"]["lease"]["placementId"]<>current~placementId then call fail "replay response changed"
ignore=server3~stop
say "PASS QueueRexx dev12 authority restart: durable network1 request drains before listen, exact JTN state/ledger replay survives restart, offline reply remains durable without blocking authority startup"
exit 0

makeRequest: procedure
  use arg requestId,clientId,operation,placement,lease,now,duration
  d=.table~new; d["schema"]=.JobNodeNetworkBuild~REQUEST_SCHEMA; d["api"]=.JobNodeNetworkBuild~API
  d["requestId"]=requestId; d["clientId"]=clientId; d["operation"]=operation
  d["placementRequest"]=.JobNodeNetworkCodec~encodePlacementRequest(placement); d["lease"]=.JobNodeNetworkCodec~encodeLease(lease)
  d["nowEpochMs"]=now; d["leaseDurationMs"]=duration
  return d
fail: procedure
  parse arg message; say "FAIL" message; exit 1
::class TestDigest public
::method digest
  use strict arg text
  return "D:"||c2x(text~string)
::requires "QueueRexxAuthority.cls"
