GB=1024*1024*1024
wm=.StorageWorkspaceManager~new
safe=.StorageServiceLifecycle~new(.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE)
scratchLife=.StorageServiceLifecycle~new(.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~TEMPORARY)
safePool=.StoragePool~new('safe','local','/safe','fs:safe',.StoragePoolMode~BOTH,0,'n1','UK',safe)
scratch=.StoragePool~new('scratch','cloud','/scratch','fs:scratch',.StoragePoolMode~WORKSPACE,0,'n2','UK',scratchLife)
wm~registerPool(safePool)~registerPool(scratch)
wm~observeCapacity(.StorageCapacityObservation~new('fs:safe',20*GB,20*GB))
wm~observeCapacity(.StorageCapacityObservation~new('fs:scratch',100*GB,100*GB))
workspace=.MLWorkspaceBudget~gib(7,1,8,24)
pe=.MLStorageFabricBridge~placement('n2',.array~new,workspace,1024,2*GB,wm)
call true pe~feasible,'disposable node is valid workspace'
call eq pe~mandatoryOutputCommitBytes,2*GB,'disposable workspace requires output commit'

/* Durable completion remains Storage Fabric authority. */
obj=.StorageObject~new(.StorageRef~new('frontier:1','sha256:abc'),'frontier.value',100,'text/plain')
unsafeLoc=.StorageLocation~new('cloud','/scratch/frontier','fs:scratch',.StorageLocationState~AVAILABLE,'',.true,'sha256:abc',.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~TEMPORARY,'n2')
obj~addLocation(unsafeLoc)
e1=.MLStorageFabricBridge~durableCompletion(obj,1)
call true \e1~durableSatisfied,'verified disposable copy is not durable completion'
safeLoc=.StorageLocation~new('local','/safe/frontier','fs:safe',.StorageLocationState~AVAILABLE,'',.true,'sha256:abc',.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,'n1')
obj~addLocation(safeLoc)
e2=.MLStorageFabricBridge~durableCompletion(obj,1)
call true e2~durableSatisfied,'verified safe stable replica satisfies durable completion'

/* ML checkpoint export is value-only. */
state=.MLDriveableObject~new('MODEL','MODEL',.directory~new)
exp=.MLExperiment~new('STORE-EXP'); exp~register('model',state); cp=exp~checkpoint('publish','TEST')
cv=.MLStorageCheckpointValue~fromExperiment(exp,cp)
call eq cv~checkpointId,cp~checkpointId,'checkpoint identity preserved'
call true cv~canonicalText~pos('model=')>0,'participant point exported as value identity'
say 'PASS test_storage_fabric_bridge'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "MLStorageFabricBridge.cls"
