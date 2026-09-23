/* AudioV9PropagationReconstruction.cls
 * dev16: reflection-aware whisper reconstruction evidence/planning.
 *
 * Audio establishes an acoustic path. Video/vehicle geometry may corroborate
 * an already observed path but never creates acoustic authority by itself.
 * Loud/impulsive material is a separate-stem probe and may not reset the
 * low-level whisper gain trajectory.
 */
::options numeric inherit

::class AudioV9PropagationObservation public
::method init
  expose id startMs endMs sourceId feed pathKind delaySamples apparentGainDb audioScore videoScore reflectorId loudProbe provenance
  use strict arg idValue,startValue,endValue,sourceValue,feedValue,pathValue,delayValue,gainDbValue,audioScoreValue,videoScoreValue=0,reflectorValue='',loudProbeValue=0,provenanceValue='AUDIO'
  id=idValue~string; startMs=startValue+0; endMs=endValue+0; sourceId=sourceValue~string
  feed=feedValue~string~upper; pathKind=pathValue~string~upper; delaySamples=delayValue+0
  apparentGainDb=gainDbValue+0; audioScore=audioScoreValue+0; videoScore=videoScoreValue+0
  reflectorId=reflectorValue~string; loudProbe=(loudProbeValue<>0); provenance=provenanceValue~string
  if id='' | sourceId='' then raise syntax 88.900 array('propagation observation requires id and source id')
  if endMs<=startMs then raise syntax 88.900 array('invalid propagation observation interval')
  if feed\='FC' & feed\='FD' & feed\='FC_FD' then raise syntax 88.900 array('invalid propagation feed',feed)
  if pathKind\='DIRECT' & pathKind\='STATIC_REFLECTION' & pathKind\='TRANSIENT_REFLECTION' & pathKind\='UNKNOWN_REFLECTION' then raise syntax 88.900 array('invalid propagation path kind',pathKind)
  if audioScore<0 | audioScore>1 | videoScore<0 | videoScore>1 then raise syntax 88.900 array('propagation scores must be 0..1')
::method id; expose id; return id
::method startMs; expose startMs; return startMs
::method endMs; expose endMs; return endMs
::method sourceId; expose sourceId; return sourceId
::method feed; expose feed; return feed
::method pathKind; expose pathKind; return pathKind
::method delaySamples; expose delaySamples; return delaySamples
::method apparentGainDb; expose apparentGainDb; return apparentGainDb
::method audioScore; expose audioScore; return audioScore
::method videoScore; expose videoScore; return videoScore
::method reflectorId; expose reflectorId; return reflectorId
::method loudProbe; expose loudProbe; return loudProbe
::method provenance; expose provenance; return provenance
::method overlaps
  expose startMs endMs
  use strict arg left,right
  return endMs>left & startMs<right
::method audioEligible
  expose audioScore
  use strict arg gate=.45
  return audioScore>=gate
::method videoCorroborated
  expose audioScore videoScore
  use strict arg audioGate=.45,videoGate=.50
  return audioScore>=audioGate & videoScore>=videoGate
::method authority
  if self~videoCorroborated then return 'AUDIO_PLUS_VIDEO'
  if self~audioEligible then return 'AUDIO_ONLY'
  if self~videoScore>=.50 then return 'VISUAL_ONLY_CANDIDATE'
  return 'INSUFFICIENT'
::method withVideoCorroboration
  expose id startMs endMs sourceId feed pathKind delaySamples apparentGainDb audioScore loudProbe provenance
  use strict arg score,reflector=''
  v=score+0; if v<0 then v=0; if v>1 then v=1
  return .AudioV9PropagationObservation~new(id,startMs,endMs,sourceId,feed,pathKind,delaySamples,apparentGainDb,audioScore,v,reflector,loudProbe,provenance)
