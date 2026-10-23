/* dev6 estate-native migration advisory. Real JNA lease verifier, real JNA
 * lifecycle evidence and real Memory Fabric execution-context planner. */
numeric digits 30
base=arg(1)
run=.CloudEconomicIO~read(base||'/fixtures/mobility_running.tsv')[1]
routes=.CloudEconomicIO~read(base||'/fixtures/mobility_routes.tsv')
offers=.CloudEconomicIO~read(base||'/fixtures/mobility_offers.tsv')
terms=.CloudEconomicIO~read(base||'/fixtures/mobility_terms.tsv')
now=1791000000; nowMs=now*1000
u=.array~of('UK')
req=.JobNodeRequirement~new(u,.nil,.nil,.nil,.nil,.array~of('ooRexx'), ,
 .nil,'',65536,0,8,65536,0,8)
request=.JobPlacementRequest~new('running-demo',req,'OWNER')
registry=.NodeCapabilityRegistry~new
srcCap=.NodeCapabilityStatement~new('node-aws',1,'cap-aws',u, ,
 .nil,.nil,.nil,.nil,.array~of('ooRexx'),.nil,'',65536,0,8)
srcObs=.NodeCapacityObservation~new('node-aws',1,1,nowMs-1000, ,
 nowMs+600000,65536,0,8,0)
call assert registry~advertiseCapability(srcCap),'source node capability'
call assert registry~observeCapacity(srcObs),'source node capacity'
allocator=.JobNodeAllocator~new(registry)
placed=allocator~allocate(request,nowMs,300000)
call assert placed~placed,'native placement created'
lease=placed~lease
call assert allocator~verifyLease(lease,request,nowMs),'native issued lease valid'
lifecycle=.JobNodeExecutionLifecycleRegistry~new
runningState=.JobNodeExecutionLifecycleState~new('running-demo', ,
 lease~placementId,lease~ownershipEpoch,'RUNNING','EXEC-A','RUN1', ,
 nowMs-1000,.false,'RESTORED')
call assert lifecycle~restore(runningState),'native lifecycle replay state'
source=.directory~new; source['offer_id']='aws-64'; source['node_id']='node-aws'
/* Separate eligible destination node observation, not a fabricated cloud buy. */
dstCap=.NodeCapabilityStatement~new('node-oci',1,'cap-oci',u, ,
 .nil,.nil,.nil,.nil,.array~of('ooRexx'),.nil,'',65536,0,8)
dstObs=.NodeCapacityObservation~new('node-oci',1,1,nowMs-1000, ,
 nowMs+600000,65536,0,8,0)
destBind=.directory~new; destBind['offer_id']='oci-64';destBind['node_id']='node-oci'
p=.directory~new
p['binding']=destBind; p['request']=request; p['capability']=dstCap;p['capacity']=dstObs
proofs=.directory~new;proofs['oci-64']=p
/* Use dev9's actual registered execution-context planning and Memory Fabric. */
GB=1073741824
memreg=.MemoryFabricRegistry~new('economics-native')
memreg~registerProvider(.MemoryFabricProvider~new('mem-oci','MI', ,
 'MU-OCI','MI-OCI','oci-london-ad-1','host-oci','queue://oci',64*GB,0, ,
 'ACTIVE','ACCEPTING',1,1,'boot-oci'))
mp=.MemoryFabricCapacityPlanner~new(memreg)
profile=.RegisteredJobExecutionProfile~new('FULL',64*GB,64*GB,1, ,
 .MemoryFabricLocality~SAME_SITE,0,1,.true)
storage=.RegisteredJobStorageEvidence~new('node-oci',.true,0,0, ,
 .true,0,'storage-native')
node=.RegisteredJobNodeCandidate~new('node-oci','MU-OCI','MI-OCI', ,
 'host-oci','oci-london-ad-1',.true,.true,5,0,'',storage)
ctx=.RegisteredJobExecutionContextPlanner~new(mp)~choose( ,
 .array~of(profile),.array~of(node))
call assert ctx~action='RUN_EXISTING','native memory context chosen'
call assert ctx~memoryPlan~complete,'native memory plan complete'
contexts=.directory~new; contexts['oci-64']=ctx
bridge=.CloudMigrationEstateBridge~new
ans=bridge~evaluate(run,routes,offers,now,terms,lease,request, ,
 allocator,lifecycle,source,proofs,.JobNodeEligibilityPolicy~new,contexts)
call assert ans~status='NATIVE_ELIGIBLE_ADVISORY','native authority passes'
call assert ans~decision['status']='PAPER_MOVE_FAVORED','economic move under authority'
call assert ans~decision['selected']='oci-64','chosen destination preserved'
call assert \ans~dispatchable & \ans~migrationAllowed & \ans~purchaseAllowed, ,
 'handoff never owns effects'
call assert ans~lease==lease & ans~context==ctx,'native objects retained'
/* Prospective commissioning must not be mislabelled as running capacity. */
contexts['oci-64']=.RegisteredJobExecutionContextPlan~new('COMMISSION', ,
 node,profile,ctx~memoryPlan,'prospective only',0)
