/* EyePoke / Low Blow strategies: SLAM selects and scores, but does not
 * decode, register, reconstruct, invent pixels, or promote to observation.
 * Scores are bounded consistency indicators, never forensic certainty.
 */
::class SlamRecoveryStrategy public
/* Signal booleans must be independently measured, not inferred from output. */
::method select
  use strict arg frameCount, translationMeasured, blurMeasured, textureUsable, occlusionMeasured
  methods=.array~new
  if \datatype(frameCount,'W') then return methods
  if frameCount<5 then return methods
  if \translationMeasured then return methods
  methods~append('VIDEO.RECON.LEADING_EDGE_BACKPROJECTION')
  if blurMeasured then methods~append('VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL')
  if textureUsable then methods~append('VIDEO.RECON.FLOW_WARP_ACCUMULATE')
  if occlusionMeasured then methods~append('VIDEO.RECON.MOVING_STRIP_MOSAIC')
  if textureUsable then methods~append('VIDEO.RECON.LATENT_MULTI_FRAME')
  return methods

::method score
  use strict arg assessment, producerId, checkerId
  scorecard=.directory~new
  scorecard['STATUS']='UNQUALIFIED'
  scorecard['SCORE']=0
  scorecard['AUTHORITY']='CONSISTENCY_ONLY'
  scorecard['TESTED']=.false
  if assessment=.nil then return scorecard
  if assessment~status<>'ELIGIBLE' then return scorecard
  if strip(producerId)='' | strip(checkerId)='' then return scorecard
  if producerId=checkerId then return scorecard
  m=assessment~measurements
  if m['CANDIDATE_RESIDUAL']>=m['BASELINE_RESIDUAL'] then do
    scorecard['STATUS']='NO_IMPROVEMENT'
    return scorecard
  end
  gain=(m['BASELINE_RESIDUAL']-m['CANDIDATE_RESIDUAL'])/m['BASELINE_RESIDUAL']
  if gain>0.25 then gain=0.25
  consistency=100*(gain/0.25)*m['SUPPORT_FRACTION']*(1-m['UNCERTAINTY_FRACTION'])
  scorecard['SCORE']=max(0,min(100,consistency))
  scorecard['STATUS']='SCORED_CONSISTENCY'
  /* Independent checker identity is necessary, not enough for TESTED SLAM
   * evidence: the checker must publish its own qualified evidence record. */
  return scorecard