::method tsv
  expose id startMs endMs sourceId feed pathKind delaySamples apparentGainDb audioScore videoScore reflectorId loudProbe provenance
  return id||'09'x||startMs||'09'x||endMs||'09'x||sourceId||'09'x||feed||'09'x||pathKind||'09'x||delaySamples||'09'x||apparentGainDb||'09'x||audioScore||'09'x||videoScore||'09'x||reflectorId||'09'x||(loudProbe+0)||'09'x||provenance||'09'x||self~authority

::class AudioV9VideoReflectorObservation public
::method init
  expose reflectorId startMs endMs geometryScore provenance
  use strict arg idValue,startValue,endValue,scoreValue,provenanceValue='VIDEO'
  reflectorId=idValue~string; startMs=startValue+0; endMs=endValue+0; geometryScore=scoreValue+0; provenance=provenanceValue~string
  if reflectorId='' | endMs<=startMs then raise syntax 88.900 array('invalid video reflector observation')
  if geometryScore<0 | geometryScore>1 then raise syntax 88.900 array('video reflector score must be 0..1')
::method reflectorId; expose reflectorId; return reflectorId
::method startMs; expose startMs; return startMs
::method endMs; expose endMs; return endMs
::method geometryScore; expose geometryScore; return geometryScore
::method provenance; expose provenance; return provenance
::method overlaps
  expose startMs endMs
  use strict arg left,right
  return endMs>left & startMs<right

::class AudioV9PropagationCorrelator public
::method corroborate
  use strict arg audioObservation,videoObservations
  if \audioObservation~isA(.AudioV9PropagationObservation) then raise syntax 88.900 array('correlator requires audio propagation observation')
  if \videoObservations~isA(.Array) then raise syntax 88.900 array('correlator video observations must be Array')
  /* Visual geometry cannot create acoustic authority. It only annotates an
   * acoustic observation that already exists. */
  best=0; reflector=''
  do v over videoObservations
    if \v~isA(.AudioV9VideoReflectorObservation) then raise syntax 88.900 array('invalid video reflector evidence')
    if \v~overlaps(audioObservation~startMs,audioObservation~endMs) then iterate
    if v~geometryScore>best then do; best=v~geometryScore; reflector=v~reflectorId; end
  end
  if best=0 then return audioObservation
  return audioObservation~withVideoCorroboration(best,reflector)

::class AudioV9PropagationEvidenceSet public
::method init
  expose rows
  rows=.array~new
::method append
  expose rows
  use strict arg observation
  if \observation~isA(.AudioV9PropagationObservation) then raise syntax 88.900 array('propagation evidence requires AudioV9PropagationObservation')
  rows~append(observation); return self
::method rows; expose rows; return rows~copy
::method items; expose rows; return rows~items
::method overlapping
  expose rows
  use strict arg startMs,endMs,sourceId=''
  out=.array~new
  do r over rows
    if sourceId<>'' then if r~sourceId\==sourceId then iterate
    if r~overlaps(startMs,endMs) then out~append(r)
  end
  return out

::class AudioV9WhisperGainTracker public
::method init
  expose targetRms maxGainDb maxStepDb referenceRms
  use strict arg targetValue=.06,maxGainDbValue=36,maxStepDbValue=3
  targetRms=targetValue+0; maxGainDb=maxGainDbValue+0; maxStepDb=maxStepDbValue+0; referenceRms=.nil
  if targetRms<=0 | maxGainDb<0 | maxStepDb<=0 then raise syntax 88.900 array('invalid whisper gain tracker policy')
::method referenceRms; expose referenceRms; return referenceRms
::method observe
  expose referenceRms
  use strict arg rms,isLoud=.false,isTransient=.false
  x=rms+0
  if x<=1E-12 then return self
  /* A bang or a transient moving-reflector boost is evidence about the path,
   * not a new speech-loudness reference. */
  if isLoud | isTransient then return self
  if referenceRms==.nil then referenceRms=x
  else do
    low=referenceRms/2; high=referenceRms*2; bounded=x
    if bounded<low then bounded=low
    if bounded>high then bounded=high
    referenceRms=.80*referenceRms+.20*bounded
  end
  return self
