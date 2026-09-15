digest=.WorkBundleCryptoSHA256Digest~new
bundleProof=.FakeNamedProof~new("bundle")
taskProof=.FakeNamedProof~new("task")
leaseProof=.FakeLeaseProof~new("lease")
root=directory()||"/fixtures"
bundle=.WorkBundleBuilder~new(digest,bundleProof)~seal(root,"B-RETRY","BUILD","K",.array~of("task.rex"),.array~of("task.rex"),.array~of("TEST"),.array~of("OOREXX"),"ssc:retry",1,10000)
repo=.InMemoryWorkBundleRepository~new; ref=repo~put(bundle)
lease=.JobNodePlacementLease~new("P-RETRY","JOB-RETRY","NODE-X","CONTROL",1,1,100,5000,"r","c","o","1","proof","","",1,0,"")
lease~signature=leaseProof~sign(lease~canonical)
spec=.ManagedTaskSpec~new("JOB-RETRY","TEST",ref,"OOREXX","task.rex",.array~of("x"),30,"late-results",1024)
auth=.ManagedTaskAuthorizer~new(digest,taskProof,"AUTH","K")~issue(spec,lease,110,4000)
env=.ManagedNodeDispatchEnvelope~new(lease,.ManagedTaskRequest~new(spec,auth))

mgr=.ObjectQueueManager~new("",.nil,"queue-admin")
call assertTrue mgr~createQueue("node-x","TEMPORARY","M",10,"queue-admin")~ok,"work queue"
dispatch=.JobNodeQueueFabricDispatcher~new(mgr)~bindNodeQueue("NODE-X","node-x")
call assertTrue dispatch~dispatch(env,"queue-admin")~ok,"dispatch"
exec=.CountingExecutor~new
runtime=.ManagedRuntimeRegistry~new~register("OOREXX","/usr/local/bin/rexx")
stager=.ManagedBundleStager~new("/tmp/oorexx-managed-node-retry",digest)
agent=.ManagedNodeAgent~new("NODE-X",mgr,"node-x","queue-admin",repo,.WorkBundleVerifier~new(digest,bundleProof),.ManagedTaskAuthorizationVerifier~new(digest,taskProof),.ManagedPlacementVerifier~new(leaseProof,.true),runtime,stager,exec,.nil,.false)
first=agent~runOnce(200)
call assertTrue first~code="RESULT_DELIVERY_FAILED","delivery failure causes NACK"
call assertTrue exec~count=1,"executed once before retry"
call assertTrue mgr~depth("node-x","queue-admin")~value["ready"]=1,"work requeued"
call assertTrue mgr~createQueue("late-results","TEMPORARY","M",10,"queue-admin")~ok,"late result queue"
second=agent~runOnce(210)
call assertTrue second~ok,"retry processed"
call assertTrue exec~count=1,"retry reused cached attempt"
r=mgr~get("late-results","queue-admin"); call assertTrue r~ok,"result delivered"
call assertTrue r~value~payload~code="COMPLETED","cached completion retained"
address system "rm -rf /tmp/oorexx-managed-node-retry"
say "PASS Managed Node result-delivery retry is execution-idempotent in-process"
exit 0

assertTrue: procedure
 use arg c,l
 if \c then do; say "FAIL" l; exit 1; end
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
  return .ManagedCommandExecutionResult~new(0,"COUNTED","",.false,.false)

::class FakeNamedProof public
::method init
 expose key
 use strict arg k
 key=k
::method sign
 expose key
 use strict arg i,k,c
 return .SHA256~new(key||i||k||c)~digest
::method verify
 use strict arg i,k,c,s
 return s=self~sign(i,k,c)

::class FakeLeaseProof public subclass JobNodeProofAuthority
::method init
 expose key
 use strict arg k
 key=k
::method sign
 expose key
 use strict arg c
 return .SHA256~new(key||c)~digest
::method verify
 use strict arg c,s
 return s=self~sign(c)

::requires "../src/ManagedNode.cls"
::requires "JobNodeQueueFabricAdapter.cls"
