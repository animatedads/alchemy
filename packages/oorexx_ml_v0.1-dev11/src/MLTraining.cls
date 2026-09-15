/* MLTraining.cls - driveable training sessions and optimizer state.
 *
 * Training state is deliberately separate from model state.  MLTrainingRun
 * coordinates model + optimizer + session through State-of-the-Nation so a
 * rollback restores all three together.
 */

::class MLGradientDescentOptimizer subclass MLDriveableObject public
::method init
  use strict arg stableId='GRADIENT_DESCENT',learningRate=0.01,momentum=0
  if learningRate<=0 then raise syntax 88.900 array('optimizer learning rate must be positive')
  if momentum<0 | momentum>=1 then raise syntax 88.900 array('optimizer momentum must be in [0,1)')
  initial=.directory~new; initial['learningRate']=learningRate; initial['momentum']=momentum; initial['step']=0; initial['velocity']=.MLFrozenVector~new(.array~new)
  self~init:super(stableId,'GRADIENT_DESCENT_OPTIMIZER',initial)
::method learningRate; return self~at('learningRate')
::method momentum; return self~at('momentum')
::method step; return self~at('step')
::method setLearningRate
  use strict arg learningRate
  if learningRate<=0 then raise syntax 88.900 array('optimizer learning rate must be positive')
  c=.directory~new; c['learningRate']=learningRate; return self~mutate(c,'OPTIMIZER_LEARNING_RATE')
::method setMomentum
  use strict arg momentum
  if momentum<0 | momentum>=1 then raise syntax 88.900 array('optimizer momentum must be in [0,1)')
  c=.directory~new; c['momentum']=momentum; return self~mutate(c,'OPTIMIZER_MOMENTUM')
::method apply
  use strict arg parameters,gradients,tag='OPTIMIZER_STEP'
  if \parameters~isA(.Array) | \gradients~isA(.Array) | parameters~items<>gradients~items | parameters~items=0 then raise syntax 88.900 array('optimizer parameter/gradient arrays must have equal nonzero length')
  oldVelocity=self~at('velocity'); velocity=.array~new; out=.array~new
  do i=1 to parameters~items
    if oldVelocity~items=parameters~items then old=oldVelocity[i]; else old=0
    v=(self~at('momentum')*old)+gradients[i]
    velocity~append(v); out~append(parameters[i]-(self~at('learningRate')*v))
  end
  c=.directory~new; c['velocity']=.MLFrozenVector~new(velocity); c['lastGradient']=.MLFrozenVector~new(gradients); c['step']=self~at('step')+1
  self~mutate(c,tag)
  return .MLFrozenVector~new(out)

::class MLTrainingSession subclass MLDriveableObject public
::method init
  use strict arg runId,modelId='',datasetId='',optimizerId='',goal='MINIMIZE'
  g=goal~translate; if g<>'MINIMIZE' & g<>'MAXIMIZE' then raise syntax 88.900 array('training goal must be MINIMIZE or MAXIMIZE')
  initial=.directory~new; initial['runId']=runId; initial['modelId']=modelId; initial['datasetId']=datasetId; initial['optimizerId']=optimizerId
  initial['goal']=g; initial['status']='CREATED'; initial['epoch']=0; initial['step']=0; initial['objective']=.nil; initial['bestObjective']=.nil; initial['bestEpoch']=0; initial['lastMetrics']=.nil
  self~init:super('TRAINING:'||runId,'TRAINING_SESSION',initial)
::method runId; return self~at('runId')
::method status; return self~at('status')
::method epoch; return self~at('epoch')
::method step; return self~at('step')
::method begin
  use strict arg metadata=.nil
  if self~at('status')<>'CREATED' then raise syntax 88.900 array('training session can begin only from CREATED')
  c=.directory~new; c['status']='RUNNING'; c['startMetadata']=metadata
  return self~mutate(c,'TRAINING_BEGIN',metadata)
::method recordStep
  use strict arg objective=.nil,metrics=.nil,metadata=.nil
  if self~at('status')<>'RUNNING' then raise syntax 88.900 array('training step requires RUNNING session')
  c=.directory~new; c['step']=self~at('step')+1
  if objective\==.nil then c['objective']=objective
  if metrics\==.nil then do; if \metrics~isA(.Directory) then raise syntax 88.900 array('training metrics must be Directory'); c['lastMetrics']=.MLFrozenMap~new(metrics); end
  return self~mutate(c,'TRAINING_STEP',metadata)
::method recordEpoch
  use strict arg epoch,objective,metrics=.nil,metadata=.nil
  if self~at('status')<>'RUNNING' then raise syntax 88.900 array('training epoch requires RUNNING session')
  if epoch<1 then raise syntax 88.900 array('training epoch must be positive')
  c=.directory~new; c['epoch']=epoch; c['objective']=objective
  if metrics\==.nil then do; if \metrics~isA(.Directory) then raise syntax 88.900 array('training metrics must be Directory'); c['lastMetrics']=.MLFrozenMap~new(metrics); end
  best=self~at('bestObjective'); improved=.false
  if best==.nil then improved=.true
  else if self~at('goal')='MINIMIZE' & objective<best then improved=.true
  else if self~at('goal')='MAXIMIZE' & objective>best then improved=.true
  if improved then do; c['bestObjective']=objective; c['bestEpoch']=epoch; end
  return self~mutate(c,'TRAINING_EPOCH',metadata)
