/* AudioV9SoftReconstruction.cls - dev2 time-varying speech-preserving reconstruction plan. */
::options numeric inherit

::class AudioV9ReconstructionPlanRow public
::method init
  expose startSample endSample lagBSamples weightA weightB gain sourceFamily reason
  use strict arg startValue,endValue,lagValue,weightAValue,weightBValue,gainValue,familyValue='UNLABELLED',reasonValue='EVIDENCE'
  startSample=startValue+0; endSample=endValue+0; lagBSamples=lagValue+0; weightA=weightAValue+0; weightB=weightBValue+0; gain=gainValue+0; sourceFamily=familyValue~string; reason=reasonValue~string
  if startSample<0 | endSample<=startSample then raise syntax 88.900 array('invalid reconstruction row sample range')
  if weightA<0 | weightB<0 | weightA+weightB<=0 then raise syntax 88.900 array('invalid reconstruction weights')
  if gain<=0 then raise syntax 88.900 array('reconstruction gain must be positive')
::method startSample; expose startSample; return startSample
::method endSample; expose endSample; return endSample
::method lagBSamples; expose lagBSamples; return lagBSamples
::method weightA; expose weightA; return weightA
::method weightB; expose weightB; return weightB
::method gain; expose gain; return gain
::method sourceFamily; expose sourceFamily; return sourceFamily
::method reason; expose reason; return reason
::method tsv
  return self~startSample||'09'x||self~endSample||'09'x||self~lagBSamples||'09'x||self~weightA||'09'x||self~weightB||'09'x||self~gain||'09'x||self~sourceFamily||'09'x||self~reason

::class AudioV9SoftReconstructionPolicy public
::method init
  expose targetRms targetPeak maxGainDb minGainDb coherenceGate strongCoherenceGate impulseCrest maxGainStepDb
  use strict arg targetRmsValue=.06,targetPeakValue=.92,maxGainDbValue=32,minGainDbValue=0,coherenceGateValue=.15,strongCoherenceGateValue=.35,impulseCrestValue=7,maxGainStepDbValue=3
  targetRms=targetRmsValue+0; targetPeak=targetPeakValue+0; maxGainDb=maxGainDbValue+0; minGainDb=minGainDbValue+0
  coherenceGate=coherenceGateValue+0; strongCoherenceGate=strongCoherenceGateValue+0; impulseCrest=impulseCrestValue+0; maxGainStepDb=maxGainStepDbValue+0
  if targetRms<=0 | targetPeak<=0 | targetPeak>1 then raise syntax 88.900 array('invalid reconstruction level targets')
  if strongCoherenceGate<coherenceGate then raise syntax 88.900 array('strong coherence gate must be >= coherence gate')
::method planRow
  expose targetRms targetPeak maxGainDb minGainDb coherenceGate strongCoherenceGate impulseCrest maxGainStepDb
  use strict arg startSample,endSample,measurement,familyEvidence=.nil,previousGain=.nil
  if \measurement~isA(.AudioV9SpatialMeasurement) then raise syntax 88.900 array('reconstruction policy requires spatial measurement')
  ra=measurement~rmsA; rb=measurement~rmsB; coh=measurement~refinedCoherence; score=measurement~refinedScore
  /* Energy never decides source identity.  It only breaks a tie when the spatial relation is weak. */
  if coh>=strongCoherenceGate & score>0 then do
    wa=.5; wb=.5; reason='COHERENT_DUAL_FEED'
  end
  else if coh>=coherenceGate & score>0 then do
    if ra>=rb then do; wa=.65; wb=.35; reason='FC_LEADS_WEAK_COHERENCE'; end
    else do; wa=.35; wb=.65; reason='FD_LEADS_WEAK_COHERENCE'; end
  end
  else do
    if ra>=rb then do; wa=.85; wb=.15; reason='FC_DOMINANT_LOW_COHERENCE'; end
    else do; wa=.15; wb=.85; reason='FD_DOMINANT_LOW_COHERENCE'; end
  end
  sourceRms=wa*ra+wb*rb
  if sourceRms<=1E-12 then desired=self~dbGain(maxGainDb)
  else desired=targetRms/sourceRms
  maxGain=self~dbGain(maxGainDb); minGain=self~dbGain(minGainDb)
  if desired>maxGain then desired=maxGain
  if desired<minGain then desired=minGain

  /* Slow gain movement keeps whispers stable instead of pumping from box to box. */
  if previousGain\==.nil then do
    step=self~dbGain(maxGainStepDb)
    if desired>previousGain*step then desired=previousGain*step
    if desired<previousGain/step then desired=previousGain/step
  end

  /* An impulse may constrain the current peak but may not reset the speech gain trajectory. */
  if measurement~crestA>=impulseCrest | measurement~crestB>=impulseCrest then do
    if previousGain\==.nil then desired=previousGain+0
    reason=reason||'+IMPULSE_HOLD_GAIN'
  end

  /* Whole-window class evidence annotates the plan.  Spectral box masks, not this stage,
   * own source-selective attenuation so possible whisper is never erased by a coarse label. */
  family='UNLABELLED'
  if familyEvidence\==.nil then do
    family=familyEvidence~strongest
    if familyEvidence~alarm>.80 then reason=reason||'+ALARM_EVIDENCE'
    if familyEvidence~impulse>.80 then reason=reason||'+IMPACT_EVIDENCE'
    if familyEvidence~background>.90 then reason=reason||'+BACKGROUND_EVIDENCE'
    if familyEvidence~vocalisation>.65 then reason=reason||'+VOCALISATION_EVIDENCE'
  end

  /* Float rendering preserves headroom, but this guard makes the plan safe for a later
   * single final encode without allowing 20-32 dB whisper gain to clip on a bang. */
  predictedPeak=wa*measurement~peakA+wb*measurement~peakB
  if predictedPeak>1E-12 then do
    peakGain=targetPeak/predictedPeak
    if desired>peakGain then do; desired=peakGain; reason=reason||'+PEAK_GUARD'; end
  end
  if desired<=0 then desired=1E-12
  return .AudioV9ReconstructionPlanRow~new(startSample,endSample,measurement~refinedLagSamples,wa,wb,desired,family,reason)
