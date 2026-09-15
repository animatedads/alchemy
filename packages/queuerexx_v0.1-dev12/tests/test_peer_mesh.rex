root="/mnt/data/queuerexx-dev12-peer-mesh"
address system "rm -rf "||root
call SysMkDir root
wire=.QueueInProcessTransport~new
codec=.QueueGraphPayloadCodec~new

nodeA=.TestMeshNode~new("A","NODE-A",root||"/a",wire,codec)
nodeB=.TestMeshNode~new("B","NODE-B",root||"/b",wire,codec)
nodeC=.TestMeshNode~new("C","NODE-C",root||"/c",wire,codec)
wire~registerEndpoint("NODE-A",nodeA~fabric)
wire~registerEndpoint("NODE-B",nodeB~fabric)
wire~registerEndpoint("NODE-C",nodeC~fabric)
ops=.array~of(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerOperation~JOB_CHECK,.QueueRexxPeerOperation~LOAD_CHECK,.QueueRexxPeerOperation~POLICY_CHECK,.QueueRexxPeerOperation~HEALTH)
call must nodeA~runtime~bindFabricPeer("B","NODE-B","mesh-ab",ops),"bind A-B"
call must nodeB~runtime~bindFabricPeer("A","NODE-A","mesh-ab",ops),"bind B-A"
call must nodeA~runtime~bindFabricPeer("C","NODE-C","mesh-ac",ops),"bind A-C"
call must nodeC~runtime~bindFabricPeer("A","NODE-A","mesh-ac",ops),"bind C-A"
call must nodeB~runtime~bindFabricPeer("C","NODE-C","mesh-bc",ops),"bind B-C"
call must nodeC~runtime~bindFabricPeer("B","NODE-B","mesh-bc",ops),"bind C-B"

/* Each node has two independent peer authority links: no hub. */
if nodeA~runtime~trustPolicy~peers~items<>2 | nodeB~runtime~trustPolicy~peers~items<>2 | nodeC~runtime~trustPolicy~peers~items<>2 then call fail "mesh degree"

nodeA~runtime~service~registerHandler(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerStaticDecisionHandler~new("APPROVE","A-APPROVES"))
nodeB~runtime~service~registerHandler(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerStaticDecisionHandler~new("APPROVE","B-APPROVES"))
nodeC~runtime~service~registerHandler(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerStaticDecisionHandler~new("APPROVE","C-APPROVES"))

/* Real local QueueRexx job-state projections on B and C. */
call makeJobRoot root||"/b/queue","JOB-42","pending","B-JOB"
call makeJobRoot root||"/c/queue","JOB-42","pending","C-JOB"
nodeB~runtime~service~registerHandler(.QueueRexxPeerOperation~JOB_CHECK,.QueueRexxPeerJobCheckHandler~new(root||"/b/queue"))
nodeC~runtime~service~registerHandler(.QueueRexxPeerOperation~JOB_CHECK,.QueueRexxPeerJobCheckHandler~new(root||"/c/queue"))

/* Real Job-to-Node capacity observations back LOAD_CHECK. */
breg=.NodeCapabilityRegistry~new; creg=.NodeCapabilityRegistry~new
ignore=breg~advertiseCapability(.NodeCapabilityStatement~new("B",1)); ignore=breg~observeCapacity(.NodeCapacityObservation~new("B",1,1,1000,5000,20000,30000,8,4000000,2,1,"B-PROOF"))
ignore=creg~advertiseCapability(.NodeCapabilityStatement~new("C",1)); ignore=creg~observeCapacity(.NodeCapacityObservation~new("C",1,1,1000,5000,10000,15000,4,2000000,5,2,"C-PROOF"))
nodeB~runtime~service~registerHandler(.QueueRexxPeerOperation~LOAD_CHECK,.QueueRexxPeerJobNodeLoadHandler~new(breg,"B"))
nodeC~runtime~service~registerHandler(.QueueRexxPeerOperation~LOAD_CHECK,.QueueRexxPeerJobNodeLoadHandler~new(creg,"C"))

/* Replace A's ordinary synchronous routes with test orchestrators which run
 * the remote service in the same process while retaining real Queue Fabric
 * store-and-forward semantics. */
ab=.TestOrchestratedExecutor~new(nodeA~runtime~client~route("B")~executor,nodeB~runtime~service,"A")
ac=.TestOrchestratedExecutor~new(nodeA~runtime~client~route("C")~executor,nodeC~runtime~service,"A")
nodeA~runtime~client~addRoute("B",ab)
nodeA~runtime~client~addRoute("C",ac)