::method complete
  use strict arg metadata=.nil
  if self~at('status')<>'RUNNING' then raise syntax 88.900 array('training completion requires RUNNING session')
  c=.directory~new; c['status']='COMPLETE'; c['completionMetadata']=metadata; return self~mutate(c,'TRAINING_COMPLETE',metadata)
::method fail
  use strict arg reason,metadata=.nil
  if self~at('status')<>'RUNNING' then raise syntax 88.900 array('training failure requires RUNNING session')
  c=.directory~new; c['status']='FAILED'; c['failureReason']=reason; c['failureMetadata']=metadata; return self~mutate(c,'TRAINING_FAILED',metadata)
::method evidence
  use strict arg model=.nil,optimizer=.nil,checkpoint=.nil
  return .MLTrainingEvidence~new(self,model,optimizer,checkpoint)

::class MLTrainingEvidence public
::attribute runId
::attribute status
::attribute branch
::attribute sessionPoint
::attribute modelId
::attribute modelPoint
::attribute optimizerId
::attribute optimizerPoint
::attribute datasetId
::attribute epoch
::attribute step
::attribute objective
::attribute bestObjective
::attribute bestEpoch
::attribute checkpointId
::attribute metrics
::method init
  use strict arg session,model=.nil,optimizer=.nil,checkpoint=.nil
  self~runId=session~at('runId'); self~status=session~at('status'); self~branch=session~currentBranch; self~sessionPoint=session~journalPoint~string
  self~datasetId=session~at('datasetId'); self~epoch=session~at('epoch'); self~step=session~at('step'); self~objective=session~at('objective'); self~bestObjective=session~at('bestObjective'); self~bestEpoch=session~at('bestEpoch'); self~metrics=session~at('lastMetrics')
  self~modelId=''; self~modelPoint=''; if model\==.nil then do; self~modelId=model~stableId; self~modelPoint=model~journalPoint~string; end
  self~optimizerId=''; self~optimizerPoint=''; if optimizer\==.nil then do; self~optimizerId=optimizer~stableId; self~optimizerPoint=optimizer~journalPoint~string; end
  self~checkpointId=''; if checkpoint\==.nil then self~checkpointId=checkpoint~checkpointId
::method canonicalText
  return 'TRAINING='||self~runId||'|status='||self~status||'|branch='||self~branch||'|sessionPoint='||self~sessionPoint||'|model='||self~modelId||'@'||self~modelPoint||'|optimizer='||self~optimizerId||'@'||self~optimizerPoint||'|dataset='||self~datasetId||'|epoch='||self~epoch||'|step='||self~step||'|objective='||self~objective||'|best='||self~bestObjective||'@'||self~bestEpoch||'|checkpoint='||self~checkpointId

::class MLTrainingRun public
::method init
  expose runId experiment session model optimizer initialCheckpoint
  use strict arg runId,model,optimizer=.nil,datasetId='',goal='MINIMIZE',experiment=.nil
  if experiment==.nil then experiment=.MLExperiment~new('TRAINING:'||runId)
  optimizerId=''
  if optimizer\==.nil then optimizerId=optimizer~stableId
  session=.MLTrainingSession~new(runId,model~stableId,datasetId,optimizerId,goal)
  if experiment~participant('model')\==.nil then raise syntax 88.900 array('training experiment already has model participant')
  experiment~register('model',model)
  if optimizer\==.nil then do
    if experiment~participant('optimizer')\==.nil then raise syntax 88.900 array('training experiment already has optimizer participant')
    experiment~register('optimizer',optimizer)
  end
  if experiment~participant('session')\==.nil then raise syntax 88.900 array('training experiment already has session participant')
  experiment~register('session',session)
  initialCheckpoint=experiment~checkpoint('training-initial','TRAINING_INITIAL')
::method id; expose runId; return runId
::method experiment; expose experiment; return experiment
::method session; expose session; return session
::method model; expose model; return model
::method optimizer; expose optimizer; return optimizer
::method initialCheckpoint; expose initialCheckpoint; return initialCheckpoint
::method checkpoint
  expose experiment
  use strict arg label='training-checkpoint',eventName='TRAINING',metadata=.nil
  return experiment~checkpoint(label,eventName,metadata)
::method rollback
  expose experiment
  use strict arg checkpoint,preserveAs=''
  return experiment~rollback(checkpoint,preserveAs)
::method branch
  expose experiment
  use strict arg name,fromCheckpoint=.nil
  return experiment~branch(name,fromCheckpoint)
::method checkout
  expose experiment
  use strict arg name
  return experiment~checkout(name)
::method rollForward
  expose experiment
  use strict arg name
  return experiment~rollForward(name)

::requires "MLCore.cls"