::method dbGain private
  use strict arg db
  return self~exp((db/20)*2.302585092994045684017991454684)
::method exp private
  use strict arg x
  numeric digits 30
  term=1; sum=1
  do n=1 to 80
    term=term*x/n; sum=sum+term
    if abs(term)<1E-24 then leave
  end
  return sum

::class AudioV9ReconstructionPlan public
::method init
  expose rows
  rows=.array~new
::method append
  expose rows
  use strict arg row
  if \row~isA(.AudioV9ReconstructionPlanRow) then raise syntax 88.900 array('reconstruction plan row required')
  if rows~items>0 then do
    if row~startSample<>rows[rows~items]~endSample then raise syntax 88.900 array('reconstruction plan must be contiguous',row~startSample,rows[rows~items]~endSample)
  end
  rows~append(row); return self
::method rows; expose rows; return rows~copy
::method items; expose rows; return rows~items
::method write
  expose rows
  use strict arg path
  call stream path,'C','OPEN WRITE REPLACE'
  call lineout path,'start_sample'||'09'x||'end_sample'||'09'x||'lag_b_samples'||'09'x||'weight_a'||'09'x||'weight_b'||'09'x||'gain'||'09'x||'source_family'||'09'x||'reason'
  do r over rows; call lineout path,r~tsv; end
  call stream path,'C','CLOSE'
  return path

::class AudioV9SoftReconstructionPlanner public
::method init
  expose policy
  use strict arg policyValue=.nil
  if policyValue==.nil then policy=.AudioV9SoftReconstructionPolicy~new; else policy=policyValue
::method fromScan
  expose policy
  use strict arg scan,totalSamples,familyEvidenceByIndex=.nil
  if \scan~isA(.AudioV9SpatialScan) then raise syntax 88.900 array('soft reconstruction planner requires AudioV9SpatialScan')
  totalSamples=totalSamples+0
  if totalSamples<1 | scan~size<1 then raise syntax 88.900 array('invalid reconstruction scan geometry')
  rows=scan~rows; plan=.AudioV9ReconstructionPlan~new; previousGain=.nil
  do i=1 to rows~items
    start=rows[i]~startSample
    if i<rows~items then finish=rows[i+1]~startSample
    else finish=totalSamples
    if finish<=start then raise syntax 88.900 array('spatial scan starts must increase')
    family=.nil
    if familyEvidenceByIndex\==.nil then do
      if familyEvidenceByIndex~hasIndex(i) then family=familyEvidenceByIndex[i]
    end
    r=policy~planRow(start,finish,rows[i]~measurement,family,previousGain)
    plan~append(r); previousGain=r~gain
  end
  if plan~rows[1]~startSample<>0 then raise syntax 88.900 array('spatial scan must begin at sample zero')
  if plan~rows[plan~items]~endSample<>totalSamples then raise syntax 88.900 array('spatial scan does not cover complete render interval')
  return plan

::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'AudioV9AcousticCharacter.cls'
