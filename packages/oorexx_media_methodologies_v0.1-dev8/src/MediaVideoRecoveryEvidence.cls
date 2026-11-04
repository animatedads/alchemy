/* Evidence admission for the existing video reconstruction candidates.
 * No reconstruction algorithm is implemented here and no candidate becomes
 * an original observation. Held-out residuals measure consistency, not truth.
 */
::class MediaVideoRecoveryAssessment public
::method init
  expose status reason measurements
  use strict arg statusArg, reasonArg, measurementsArg=.nil
  status=statusArg
  reason=reasonArg
  measurements=measurementsArg
::attribute status get
::attribute reason get
::attribute measurements get

::class MediaVideoRecoveryEvidence public
::method assess
  use strict arg candidate, measurements
  if candidate=.nil then return .MediaVideoRecoveryAssessment~new('REJECTED','MISSING_CANDIDATE')
  if measurements=.nil then return .MediaVideoRecoveryAssessment~new('REJECTED','MISSING_MEASUREMENTS')
  if \candidate~isA(.MediaExperimentCandidate) then return .MediaVideoRecoveryAssessment~new('REJECTED','WRONG_CANDIDATE_TYPE')
  if \measurements~isA(.Directory) then return .MediaVideoRecoveryAssessment~new('REJECTED','WRONG_MEASUREMENTS_TYPE')
  if candidate~status<>'CANDIDATE' then return .MediaVideoRecoveryAssessment~new('REJECTED','WRONG_AUTHORITY')
  if candidate~candidateKind<>'DERIVED_RECONSTRUCTION' then return .MediaVideoRecoveryAssessment~new('REJECTED','NOT_DERIVED_RECONSTRUCTION')
  if candidate~outputRef=.nil | candidate~outputRef='' then return .MediaVideoRecoveryAssessment~new('REJECTED','NO_MATERIAL')
  if candidate~supportMapRef=.nil | candidate~supportMapRef='' then return .MediaVideoRecoveryAssessment~new('REJECTED','NO_SUPPORT_MAP')
  if candidate~uncertaintyRef=.nil | candidate~uncertaintyRef='' then return .MediaVideoRecoveryAssessment~new('REJECTED','NO_UNCERTAINTY_MAP')
  if candidate~provenanceRefs~items<1 then return .MediaVideoRecoveryAssessment~new('REJECTED','NO_PROVENANCE')
  allowed=' VIDEO.RECON.LEADING_EDGE_BACKPROJECTION VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL VIDEO.RECON.FLOW_WARP_ACCUMULATE VIDEO.RECON.MOVING_STRIP_MOSAIC VIDEO.RECON.LATENT_MULTI_FRAME '
  if pos(' '||candidate~methodologyId||' ',allowed)=0 then return .MediaVideoRecoveryAssessment~new('REJECTED','UNKNOWN_VIDEO_METHOD')
  do key over .array~of('BASELINE_RESIDUAL','CANDIDATE_RESIDUAL','SUPPORT_FRACTION','UNCERTAINTY_FRACTION','HELDOUT_PAIRS')
    if \measurements~hasIndex(key) then return .MediaVideoRecoveryAssessment~new('REJECTED','MISSING_'||key)
    if \datatype(measurements[key],'N') then return .MediaVideoRecoveryAssessment~new('REJECTED','INVALID_'||key)
  end
  if measurements['BASELINE_RESIDUAL']<=0 then return .MediaVideoRecoveryAssessment~new('REJECTED','INVALID_BASELINE')
  if measurements['CANDIDATE_RESIDUAL']<0 then return .MediaVideoRecoveryAssessment~new('REJECTED','INVALID_RESIDUAL')
  if measurements['SUPPORT_FRACTION']<0 | measurements['SUPPORT_FRACTION']>1 then return .MediaVideoRecoveryAssessment~new('REJECTED','INVALID_SUPPORT')
  if measurements['UNCERTAINTY_FRACTION']<0 | measurements['UNCERTAINTY_FRACTION']>1 then return .MediaVideoRecoveryAssessment~new('REJECTED','INVALID_UNCERTAINTY')
  if \datatype(measurements['HELDOUT_PAIRS'],'W') then return .MediaVideoRecoveryAssessment~new('REJECTED','INVALID_HELDOUT')
  if measurements['HELDOUT_PAIRS']<3 then return .MediaVideoRecoveryAssessment~new('REJECTED','INSUFFICIENT_HOLDOUT')
  return .MediaVideoRecoveryAssessment~new('ELIGIBLE','CONSISTENCY_ONLY',measurements)

::requires 'MediaMethodologyExperiments.cls'
