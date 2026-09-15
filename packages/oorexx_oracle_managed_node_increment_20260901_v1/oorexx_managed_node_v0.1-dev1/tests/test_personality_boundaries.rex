digest=.WorkBundleCryptoSHA256Digest~new
bundleProof=.FakeNamedProof~new("bundle-key")
taskProof=.FakeNamedProof~new("task-key")
leaseProof=.FakeLeaseProof~new("lease-key")

root=directory()||"/fixtures"
builder=.WorkBundleBuilder~new(digest,bundleProof)
bundle=builder~seal(root,"BUNDLE-BOUNDARY","BUILD","K1",.array~of("task.rex"),.array~of("task.rex"),.array~of("FETCH","SERVICE"),.array~of("OOREXX"),"ssc:MANAGED-NODE-BOUNDARY@1",100,10000)
repo=.InMemoryWorkBundleRepository~new; ref=repo~put(bundle)
verifier=.WorkBundleVerifier~new(digest,bundleProof)

registry=.NodeCapabilityRegistry~new
abilities=.array~of("MANAGED_NODE_EXECUTION","FETCH_EXECUTION","SERVICE_HOSTING")
runtimes=.array~of("OOREXX"); uk=.array~of("GB")
cap=.NodeCapabilityStatement~new("NODE-A",1,"proof-a",uk,.nil,.nil,.nil,abilities,runtimes,.nil,"X86_64",8192,50000,4,"5.3.0-r13196")
registry~advertiseCapability(cap)
registry~observeCapacity(.NodeCapacityObservation~new("NODE-A",1,1,100,10000,4096,20000,3,3000000,0,0,"oa"))
ownership=.JobNodeOwnershipRegistry~new
allocator=.JobNodeAllocator~new(registry,.nil,.nil,.nil,leaseProof,"1",.nil,ownership)

codec=.QueueGraphPayloadCodec~new; call assertTrue .ManagedNodeQueueTypes~register(codec),"types"
qroot="/tmp/managed-node-boundary-"||time("S"); address system "rm -rf '"||qroot||"'"
mgr=.ObjectQueueManager~new(qroot,codec,"queue-admin")
call assertTrue mgr~createQueue("node-a","TEMPORARY","MANAGED",20,"queue-admin")~ok,"work queue"
call assertTrue mgr~createQueue("results","TEMPORARY","MANAGED",20,"queue-admin")~ok,"result queue"
dispatch=.JobNodeQueueFabricDispatcher~new(mgr)~bindNodeQueue("NODE-A","node-a")
authorizer=.ManagedTaskAuthorizer~new(digest,taskProof,"EXECUTION-AUTHORITY","TK1")
runner=.CountingExecutor~new
runtime=.ManagedRuntimeRegistry~new~register("OOREXX","/usr/local/bin/rexx")
stager=.ManagedBundleStager~new("/tmp/oorexx-managed-node-boundary-stage",digest)
agent=.ManagedNodeAgent~new("NODE-A",mgr,"node-a","queue-admin",repo,verifier,.ManagedTaskAuthorizationVerifier~new(digest,taskProof),.ManagedPlacementVerifier~new(leaseProof,.true),runtime,stager,runner,.nil,.false)

call checkBoundary "FETCH","FETCH_EXECUTION","FETCH_RUNNER_NOT_IMPLEMENTED",allocator,authorizer,dispatch,agent,ref,runner,uk,runtimes
call checkBoundary "SERVICE","SERVICE_HOSTING","SERVICE_RECONCILER_NOT_IMPLEMENTED",allocator,authorizer,dispatch,agent,ref,runner,uk,runtimes
call assertTrue runner~count=0,"generic executor never receives FETCH or SERVICE"
address system "rm -rf '"||qroot||"' /tmp/oorexx-managed-node-boundary-stage"
say "PASS Managed Node FETCH/SERVICE fail-closed personality boundaries"
exit 0

checkBoundary: procedure
  use arg kind,ability,expected,allocator,authorizer,dispatch,agent,ref,runner,uk,runtimes
  job="JOB-"||kind
  req=.JobNodeRequirement~new(uk,.nil,.nil,.nil,.array~of(ability),runtimes,.nil,"X86_64",0,0,0,1,1,1,1,.nil,"5.3.0-r13196")
  d=allocator~allocate(.JobPlacementRequest~new(job,req,"CONTROL",0,0),200,5000)
  call assertTrue d~placed,kind||" placement"
  lease=d~lease
  spec=.ManagedTaskSpec~new(job,kind,ref,"OOREXX","task.rex",.array~new,30,"results",65536)
  auth=authorizer~issue(spec,lease,210,4000)
  opts=.table~new; opts["persistent"]=.false; opts["priority"]=.ManagedTaskPriority~NORMAL
  call assertTrue dispatch~dispatch(.ManagedNodeDispatchEnvelope~new(lease,.ManagedTaskRequest~new(spec,auth)),"queue-admin",opts)~ok,kind||" dispatch"
  cycle=agent~runOnce(300)
  call assertTrue cycle~ok,kind||" cycle"
  call assertTrue cycle~result~code=expected,kind||" fails closed"
  call assertTrue \cycle~result~success,kind||" not reported success"
  return

assertTrue: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return

::class CountingExecutor public
::attribute count get
::method init
  expose count
  count=0
::method run
  expose count
  use strict arg executable,entrypoint,arguments,workingDirectory,timeoutSeconds,maxOutputBytes
  count+=1
  return .ManagedCommandExecutionResult~new(0,"SHOULD-NOT-RUN")

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
