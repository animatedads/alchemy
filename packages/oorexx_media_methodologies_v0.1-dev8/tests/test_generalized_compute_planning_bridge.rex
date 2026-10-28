#!/usr/bin/env rexx
abilities=.array~of('MEDIA.AUDIO.PCM')
profile=.MediaImplementationExecutionProfile~new('impl/1','AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP','PYTHON3',abilities)
selection=.MediaExperimentMethodSelection~new('AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP',profile,'LINEAGE-SI')
unit=.MediaWorkUnit~new('WORK-1','AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP','SAMPLE',1,100,1,100,1)
task=.MediaExperimentTask~new('EXP-1','LINEAGE-SI',selection,unit)
resource=.TestResource~new('MI-TEST')
allow=.AllowAdapter~new
planner=.GeneralizedComputeIntentionProvider~new(.ComputeAdapter~new(resource),allow,allow,allow)
bridge=.MediaGeneralizedComputeBridge~new
obs=bridge~plan(planner,task,profile,.array~of('sha256:source'))
call assertTrue obs~ready,'plan ready'
call assertEq 'NONE',obs~mutationAuthority,'bridge has no mutation authority'
call assertTrue obs~revalidationRequired,'bridge requires revalidation'
call assertTrue obs~workload~task==task,'exact task retained'
call assertTrue obs~workload~executionProfile==profile,'exact execution profile retained'
prep=bridge~prepare(planner,task,profile,.array~of('sha256:source'))
call assertTrue prep~handoff<>.nil,'handoff prepared'
call assertTrue prep~handoff~revalidationRequired,'upstream handoff requires revalidation'
call assertTrue prep~handoff~workload==prep~workload,'workload object retained in handoff'
say 'PASS generalized compute bridge plans media work without placement authority'
exit 0
assertTrue: procedure
  use arg value,label
  if value then return
  say 'FAIL' label
  exit 1
assertEq: procedure
  use arg expected,actual,label
  if expected==actual then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1
::class TestResource
::method init
  expose id
  use arg id
::attribute id
::class ComputeAdapter subclass ComputeIntentionAdapter
::method init
  expose resource
  use arg resource
::method discoverCandidates
  expose resource
  use arg workload,context=.nil
  return .array~of(resource)
::method assess
  use arg workload,resource,context=.nil
  return .IntentionAssessment~new(.true,'compute','CAPABLE',resource)
::class AllowAdapter
::method assess
  use arg workload,resource,context=.nil
  return .IntentionAssessment~new(.true,'authority','ALLOW',resource)
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaMethodologyExperiments.cls'
::requires 'MediaGeneralizedComputeBridge.cls'
::requires 'GeneralizedComputeIntentions.cls'