subject=.directory~new; subject["qid"]="JOB-42"; context=.directory~new; context["risk"]="HIGH"
peers=.array~of("B","C")

/* Strong approval: both peers required by a 2-of-2 quorum. */
q2=.QueueRexxPeerDecisionPolicy~new(.QueueRexxPeerDecisionMode~QUORUM,2,2)
d=nodeA~runtime~coordinator~evaluate(peers,.QueueRexxPeerOperation~AUTHORIZE,subject,context,q2)
if \d~approved | d~approvals~items<>2 then call fail "2-of-2 approval"

/* Lose B: a policy which only needs one healthy peer continues through C.
 * The unavailable B is evidence, not a cluster-wide veto. */
ab~available=.false
q1=.QueueRexxPeerDecisionPolicy~new(.QueueRexxPeerDecisionMode~QUORUM,1,1)
d=nodeA~runtime~coordinator~evaluate(peers,.QueueRexxPeerOperation~AUTHORIZE,subject,context,q1)
if \d~approved | d~approvals~items<>1 | d~unavailable~items<>1 | d~unavailable[1]<>"B" then call fail "degraded quorum did not survive B loss"

/* But a policy explicitly requiring B must fail closed while B is absent. */
required=.QueueRexxPeerDecisionPolicy~new(.QueueRexxPeerDecisionMode~REQUIRED,1,1,.array~of("B"))
d=nodeA~runtime~coordinator~evaluate(peers,.QueueRexxPeerOperation~AUTHORIZE,subject,context,required)
if d~approved then call fail "required unavailable peer incorrectly bypassed"
ab~available=.true

/* Job and load checks use the same peer path, not bespoke transports. */
d=nodeA~runtime~coordinator~evaluate(peers,.QueueRexxPeerOperation~JOB_CHECK,subject,.directory~new,q2)
if \d~approved then call fail "job check quorum"
ld=nodeA~runtime~coordinator~evaluate(peers,.QueueRexxPeerOperation~LOAD_CHECK,subject,.directory~new,q2)
if \ld~approved then call fail "load check quorum"
if ld~responses["B"]["evidence"]["available_cpu_units"]<>8 | ld~responses["C"]["evidence"]["available_cpu_units"]<>4 then call fail "load evidence"
if ld~responses["B"]["evidence"]["proof_ref"]<>"B-PROOF" | ld~responses["C"]["evidence"]["proof_ref"]<>"C-PROOF" then call fail "load proof evidence"

/* Explicit peer veto is a policy choice. */
nodeC~runtime~service~registerHandler(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerStaticDecisionHandler~new("DENY","C-VETO"))
veto=.QueueRexxPeerDecisionPolicy~new(.QueueRexxPeerDecisionMode~QUORUM,1,1,.nil,.true)
d=nodeA~runtime~coordinator~evaluate(peers,.QueueRexxPeerOperation~AUTHORIZE,subject,context,veto)
if d~approved | d~denials~items<>1 then call fail "deny veto"
nodeC~runtime~service~registerHandler(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerStaticDecisionHandler~new("APPROVE","C-APPROVES"))

/* The authorization frontage binds the complete quorum policy to one stable
 * authorization id.  Restart/retry reuses exact per-peer request ids; trying
 * to reinterpret the same approvals under a different quorum conflicts. */
auth=nodeA~runtime~authorizationGate~authorize(peers,subject,context,q2,"AUTH-JOB-42",0,0,"high-risk-job")
if \auth~approved | auth~asDirectory["authorization_id"]<>"AUTH-JOB-42" then call fail "authorization gate 2-of-2"
authReplay=nodeA~runtime~authorizationGate~authorize(peers,subject,context,q2,"AUTH-JOB-42",0,0,"high-risk-job")
if \authReplay~approved then call fail "authorization replay"
if authReplay~decision~responses["B"]["replayed"]<>"1" | authReplay~decision~responses["C"]["replayed"]<>"1" then call fail "authorization peer replay evidence"
authChanged=nodeA~runtime~authorizationGate~authorize(peers,subject,context,q1,"AUTH-JOB-42",0,0,"high-risk-job")
if authChanged~approved | authChanged~decision~errors~items<>2 then call fail "authorization policy reinterpretation was not rejected"
if authChanged~decision~responses["B"]["code"]<>"REQUEST_ID_CONFLICT" | authChanged~decision~responses["C"]["code"]<>"REQUEST_ID_CONFLICT" then call fail "authorization policy conflict evidence"

