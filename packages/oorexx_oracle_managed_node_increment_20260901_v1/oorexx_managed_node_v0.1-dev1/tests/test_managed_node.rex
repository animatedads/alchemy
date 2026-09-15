/* full allocator -> priority queue -> node agent -> persistent result path */
digest=.WorkBundleCryptoSHA256Digest~new
bundleProof=.FakeNamedProof~new("bundle-key")
taskProof=.FakeNamedProof~new("task-key")
leaseProof=.FakeLeaseProof~new("lease-key")

/* Build one immutable TEST bundle. */
root=directory()||"/fixtures"
builder=.WorkBundleBuilder~new(digest,bundleProof)
bundle=builder~seal(root,"BUNDLE-TEST","BUILD","K1",.array~of("task.rex"),.array~of("task.rex"),.array~of("TEST"),.array~of("OOREXX"),"ssc:MANAGED-NODE@1",100,10000)
repo=.InMemoryWorkBundleRepository~new; ref=repo~put(bundle)
verifier=.WorkBundleVerifier~new(digest,bundleProof)

/* Allocator has two eligible durable nodes. NODE-B has more spare capacity,
 * proving placement remains allocator-owned rather than runner-owned. */
registry=.NodeCapabilityRegistry~new
abilities=.array~of("MANAGED_NODE_EXECUTION","COMMAND_EXECUTION","TEST_EXECUTION")
runtimes=.array~of("OOREXX")
uk=.array~of("GB")
ca=.NodeCapabilityStatement~new("NODE-A",1,"proof-a",uk,.nil,.nil,.nil,abilities,runtimes,.nil,"X86_64",8192,50000,4,"5.3.0-r13196")
cb=.NodeCapabilityStatement~new("NODE-B",1,"proof-b",uk,.nil,.nil,.nil,abilities,runtimes,.nil,"X86_64",8192,50000,4,"5.3.0-r13196")
registry~advertiseCapability(ca); registry~advertiseCapability(cb)
registry~observeCapacity(.NodeCapacityObservation~new("NODE-A",1,1,100,10000,2048,10000,1,1000000,0,0,"oa"))
registry~observeCapacity(.NodeCapacityObservation~new("NODE-B",1,1,100,10000,4096,20000,3,3000000,0,0,"ob"))
ownership=.JobNodeOwnershipRegistry~new
allocator=.JobNodeAllocator~new(registry,.nil,.nil,.nil,leaseProof,"1",.nil,ownership)
req=.JobNodeRequirement~new(uk,.nil,.nil,.nil,.array~of("TEST_EXECUTION"),runtimes,.nil,"X86_64",0,0,0,1,1,1,1,.nil,"5.3.0-r13196")
placeReq=.JobPlacementRequest~new("JOB-INTERACTIVE",req,"CONTROL",0,0)
decision=allocator~allocate(placeReq,200,5000)
call assertTrue decision~placed,"placement"
lease=decision~lease
call assertTrue lease~ownershipEpoch=1,"ownership epoch"

/* Queue graph codec is registered before manager construction so both work and
 * result payloads are journal-persistable. */
codec=.QueueGraphPayloadCodec~new
call assertTrue .ManagedNodeQueueTypes~register(codec),"queue type registration"
qroot="/tmp/managed-node-q-"||time("S")
address system "rm -rf '"||qroot||"'"
mgr=.ObjectQueueManager~new(qroot,codec,"queue-admin")
call assertTrue mgr~createQueue("node-a","PERMANENT","MANAGED",20,"queue-admin")~ok,"node-a queue"
call assertTrue mgr~createQueue("node-b","PERMANENT","MANAGED",20,"queue-admin")~ok,"node-b queue"
call assertTrue mgr~createQueue("results","PERMANENT","MANAGED",20,"queue-admin")~ok,"result queue"

/* First queue a background job directly onto the chosen node, then the real
 * interactive job. Queue Fabric must claim the interactive task first. */
authorizer=.ManagedTaskAuthorizer~new(digest,taskProof,"EXECUTION-AUTHORITY","TK1")
spec=.ManagedTaskSpec~new("JOB-INTERACTIVE","TEST",ref,"OOREXX","task.rex",.array~of("hello","oracle"),30,"results",65536)
auth=authorizer~issue(spec,lease,210,4000)
request=.ManagedTaskRequest~new(spec,auth)
envelope=.ManagedNodeDispatchEnvelope~new(lease,request)
dispatch=.JobNodeQueueFabricDispatcher~new(mgr)~bindNodeQueue("NODE-A","node-a")~bindNodeQueue("NODE-B","node-b")
opts=.table~new; opts["persistent"]=.true; opts["priority"]=.ManagedTaskPriority~INTERACTIVE

/* Lower priority synthetic task uses a second valid placement. It is queued
 * first; the later INTERACTIVE task must overtake it at claim time. */
