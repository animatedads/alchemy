/* MLStorageFabricBridge.cls - optional Storage Fabric v0.1-dev7 integration.
 *
 * ML exports only value-only checkpoint/frontier identity.  Storage Fabric owns
 * workspace placement, replica safety, transfer verification and durable commit.
 */

::class MLStorageCheckpointValue public
::attribute schema
::attribute experimentId
::attribute branch
::attribute checkpointId
::attribute label
::attribute eventName
::attribute timestamp
::attribute positions
::method init
  use strict arg experimentId,branch,checkpoint
  if checkpoint==.nil | \checkpoint~hasMethod('CHECKPOINTID') then raise syntax 88.900 array('ML storage checkpoint value requires State-of-Nation checkpoint')
  self~schema='ml.checkpoint.value/1'; self~experimentId=experimentId; self~branch=branch; self~checkpointId=checkpoint~checkpointId
  self~label=checkpoint~label; self~eventName=checkpoint~eventName; self~timestamp=checkpoint~timestamp
  p=.directory~new; positions=checkpoint~positions; ids=positions~allIndexes; ids~sort
  do id over ids; p[id]=positions[id]~string; end
  self~positions=.MLFrozenMap~new(p)
::method fromExperiment class
  use strict arg experiment,checkpoint=.nil
  if \experiment~isA(.MLExperiment) then raise syntax 88.900 array('checkpoint value requires MLExperiment')
  if checkpoint==.nil then checkpoint=experiment~currentCheckpoint
  return self~new(experiment~id,experiment~currentBranch,checkpoint)
::method canonicalText
  return 'ML_CHECKPOINT_VALUE='||self~schema||'|experiment='||self~experimentId||'|branch='||self~branch||'|checkpoint='||self~checkpointId||'|label='||self~label||'|event='||self~eventName||'|timestamp='||self~timestamp||'0a'x||self~positions~canonicalText

::class MLFrontierEntryValue public
::attribute candidateId
::attribute rank
::attribute crowdingDistance
::attribute scores
::method init
  use strict arg candidateId,rank,crowdingDistance,scores
  self~candidateId=candidateId; self~rank=rank; self~crowdingDistance=crowdingDistance; self~scores=.MLFrozenMap~new(scores)
::method canonicalText
  return 'FRONTIER_ENTRY='||self~candidateId||'|rank='||self~rank||'|crowding='||self~crowdingDistance||'0a'x||self~scores~canonicalText

::class MLDurableFrontierValue public
::attribute schema
::attribute id
::attribute experimentId
::attribute branch
::attribute checkpointId
::attribute objectiveSetId
::attribute constraintSetId
::method init
  expose entries
  use strict arg id,experimentId,branch,checkpointId,objectiveSetId,constraintSetId,sourceEntries
  self~schema='ml.frontier.value/1'; self~id=id; self~experimentId=experimentId; self~branch=branch; self~checkpointId=checkpointId; self~objectiveSetId=objectiveSetId; self~constraintSetId=constraintSetId
  entries=.array~new; do e over sourceEntries; entries~append(e); end
::method entries
  expose entries
  out=.array~new; do e over entries; out~append(e); end; return out
::method canonicalText
  expose entries
  lines=.array~new; lines~append('ML_FRONTIER_VALUE='||self~schema||'|id='||self~id||'|experiment='||self~experimentId||'|branch='||self~branch||'|checkpoint='||self~checkpointId||'|objectives='||self~objectiveSetId||'|constraints='||self~constraintSetId||'|entries='||entries~items)
  do e over entries; lines~append(e~canonicalText); end
  return lines~makeString('L')
::method fromPareto class
  use strict arg id,experiment,checkpoint,result
  if \experiment~isA(.MLExperiment) then raise syntax 88.900 array('frontier value requires MLExperiment')
  entries=.array~new; constraintSetId=''
  if result~isA(.MLConstrainedParetoResult) then do
    objectiveSetId=result~objectiveSetId; constraintSetId=result~constraintSetId; points=result~nonDominated
  end
  else if result~isA(.MLParetoResult) then do
    objectiveSetId=result~objectiveSetId; points=result~nonDominated
  end
  else raise syntax 88.900 array('frontier value requires Pareto result')
  do p over points
    scores=p~objectiveVector~scores~toDirectory
    entries~append(.MLFrontierEntryValue~new(p~subjectId,p~rank,p~crowdingDistance,scores))
  end
  return self~new(id,experiment~id,experiment~currentBranch,checkpoint~checkpointId,objectiveSetId,constraintSetId,entries)

::class MLStorageCommitEvidence public
::attribute objectId
::attribute digest
::attribute requiredReplicas
::attribute durableSatisfied
::attribute locationCount
::attribute durableLocationCount
::method init
  expose locations
  use strict arg object,requiredReplicas,durableSatisfied
  self~objectId=object~ref~objectId; self~digest=object~ref~digest; self~requiredReplicas=requiredReplicas; self~durableSatisfied=durableSatisfied
  self~locationCount=object~locations~items; self~durableLocationCount=0; locations=.array~new
  do location over object~locations
    locations~append(location~canonical)
    if location~countsAsDurable then self~durableLocationCount=self~durableLocationCount+1
  end
::method locations
  expose locations
  out=.array~new; do l over locations; out~append(l); end; return out
::method canonicalText
  expose locations
  lines=.array~new; lines~append('ML_STORAGE_COMMIT=object='||self~objectId||'|digest='||self~digest||'|required='||self~requiredReplicas||'|durable='||self~durableSatisfied||'|locations='||self~locationCount||'|durableLocations='||self~durableLocationCount)
  do l over locations; lines~append(l); end; return lines~makeString('L')

::class MLStorageFabricBridge public
::method placement class
  use strict arg node,inputObjects,workspaceBudget,jobPackageBytes=0,expectedOutputBytes=0,workspaceManager
  if \workspaceBudget~isA(.MLWorkspaceBudget) then raise syntax 88.900 array('ML storage placement requires MLWorkspaceBudget')
  return .StoragePlacementAdvisor~new~assessCandidate(node,inputObjects,workspaceBudget~maximumBytes,jobPackageBytes,expectedOutputBytes,workspaceManager)
::method durableCompletion class
  use strict arg object,requiredReplicas=1
  if requiredReplicas<1 then raise syntax 88.900 array('durable completion requires at least one replica')
  ok=.StorageDurableCompletionPolicy~new~outputSatisfied(object,requiredReplicas)
  return .MLStorageCommitEvidence~new(object,requiredReplicas,ok)
::method retainedFrontierSatisfied class
  use strict arg storageObjects,requiredReplicas=1
  if \storageObjects~isA(.Array) then raise syntax 88.900 array('retained frontier storage objects must be Array')
  results=.array~new; all=.true
  do object over storageObjects
    evidence=self~durableCompletion(object,requiredReplicas); results~append(evidence); if \evidence~durableSatisfied then all=.false
  end
  out=.directory~new; out['satisfied']=all; out['objects']=results; out['requiredReplicas']=requiredReplicas; return out

::requires "OorexxML.cls"
::requires "StorageFabric.cls"