::method gain
  expose targetRms maxGainDb maxStepDb referenceRms
  use strict arg previousGain=.nil,fallbackRms=.nil
  ref=referenceRms
  if ref==.nil then do
    if fallbackRms==.nil then ref=targetRms
    else do; ref=fallbackRms+0; if ref<=1E-12 then ref=1E-12; end
  end
  desired=targetRms/ref; maxGain=self~dbGain(maxGainDb)
  if desired>maxGain then desired=maxGain
  if desired<1 then desired=1
  if previousGain\==.nil then do
    step=self~dbGain(maxStepDb)
    if desired>previousGain*step then desired=previousGain*step
    if desired<previousGain/step then desired=previousGain/step
  end
  return desired
::method dbGain private
  use strict arg db
  return self~exp((db/20)*2.302585092994045684017991454684)
::method exp private
  use strict arg x
  term=1; sum=1
  do n=1 to 80
    term=term*x/n; sum=sum+term
    if abs(term)<1E-24 then leave
  end
  return sum

::class AudioV9WhisperContribution public
::method init
  expose feed delaySamples weight pathKind observationId confidence
  use strict arg feedValue,delayValue,weightValue,pathValue='DIRECT',observationValue='',confidenceValue=1
  feed=feedValue~string~upper; delaySamples=delayValue+0; weight=weightValue+0; pathKind=pathValue~string~upper; observationId=observationValue~string; confidence=confidenceValue+0
  if feed\='FC' & feed\='FD' then raise syntax 88.900 array('whisper contribution feed must be FC or FD')
  if weight<0 | confidence<0 | confidence>1 then raise syntax 88.900 array('invalid whisper contribution')
::method feed; expose feed; return feed
::method delaySamples; expose delaySamples; return delaySamples
::method weight; expose weight; return weight
::method pathKind; expose pathKind; return pathKind
::method observationId; expose observationId; return observationId
::method confidence; expose confidence; return confidence
::method scaled
  expose feed delaySamples pathKind observationId confidence
  use strict arg factor
  return .AudioV9WhisperContribution~new(feed,delaySamples,self~weight*(factor+0),pathKind,observationId,confidence)
::method text
  expose feed delaySamples weight pathKind observationId confidence
  return feed||'@'||delaySamples||':'||weight||':'||pathKind||':'||observationId||':'||confidence

::class AudioV9WhisperFusionPlanRow public
::method init
  expose startSample endSample gain referenceRms loudIsolated transientReflection contributions reason
  use strict arg startValue,endValue,gainValue,referenceValue,loudValue,transientValue,contributionValue,reasonValue
  startSample=startValue+0; endSample=endValue+0; gain=gainValue+0; referenceRms=referenceValue
  loudIsolated=(loudValue<>0); transientReflection=(transientValue<>0); contributions=contributionValue; reason=reasonValue~string
  if startSample<0 | endSample<=startSample | gain<=0 then raise syntax 88.900 array('invalid whisper fusion plan row')
  if \contributions~isA(.Array) | contributions~items<1 then raise syntax 88.900 array('whisper fusion row requires contributions')
::method startSample; expose startSample; return startSample
::method endSample; expose endSample; return endSample
::method gain; expose gain; return gain
::method referenceRms; expose referenceRms; return referenceRms
::method loudIsolated; expose loudIsolated; return loudIsolated
::method transientReflection; expose transientReflection; return transientReflection
::method contributions; expose contributions; return contributions~copy
::method reason; expose reason; return reason
::method weightSum
  expose contributions
  s=0; do c over contributions; s=s+c~weight; end; return s
::method tsv
  expose startSample endSample gain referenceRms loudIsolated transientReflection contributions reason
  ref=''; if referenceRms\==.nil then ref=referenceRms
  text=''; do i=1 to contributions~items; if i>1 then text=text||';'; text=text||contributions[i]~text; end
  return startSample||'09'x||endSample||'09'x||gain||'09'x||ref||'09'x||(loudIsolated+0)||'09'x||(transientReflection+0)||'09'x||text||'09'x||reason