placeReq2=.JobPlacementRequest~new("JOB-BACKGROUND",req,"CONTROL",0,0)
d2=allocator~allocate(placeReq2,220,5000); call assertTrue d2~placed,"background placement"
lease2=d2~lease
spec2=.ManagedTaskSpec~new("JOB-BACKGROUND","TEST",ref,"OOREXX","task.rex",.array~of("slow","background"),30,"results",65536)
auth2=authorizer~issue(spec2,lease2,225,4000)
env2=.ManagedNodeDispatchEnvelope~new(lease2,.ManagedTaskRequest~new(spec2,auth2))
opts2=.table~new; opts2["persistent"]=.true; opts2["priority"]=.ManagedTaskPriority~BACKGROUND
call assertTrue dispatch~dispatch(env2,"queue-admin",opts2)~ok,"background dispatch first"
call assertTrue dispatch~dispatch(envelope,"queue-admin",opts)~ok,"interactive dispatch second"

/* Restart the Queue manager before execution: both dispatch objects must be
 * reconstructed from the permanent journal with leases/auth/bundle refs intact. */
mgr=.ObjectQueueManager~new(qroot,codec,"queue-admin")
chosenQueue="node-"||lease~nodeId~right(1)~lower
runtime=.ManagedRuntimeRegistry~new~register("OOREXX","/usr/local/bin/rexx")
stager=.ManagedBundleStager~new("/tmp/oorexx-managed-node-test",digest)
agent=.ManagedNodeAgent~new(lease~nodeId,mgr,chosenQueue,"queue-admin",repo,verifier,.ManagedTaskAuthorizationVerifier~new(digest,taskProof),.ManagedPlacementVerifier~new(leaseProof,.true),runtime,stager,.nil,.nil,.true)
cycle=agent~runOnce(300)
call assertTrue cycle~ok,"agent cycle"
call assertTrue cycle~result~taskId="JOB-INTERACTIVE","interactive selected first"
call assertTrue cycle~result~success,"task completed"
call assertTrue cycle~result~stdout~pos("REMOTE-TEST hello oracle")>0,"stdout captured"
call assertTrue cycle~result~ownershipEpoch=1,"result fenced identity"
call assertTrue cycle~result~bundleDigest=bundle~digest,"result bundle identity"

/* Result is itself persistable and retrievable. */
r=mgr~get("results","queue-admin"); call assertTrue r~ok,"result get"
rr=r~value~payload
call assertTrue rr~taskId="JOB-INTERACTIVE","result payload round trip"
call assertTrue rr~placementId=lease~placementId,"result placement round trip"

/* Task authorization binds the exact argv/spec. A mutated spec cannot borrow
 * the original signed authorization. */
badSpec=.ManagedTaskSpec~new("JOB-INTERACTIVE","TEST",ref,"OOREXX","task.rex",.array~of("MUTATED"),30,"results",65536)
code=.ManagedTaskAuthorizationVerifier~new(digest,taskProof)~verify(auth,badSpec,lease,300)
call assertTrue code="TASK_AUTHORIZATION_TASK_MISMATCH","task mutation rejected"

/* Queue journal can recover the remaining background dispatch. */
mgr2=.ObjectQueueManager~new(qroot,codec,"queue-admin")
remainingQueue="node-"||lease2~nodeId~right(1)~lower
call assertTrue mgr2~depth(remainingQueue,"queue-admin")~value["ready"]>=1,"persistent dispatch recovered"
/* Destination monotonic fence rejects an older ownership epoch after a newer
 * one has been observed, even if the delayed object is otherwise well formed. */
fence=.ManagedNodeAttemptFence~new
newer=.JobNodePlacementLease~new("P2","FENCE-JOB","NODE-B","CONTROL",1,1,100,1000,"r","c","o","1","p","","",2,0,"")
older=.JobNodePlacementLease~new("P1","FENCE-JOB","NODE-B","CONTROL",1,1,100,1000,"r","c","o","1","p","","",1,0,"")
call assertTrue fence~accept(newer),"newer ownership accepted"
call assertTrue \fence~accept(older),"older ownership fenced"
address system "rm -rf '"||qroot||"' /tmp/oorexx-managed-node-test"
say "PASS Managed Node v0.1-dev1 allocator/priority/auth/bundle/execute/result/persistence"
exit 0

assertTrue: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return

::class FakeNamedProof public
::method init
  expose key
  use strict arg keyArg
  key=keyArg~string
::method sign
  expose key
  use strict arg identity,keyId,canonical
  return .SHA256~new(key||"|"||identity||"|"||keyId||"|"||canonical)~digest
::method verify
  use strict arg identity,keyId,canonical,signature
  return signature=self~sign(identity,keyId,canonical)

::class FakeLeaseProof public subclass JobNodeProofAuthority
::method init
  expose key
  use strict arg keyArg
  key=keyArg~string
::method sign
  expose key
  use strict arg canonical
  return .SHA256~new(key||"|"||canonical)~digest
::method verify
  use strict arg canonical,signature
  return signature=self~sign(canonical)

::requires "../src/ManagedNode.cls"
::requires "JobNodeQueueFabricAdapter.cls"
::requires "JobNodeLiveness.cls"