/* Stable request replay and request-id conflict are durable at the peer. */
r1=nodeA~runtime~client~request("B",.QueueRexxPeerOperation~AUTHORIZE,subject,context,0,0,"P1","FIXED-REQUEST-1")
if \r1~ok | r1~value["decision"]<>"APPROVE" then call fail "first fixed request"
r2=nodeA~runtime~client~request("B",.QueueRexxPeerOperation~AUTHORIZE,subject,context,0,0,"P1","FIXED-REQUEST-1")
if \r2~ok | r2~value["replayed"]<>"1" then call fail "peer replay"
changed=.directory~new; changed["qid"]="JOB-99"
r3=nodeA~runtime~client~request("B",.QueueRexxPeerOperation~AUTHORIZE,changed,context,0,0,"P1","FIXED-REQUEST-1")
if \r3~ok | r3~value["code"]<>"REQUEST_ID_CONFLICT" then call fail "peer request id conflict"

/* B can independently ask C: A is not a hub or mandatory transit node. */
bc=.TestOrchestratedExecutor~new(nodeB~runtime~client~route("C")~executor,nodeC~runtime~service,"B")
nodeB~runtime~client~addRoute("C",bc)
r=nodeB~runtime~client~request("C",.QueueRexxPeerOperation~HEALTH,.directory~new,.directory~new)
if \r~ok | r~value["decision"]<>"APPROVE" | r~value["source_node"]<>"C" then call fail "B-C direct health"

say "PASS QueueRexx dev12 peer mesh: three-node non-hub topology, durable authenticated Queue Fabric routes, policy-bound replay-safe authorization, quorum/required/veto policy, node-loss degradation, shared approval/job/load path, exact replay/conflict and direct B-C authority path"
exit 0

makeJobRoot: procedure
  use arg queueRoot, qid, stateName, jobName
  address system "mkdir -p "||queueRoot||"/pending "||queueRoot||"/running "||queueRoot||"/done "||queueRoot||"/failed "||queueRoot||"/interrupted "||queueRoot||"/cancelled "||queueRoot||"/pol_blocked"
  path=queueRoot||"/"||stateName||"/"||qid||".job"
  call lineout path,"JOB_ID="||qid
  call lineout path,"JOB_NAME="||jobName
  call lineout path,"JOB_CLASS=default"
  call lineout path,"PRIORITY=10"
  call lineout path,"COMMAND=('true')"
  call lineout path
  return

must: procedure
  use arg result, what
  if result==.nil | \result~ok then do
    if result==.nil then say "FAIL" what "nil"
    else say "FAIL" what result~code result~detail
    exit 1
  end
  return
fail: procedure
  parse arg message
  say "FAIL" message
  exit 1

::class TestDigest public
::method digest
  use strict arg text
  return c2x(text~string)

::class TestMeshNode public
::attribute nodeId get
::attribute manager get
::attribute fabric get
::attribute runtime get
::method init
  expose nodeId manager fabric runtime
  use strict arg nodeArg, managerName, root, wire, codec
  nodeId=nodeArg~string
  address system "mkdir -p "||root
  admin=nodeId||"-admin"
  manager=.ObjectQueueManager~new(root||"/fabric",codec,admin)
  fabric=.QueueChannelFabric~new(managerName,manager,wire,admin)
  runtime=.QueueRexxPeerMeshRuntime~new(nodeId,root,managerName,manager,fabric,wire,.nil,admin,.TestDigest~new)

::class TestOrchestratedExecutor public
::attribute available
::method init
  expose delegate remoteService callerNode
  use strict arg delegateArg, serviceArg, callerArg
  delegate=delegateArg; remoteService=serviceArg; callerNode=callerArg; self~available=.true
::method call
  expose delegate remoteService callerNode available
  use strict arg request
  if \available then return .QueueOperationResult~failure("REMOTE_MANAGER_UNAVAILABLE",callerNode)
  worker=.TestServePeerActivity~new(remoteService,callerNode)
  ignore=worker~run
  return delegate~call(request)

::class TestServePeerActivity public
::method init
  expose service peer
  use strict arg serviceArg, peerArg
  service=serviceArg; peer=peerArg
::method run
  expose service peer
  reply .true
  do i=1 to 400
    r=service~servePeer(peer,1)
    if r~ok & pos("served=1",r~detail)>0 then return
    if \r~ok then return
    call SysSleep 0.01
  end
  return

::requires "QueueRexxPeerMeshAdapters.cls"