::class AudioV9ReflectionAwareWhisperPolicy public
::method init
  expose audioGate strongCoherence maxReflectionFraction
  use strict arg audioGateValue=.45,strongCoherenceValue=.35,maxReflectionFractionValue=.35
  audioGate=audioGateValue+0; strongCoherence=strongCoherenceValue+0; maxReflectionFraction=maxReflectionFractionValue+0
  if audioGate<0 | audioGate>1 | strongCoherence<0 | strongCoherence>1 | maxReflectionFraction<0 | maxReflectionFraction>=1 then raise syntax 88.900 array('invalid reflection-aware policy')
::method planWindow
  expose audioGate strongCoherence maxReflectionFraction
  use strict arg startSample,endSample,measurement,propagationRows,gainTracker,previousGain=.nil
  if \measurement~isA(.AudioV9SpatialMeasurement) then raise syntax 88.900 array('reflection-aware policy requires spatial measurement')
  if \propagationRows~isA(.Array) then raise syntax 88.900 array('propagation rows must be Array')
  if \gainTracker~isA(.AudioV9WhisperGainTracker) then raise syntax 88.900 array('gain tracker required')

  loud=measurement~crestA>=7 | measurement~crestB>=7
  transient=.false; eligible=.array~new
  do p over propagationRows
    if p~loudProbe then loud=.true
    if p~pathKind='TRANSIENT_REFLECTION' & p~audioEligible(audioGate) then transient=.true
    if p~pathKind\='DIRECT' & p~audioEligible(audioGate) then eligible~append(p)
  end

  /* Gain reference deliberately follows low-level non-transient evidence. */
  baseRms=(measurement~rmsA+measurement~rmsB)/2
  gainTracker~observe(baseRms,loud,transient)
  gain=gainTracker~gain(previousGain,baseRms)

  direct=.array~new
  if measurement~refinedCoherence>=strongCoherence & measurement~refinedScore>0 then do
    direct~append(.AudioV9WhisperContribution~new('FC',0,.5,'DIRECT','',measurement~refinedCoherence))
    direct~append(.AudioV9WhisperContribution~new('FD',measurement~refinedLagSamples,.5,'DIRECT','',measurement~refinedCoherence))
    reason='COHERENT_DIRECT_PAIR'
  end
  else do
    /* Do not interpret a transiently louder camera as a louder source. Keep
     * both feeds represented and let acoustic compatibility drive reflections. */
    direct~append(.AudioV9WhisperContribution~new('FC',0,.6,'DIRECT','',measurement~refinedCoherence))
    direct~append(.AudioV9WhisperContribution~new('FD',measurement~refinedLagSamples,.4,'DIRECT','',measurement~refinedCoherence))
    reason='WEAK_DIRECT_PAIR'
  end

  reflections=self~rankReflections(eligible)
  raw=.array~new; reflectedWeight=0
  do i=1 to reflections~items
    if i>2 then leave
    p=reflections[i]
    /* Video contributes at most 20% of ranking strength and only after the
     * audio gate has admitted the path. */
    conf=p~audioScore*(.8+.2*p~videoScore)
    w=.08+.12*conf
    if reflectedWeight+w>maxReflectionFraction then w=maxReflectionFraction-reflectedWeight
    if w<=0 then leave
    raw~append(.AudioV9WhisperContribution~new(self~feedFor(p),p~delaySamples,w,p~pathKind,p~id,conf))
    reflectedWeight=reflectedWeight+w
  end
  directScale=1-reflectedWeight
  out=.array~new; do c over direct; out~append(c~scaled(directScale)); end
  do c over raw; out~append(c); end

  if transient then reason=reason||'+TRANSIENT_REFLECTION_HOLD_REFERENCE'
  if raw~items>0 then reason=reason||'+ECHO_CORROBORATION'
  if loud then reason=reason||'+LOUD_PROBE_SEPARATE_STEM'
  return .AudioV9WhisperFusionPlanRow~new(startSample,endSample,gain,gainTracker~referenceRms,loud,transient,out,reason)
