/* SLAM450 v0.86: independent image-and-ledger target energy hypotheses.
 * No ground truth, model coordinates, target locations or true wind.
 * A 3-pixel target image cannot be used as a precise distance measure:
 * such ranges receive a conservative approximation and LOW confidence.
 * Costs are hypotheses in synthetic battery units, not guarantees.
 */
::requires 'Slam450Battery.cls'
::class Slam450TargetCost public
::attribute lastEstimate get
::method init
  expose lastEstimate
  lastEstimate=.nil
::method estimate
  expose lastEstimate
  use strict arg frame,available,meter,ownEnergy=.nil,tick=0
  if meter['SOURCE']\=='OWN_BATTERY_METER' then ,
    raise syntax 88.900 array('cost estimator needs own battery meter')
  if meter~hasIndex('TRUE_X') | meter~hasIndex('TARGET_X') | ,
     meter~hasIndex('WIND_EAST_MPS') then ,
    raise syntax 88.900 array('oracle values prohibited from cost estimate')
  sight=.Slam450Vision~new
  costs=.array~new;risks=.array~new
  confs=.array~new;theories=.array~new
  burn=1.0;remote=0.6;sampleTurns=0
  if ownEnergy\==.nil then do
    trend=ownEnergy~peerSummary(tick,meter)
    sampleTurns=trend['WINDOW_TURNS']
    if sampleTurns>=2 then do
      burn=max(1,min(9,trend['DELTA_FLIGHT']/sampleTurns))
      remote=max(0,min(3,trend['DELTA_REMOTE']/sampleTurns))
    end
  end
  perTurn=burn+remote+0.03
  remaining=meter['REMAINING']
  reserve=max(25,min(90,remaining*0.12))
  do t=1 to 5
    if \available~hasIndex(t) then do
      costs~append(0);risks~append('CLAIMED')
      confs~append('NONE');theories~append('TARGET_ALREADY_GONE')
      iterate
    end
    observed=sight~observe(frame,t)
    distance=420;search=30;turn=12;climb=0
    theory='HIDDEN_SEARCH';confidence='LOW'
    if observed\==.nil then do
      w=max(observed['WIDTH'],observed['HEIGHT'])
      az=abs(observed['AZ']);el=observed['EL']
      turn=az/15
      search=0
      if w<=3 then do
        distance=300;theory='IMAGE_RANGE_WEAK';confidence='LOW'
      end
      else do
        distance=max(3,min(500,150/max(1,w-2)))
        theory='IMAGE_ANGULAR_RANGE';confidence='MEDIUM'
        if w>=15 then do
          theory='SHORT_RANGE_SIGHTING';confidence='HIGH'
        end
      end
      /* Vertical component inferred from image elevation, not hidden z. */
      climb=max(0,min(70,el*distance/100))
      if climb>8 then theory='CLIMB_LIKELY'
    end
    steps=distance/3+turn+search
    cost=steps*perTurn+0.9*climb
    if sampleTurns>=2 & burn>2.2 then theory='HIGH_DRAIN_OBSERVED'
    uncertainty=1.15
    if confidence=='MEDIUM' then uncertainty=1.4
    if confidence=='LOW' then uncertainty=1.9
    worst=cost*uncertainty
    risk='LOW'
    if confidence=='LOW' then risk='UNCERTAIN'
    if cost>remaining*0.45 then risk='CAUTION'
    if cost>remaining*0.70 then risk='HIGH'
    if worst>remaining-reserve then risk='STRANDED'
    /* Paid communication always carries a bounded, reproducible estimate. */
    costs~append(max(0,min(100000,trunc(cost*1000)/1000)))
    risks~append(risk);confs~append(confidence);theories~append(theory)
  end
  d=.directory~new
  d['COSTS']=costs;d['RISKS']=risks
  d['CONFIDENCES']=confs;d['THEORIES']=theories
  d['BID_REMAINING']=remaining;d['BID_RESERVE']=reserve
  d['ESTIMATED_BURN_PER_TURN']=perTurn
  d['SOURCE']='OWN_PANORAMA_OWN_METER_ESTIMATED_NOT_ORACLE'
  lastEstimate=d
  return d
