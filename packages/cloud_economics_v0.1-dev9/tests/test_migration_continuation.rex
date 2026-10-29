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
/* dev7 native Migratable Job v0.2.2 preflight and transfer-record boundary. */
sourceRequest=request
nativeDef=.MigratableJobDefinition~new('running-demo',request,'definition-1', ,
 'partition-1','node-aws','ooRexx','gen-1','revision-1',.nil,.nil,.true, ,
 .array~of('node-oci'))
mobility=.MigratableJobDestinationPolicy~new('node-aws',.true,.array~of('node-oci'))
cbridge=.CloudMigrationContinuationBridge~new
pre=cbridge~assessPreflight(ans,run,offers,routes,nativeDef,request,mobility)
call assert pre~status='PREFLIGHT_ADVISORY','native portable definition mobility preflight'
call assert \pre~dispatchable & \pre~migrationAllowed & \pre~purchaseAllowed,'no economic effect authority'
call assert pre~expectedGiB=1,'size estimate from route and workload'
restricted=.MigratableJobDestinationPolicy~new('node-aws',.true,.array~of('other-node'))
call assert cbridge~assessPreflight(ans,run,offers,routes,nativeDef,request,restricted)~status='HOLD', ,
 'hard destination policy veto'
wrongDef=.MigratableJobDefinition~new('running-demo',request,'definition-2', ,
 'partition-1','node-aws','other-runtime','gen-1','revision-1')
call assert cbridge~assessPreflight(ans,run,offers,routes,wrongDef,request,mobility)~reason='SOURCE_RUNTIME_MISMATCH', ,
 'different executable runtime veto'
scenario=.CloudMigrationEstateHandoff~new('NATIVE_COMMISSION_SCENARIO_ADVISORY','PROSPECTIVE')
call assert cbridge~assessPreflight(scenario,run,offers,routes,nativeDef,request,mobility)~status='HOLD', ,
 'prospective-only commissioning rejected'
/* This stage is historical: a real source would now be paused and fenced;
 * do NOT call dev6's RUNNING verification again and assume it is current. */
migration=.MigratableJobMigration~new('mig-1',nativeDef,lease,nowMs-10000)
manifest=.MigratableJobCheckpointManifest~new('ck-1','running-demo','mig-1', ,
 'partition-1','node-aws',lease~placementId,lease~ownershipEpoch, ,
 'ooRexx','gen-1','revision-1','storage://ck-1','sha256:one', ,
 'inputs-1','outputs-1',nowMs-2000,nowMs-20000,nowMs-3000,1)
cr=.MigratableJobCheckpointResult~success(manifest,'storage://src-ck')
migration~setCheckpoint(manifest,'storage://src-ck',nowMs-2000)
/* Real destination placement requires a newer ownership epoch and correct job. */
destLease=.JobNodePlacementLease~new('dst-placement','running-demo', ,
 'node-oci','OWNER',1,1,nowMs,nowMs+300000,'req-digest', ,
 'cap-digest','capacity-digest','1','','','',lease~ownershipEpoch+1)
migration~setDestinationLease(destLease,nowMs)
migration~markSourceFenced(nowMs)
migration~markSourceAdmissionReleased(nowMs)
migration~setTransferEvidence('verified-ck-1','storage://dest-ck',nowMs)
migration~transition(.MigratableJobMigrationState~NEW, ,
 .MigratableJobMigrationState~COMMITTING,nowMs)
tr=.MigratableJobTransferResult~new('COMPLETED','verified-ck-1', ,
 'storage://dest-ck',1073741824)
posted=cbridge~assessTransfer(pre,migration,cr,tr,nowMs)
call assert posted~status='TRANSFER_RECORD_ADVISORY','bound transfer records admitted'
call assert posted~evidence['accounting_status']='NOT_POSTED_PROVIDER_INVOICE_NOT_RECONCILED', ,
 'no claim of actual invoicing'
call assert abs(posted~evidence['transfer_cost_variance_usd'])<0.00000001, ,
 'transfer estimate matched 1GiB'
call assert \posted~migrationAllowed & \posted~purchaseAllowed, ,
 'transfer evidence never an actuation authorization'
large=.MigratableJobTransferResult~new('COMPLETED','verified-ck-1', ,
 'storage://dest-ck',2*1073741824)
changed=cbridge~assessTransfer(pre,migration,cr,large,nowMs)
call assert changed~status='TRANSFER_RECORD_ADVISORY', ,
 'double checkpoint bytes reconciled as estimate variance'
call assert changed~evidence['transfer_cost_variance_usd']>0,'extra observed bytes cost more'
wrong=.MigratableJobTransferResult~new('COMPLETED','different-verification', ,
 'storage://dest-ck',1073741824)
call assert cbridge~assessTransfer(pre,migration,cr,wrong,nowMs)~reason='TRANSFER_RECORD_NOT_BOUND', ,
 'mismatched proof rejected'
wrong=.MigratableJobTransferResult~new('PAUSED','verified-ck-1', ,
 'storage://dest-ck',1073741824)
call assert cbridge~assessTransfer(pre,migration,cr,wrong,nowMs)~reason='TRANSFER_NOT_COMPLETED', ,
 'incomplete transfer cannot count'
wrongManifest=.MigratableJobCheckpointManifest~new('ck2','running-demo', ,
 'mig-1','partition-1','bad-node',lease~placementId,lease~ownershipEpoch, ,
 'ooRexx','gen-1','revision-1','storage://ck-1','sha256:one', ,
 'inputs-1','outputs-1',nowMs-2000,nowMs-20000,nowMs-3000,1)
migration~setCheckpoint(wrongManifest,'storage://src-ck',nowMs)
call assert cbridge~assessTransfer(pre,migration, ,
 .MigratableJobCheckpointResult~success(wrongManifest,'storage://src-ck'),tr,nowMs)~reason='CHECKPOINT_IDENTITY_INCONSISTENT', ,
 'source node checkpoint must match issuer placement'
call assert cbridge~assessTransfer(pre,migration,cr,tr,nowMs)~reason='CHECKPOINT_MANIFEST_NOT_BOUND', ,
 'changed native migration state invalidates old receipt'
say 'PASS dev7 native migratable definition, checkpoint/transfer record linkage and cost variance (advisory)'
exit 0
assert: procedure
  use arg ok,label
  if ok then return
  say 'FAIL:' label
  exit 1
::requires 'CloudMigrationContinuationBridge.cls'
::requires 'JobNodeExecutionLifecycle.cls'
::requires 'RegisteredJobExecutionContext.cls'
