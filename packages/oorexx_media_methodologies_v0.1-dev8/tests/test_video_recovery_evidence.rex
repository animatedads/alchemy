/* Synthetic candidate references and measurements only. */
refs=.array~of('synthetic-source-ref')
candidate=.MediaExperimentCandidate~new('synthetic-candidate','synthetic-exp','line-a', -
  'VIDEO.RECON.FLOW_WARP_ACCUMULATE','native.provider','DERIVED_RECONSTRUCTION', -
  .nil,'synthetic-output','synthetic-support','synthetic-uncertainty',refs)
gate=.MediaVideoRecoveryEvidence~new
m=.directory~new
m['BASELINE_RESIDUAL']=10
m['CANDIDATE_RESIDUAL']=9
m['SUPPORT_FRACTION']=0.7
m['UNCERTAINTY_FRACTION']=0.2
m['HELDOUT_PAIRS']=4
call expect gate~assess(candidate,m),'ELIGIBLE','CONSISTENCY_ONLY'
m['HELDOUT_PAIRS']=2
call expect gate~assess(candidate,m),'REJECTED','INSUFFICIENT_HOLDOUT'
m['HELDOUT_PAIRS']=4
m['SUPPORT_FRACTION']=1.1
call expect gate~assess(candidate,m),'REJECTED','INVALID_SUPPORT'
m['SUPPORT_FRACTION']=0.7
m['CANDIDATE_RESIDUAL']=-1
call expect gate~assess(candidate,m),'REJECTED','INVALID_RESIDUAL'
m['CANDIDATE_RESIDUAL']=9
call expect gate~assess(candidate,.nil),'REJECTED','MISSING_MEASUREMENTS'
say 'MEDIA_RECOVERY_EVIDENCE 5/5 PASS'
exit 0
::routine expect
  use strict arg assessment, status, reason
  if assessment~status<>status then raise syntax 93.900 array('FAIL status',status,assessment~status)
  if assessment~reason<>reason then raise syntax 93.900 array('FAIL reason',reason,assessment~reason)
::requires 'MediaVideoRecoveryEvidence.cls'