::method feedFor private
  use strict arg p
  if p~feed='FD' then return 'FD'
  if p~feed='FC' then return 'FC'
  /* A paired-feed reflection is represented against the delayed FD branch so
   * the direct FC reference remains zero-delay authority. */
  return 'FD'
::method rankReflections private
  use strict arg rows
  out=.array~new
  do p over rows
    placed=.false; tmp=.array~new
    ps=p~audioScore*(.8+.2*p~videoScore)
    do i=1 to out~items
      if \placed then do
        os=out[i]~audioScore*(.8+.2*out[i]~videoScore)
        if ps>os | (ps=os & p~id<out[i]~id) then do; tmp~append(p); placed=.true; end
      end
      tmp~append(out[i])
    end
    if \placed then tmp~append(p)
    out=tmp
  end
  return out

::class AudioV9WhisperFusionPlan public
::method init
  expose rows
  rows=.array~new
::method append
  expose rows
  use strict arg row
  if \row~isA(.AudioV9WhisperFusionPlanRow) then raise syntax 88.900 array('whisper fusion plan row required')
  if rows~items>0 then if row~startSample<>rows[rows~items]~endSample then raise syntax 88.900 array('whisper fusion plan must be contiguous')
  rows~append(row); return self
::method rows; expose rows; return rows~copy
::method items; expose rows; return rows~items
::method write
  expose rows
  use strict arg path
  call stream path,'C','OPEN WRITE REPLACE'
  call lineout path,'start_sample'||'09'x||'end_sample'||'09'x||'whisper_gain'||'09'x||'reference_rms'||'09'x||'loud_isolated'||'09'x||'transient_reflection'||'09'x||'contributions'||'09'x||'reason'
  do r over rows; call lineout path,r~tsv; end
  call stream path,'C','CLOSE'; return path

::class AudioV9ReflectionAwareWhisperPlanner public
::method init
  expose policy tracker
  use strict arg policyValue=.nil,trackerValue=.nil
  if policyValue==.nil then policy=.AudioV9ReflectionAwareWhisperPolicy~new; else policy=policyValue
  if trackerValue==.nil then tracker=.AudioV9WhisperGainTracker~new; else tracker=trackerValue
::method fromScan
  expose policy tracker
  use strict arg scan,totalSamples,sampleRate,absoluteStartMs,evidenceSet,sourceId=''
  if \scan~isA(.AudioV9SpatialScan) then raise syntax 88.900 array('reflection-aware planner requires spatial scan')
  if \evidenceSet~isA(.AudioV9PropagationEvidenceSet) then raise syntax 88.900 array('propagation evidence set required')
  totalSamples=totalSamples+0; sampleRate=sampleRate+0; absoluteStartMs=absoluteStartMs+0
  if totalSamples<1 | sampleRate<1 | scan~size<1 then raise syntax 88.900 array('invalid reflection-aware scan geometry')
  rows=scan~rows; plan=.AudioV9WhisperFusionPlan~new; previous=.nil
  do i=1 to rows~items
    start=rows[i]~startSample
    if i<rows~items then finish=rows[i+1]~startSample; else finish=totalSamples
    if finish<=start then raise syntax 88.900 array('reflection-aware scan starts must increase')
    left=absoluteStartMs+(start*1000/sampleRate); right=absoluteStartMs+(finish*1000/sampleRate)
    props=evidenceSet~overlapping(left,right,sourceId)
    row=policy~planWindow(start,finish,rows[i]~measurement,props,tracker,previous)
    plan~append(row); previous=row~gain
  end
  if plan~rows[1]~startSample<>0 | plan~rows[plan~items]~endSample<>totalSamples then raise syntax 88.900 array('reflection-aware plan does not cover render interval')
  return plan

::requires 'AudioV9SpatialNativeProvider.cls'