scenario=bridge~evaluate(run,routes,offers,now,terms,lease,request, ,
 allocator,lifecycle,source,proofs,.JobNodeEligibilityPolicy~new,contexts)
call assert scenario~status='NATIVE_COMMISSION_SCENARIO_ADVISORY', ,
 'commissioning not represented as acquired capacity'
contexts['oci-64']=ctx
/* Bad destination capacity/placement invalidates the route but not source. */
p['capacity']=.NodeCapacityObservation~new('node-oci',1,1, ,
 nowMs-600000,nowMs-1,65536,0,8,0)
x=bridge~evaluate(run,routes,offers,now,terms,lease,request, ,
 allocator,lifecycle,source,proofs,.JobNodeEligibilityPolicy~new,contexts)
call assert x~status='NATIVE_STAY_OR_HOLD','expired destination observation'
absent=bridge~evaluate(run,routes,offers,now,terms,lease,request, ,
 allocator,.JobNodeExecutionLifecycleRegistry~new,source,proofs, ,
 .JobNodeEligibilityPolicy~new,contexts)
call assert absent~reason='RUNNING_EXECUTION_NOT_OBSERVED','no native running evidence'
emptyProof=.directory~new
noDest=bridge~evaluate(run,routes,offers,now,terms,lease,request, ,
 allocator,lifecycle,source,emptyProof,.JobNodeEligibilityPolicy~new,contexts)
call assert noDest~status='NATIVE_STAY_OR_HOLD','no destination JNA evidence'
siteCandidate=.RegisteredJobNodeCandidate~new('node-oci','MU-OCI', ,
 'MI-OCI','host-oci','wrong-site',.true,.true,5,0,'',storage)
contexts['oci-64']=.RegisteredJobExecutionContextPlan~new('RUN_EXISTING', ,
 siteCandidate,profile,ctx~memoryPlan,'wrong site',0)
wrongSite=bridge~evaluate(run,routes,offers,now,terms,lease,request, ,
 allocator,lifecycle,source,proofs,.JobNodeEligibilityPolicy~new,contexts)
call assert wrongSite~status='NATIVE_STAY_OR_HOLD','site of memory plan cannot differ'
contexts['oci-64']=ctx
p['capacity']=dstObs
wrong=.RegisteredJobNodeCandidate~new('wrong-node','MU-OCI','MI-OCI', ,
 'host-oci','oci-london-ad-1',.true,.true,5,0,'',storage)
contexts['oci-64']=.RegisteredJobExecutionContextPlan~new('RUN_EXISTING', ,
 wrong,profile,ctx~memoryPlan,'claimed',0)
x=bridge~evaluate(run,routes,offers,now,terms,lease,request, ,
 allocator,lifecycle,source,proofs,.JobNodeEligibilityPolicy~new,contexts)
call assert x~status='NATIVE_STAY_OR_HOLD','wrong context-node binding'
contexts['oci-64']=ctx
/* A changed source capability digest kills the lease, not just its route. */
srcCap~setOnline(.false)
x=bridge~evaluate(run,routes,offers,now,terms,lease,request, ,
 allocator,lifecycle,source,proofs,.JobNodeEligibilityPolicy~new,contexts)
call assert x~reason='SOURCE_LEASE_NOT_CURRENT','revoked source capability'
srcCap~setOnline(.true)
/* Revived source, but uncertain execution is NOT proof of RUNNING. */
uncertain=.JobNodeExecutionLifecycleState~new('running-demo', ,
 lease~placementId,lease~ownershipEpoch,'RUNNING','EXEC-A','UNCERTAIN1', ,
 nowMs,.true,'START_UNCERTAIN_PLACEMENT_HELD')
call assert lifecycle~restore(uncertain),'restored uncertainty state'
x=bridge~evaluate(run,routes,offers,now,terms,lease,request, ,
 allocator,lifecycle,source,proofs,.JobNodeEligibilityPolicy~new,contexts)
call assert x~reason='EXECUTION_NOT_CERTAINLY_RUNNING','uncertain start freezes plan'
/* Restore fresh RUNNING; old ownership/evidence becomes unusable. */
newrun=.JobNodeExecutionLifecycleState~new('running-demo', ,
 lease~placementId,lease~ownershipEpoch,'RUNNING','EXEC-A','RUN2', ,
 nowMs,.false,'RESTORED')
call assert lifecycle~restore(newrun),'restored fresh running state'
x=bridge~evaluate(run,routes,offers,now+301,terms,lease,request, ,
 allocator,lifecycle,source,proofs,.JobNodeEligibilityPolicy~new,contexts)
call assert x~status='EVIDENCE_HOLD','lease or execution stale after time'
/* A cheap offer cannot bypass the memory and storage execution context. */
call assert allocator~verifyLease(lease,request,nowMs),'lease did not mutate'
call assert ans~decision['baseline']>ans~decision['cost'],'real saving after gates'
say 'PASS dev6 native lease/lifecycle/context migration advisory and vetoes'
exit 0
assert: procedure
  use arg ok,label
  if ok then return
  say 'FAIL:' label
  exit 1
::requires 'CloudMigrationEstateBridge.cls'
::requires 'JobNodeExecutionLifecycle.cls'
::requires 'RegisteredJobExecutionContext.cls'
