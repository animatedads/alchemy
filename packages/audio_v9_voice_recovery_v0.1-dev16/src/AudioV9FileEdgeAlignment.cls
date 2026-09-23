/* AudioV9FileEdgeAlignment.cls
 * dev4: sample-exact, evidence-bearing source-file edge alignment.
 *
 * File/container clock correction is deliberately separate from physical TDOA.
 * A source filename gives a coarse nominal wall clock.  Every file edge may add
 * a measured sample step to the piecewise camera clock.  Ambiguous edges carry
 * the previous correction as a prediction; they are never silently forced.
 */
::options numeric inherit

::class AudioV9FileEdgeObservation public
::method init
  expose id feed leftFile rightFile edgeSerial estimator stepSamples score sourceFamily tdoaBefore tdoaAfter
  use strict arg idValue,feedValue,leftValue,rightValue,edgeValue,estimatorValue,stepValue,scoreValue=1,sourceFamilyValue='UNLABELLED',tdoaBeforeValue=0,tdoaAfterValue=0
  id=idValue~string; feed=feedValue~string~lower; leftFile=leftValue~string; rightFile=rightValue~string
  edgeSerial=edgeValue+0; estimator=estimatorValue~string~upper; stepSamples=stepValue+0; score=scoreValue+0
  sourceFamily=sourceFamilyValue~string; tdoaBefore=tdoaBeforeValue+0; tdoaAfter=tdoaAfterValue+0
  if feed\='fc' then if feed\='fd' then raise syntax 88.900 array('file-edge observation feed must be fc/fd',feed)
  if stepSamples\=trunc(stepSamples) then raise syntax 88.900 array('file-edge correction must be whole samples',stepSamples)
  if score<0 then raise syntax 88.900 array('file-edge observation score must be non-negative',score)
::method fromDecodedLength class
  /* Deterministic container-geometry observation.  If the left file decodes to
   * fewer/more canonical samples than the nominal filename spacing, that
   * difference predicts the piecewise start step of the right file.  It is
   * evidence of an edge discontinuity, not proof of its physical cause. */
  use strict arg idValue,feedValue,leftValue,rightValue,sampleRateValue,decodedSamplesValue,scoreValue=1.0
  sr=sampleRateValue+0; decoded=decodedSamplesValue+0
  if sr<1 | sr\=trunc(sr) then raise syntax 88.900 array('decoded-length sample rate must be integer',sr)
  if decoded<0 | decoded\=trunc(decoded) then raise syntax 88.900 array('decoded-length sample count must be whole',decoded)
  leftStart=.AudioV9VoiceClock~fromSourceName(leftValue)
  rightStart=.AudioV9VoiceClock~fromSourceName(rightValue)
  nominal=(rightStart-leftStart)*sr
  step=decoded-nominal
  return self~new(idValue,feedValue,leftValue,rightValue,rightStart,'DECODED_LENGTH',step,scoreValue,'CONTAINER_GEOMETRY',0,0)
::method fromLagChange class
  /* Convention: measuredLag = FD sample index - FC sample index.
   * A positive FC clock step increases measuredLag; a positive FD clock step
   * decreases measuredLag.  Physical-path TDOA change is removed first. */
  use strict arg idValue,feedValue,leftValue,rightValue,edgeValue,estimatorValue,lagBefore,lagAfter,tdoaBefore=0,tdoaAfter=0,scoreValue=1,sourceFamilyValue='UNLABELLED'
  residual=(lagAfter+0-lagBefore+0)-((tdoaAfter+0)-(tdoaBefore+0))
  f=feedValue~string~lower
  if f='fc' then step=residual
  else if f='fd' then step=-residual
  else raise syntax 88.900 array('file-edge observation feed must be fc/fd',f)
  step=trunc(step+0.5*sign(step))
  return self~new(idValue,f,leftValue,rightValue,edgeValue,estimatorValue,step,scoreValue,sourceFamilyValue,tdoaBefore,tdoaAfter)
::method id; expose id; return id
::method feed; expose feed; return feed
::method leftFile; expose leftFile; return leftFile
::method rightFile; expose rightFile; return rightFile
::method edgeSerial; expose edgeSerial; return edgeSerial
::method estimator; expose estimator; return estimator
::method boundaryStepSamples; expose stepSamples; return stepSamples
::method score; expose score; return score
::method sourceFamily; expose sourceFamily; return sourceFamily
::method tdoaBeforeSamples; expose tdoaBefore; return tdoaBefore
::method tdoaAfterSamples; expose tdoaAfter; return tdoaAfter
::method fitObservation
  expose id stepSamples
  d=.directory~new; d['id']=id; d['step_samples']=stepSamples; return d
::method tsv
  return self~id||'09'x||self~feed||'09'x||self~leftFile||'09'x||self~rightFile||'09'x||self~edgeSerial||'09'x||self~estimator||'09'x||self~boundaryStepSamples||'09'x||self~score||'09'x||self~sourceFamily||'09'x||self~tdoaBeforeSamples||'09'x||self~tdoaAfterSamples
::method canonicalText
  return 'AUDIO_V9_FILE_EDGE_OBSERVATION/1|id='||self~id||'|feed='||self~feed||'|edge='||self~leftFile||'->'||self~rightFile||'|stepSamples='||self~boundaryStepSamples||'|estimator='||self~estimator||'|family='||self~sourceFamily

::class AudioV9BoundaryStepFitScorer public
::method assess
  use strict arg observations
  n=observations~items
  if n<1 then raise syntax 88.900 array('boundary step fit requires observations')
  sum=0
  do o over observations; sum=sum+(o['step_samples']+0); end
  mean=sum/n; ss=0; maxAbs=0
  do o over observations
    e=(o['step_samples']+0)-mean; ss=ss+e*e; if abs(e)>maxAbs then maxAbs=abs(e)
  end
  rms=self~sqrt(ss/n)
  ev=.directory~new; ev['mean_step_samples']=mean; ev['rms_samples']=rms; ev['max_abs_samples']=maxAbs
  return .MLFitAssessment~new(rms,n,'AUDIO_FILE_EDGE_STEP',ev)
::method sqrt private
  use strict arg x
  numeric digits 30
  if x<0 then raise syntax 88.900 array('sqrt requires non-negative value',x)
  if x=0 then return 0
  if x<1 then g=1; else g=x
  do i=1 to 48; g=(g+x/g)/2; end
  return g

::class AudioV9FileEdgeSolution public
::method init
  expose feed leftFile rightFile edgeSerial step correction confidence evidenceCount ambiguous rms excluded tdoaBefore tdoaAfter status
  use strict arg feedValue,leftValue,rightValue,edgeValue,stepValue,correctionValue,confidenceValue,evidenceCountValue,ambiguousValue,rmsValue,excludedValue,tdoaBeforeValue,tdoaAfterValue,statusValue
  feed=feedValue~string~lower; leftFile=leftValue~string; rightFile=rightValue~string; edgeSerial=edgeValue+0
  step=stepValue+0; correction=correctionValue+0; confidence=confidenceValue+0; evidenceCount=evidenceCountValue+0
  ambiguous=ambiguousValue; rms=rmsValue+0; excluded=excludedValue+0; tdoaBefore=tdoaBeforeValue+0; tdoaAfter=tdoaAfterValue+0; status=statusValue~string~upper
::method feed; expose feed; return feed
::method leftFile; expose leftFile; return leftFile
::method rightFile; expose rightFile; return rightFile
::method edgeSerial; expose edgeSerial; return edgeSerial
::method boundaryStepSamples; expose step; return step
::method cumulativeCorrectionSamples; expose correction; return correction
::method confidence; expose confidence; return confidence
::method evidenceCount; expose evidenceCount; return evidenceCount
::method ambiguous; expose ambiguous; return ambiguous
::method rmsSamples; expose rms; return rms
::method excludedCount; expose excluded; return excluded
::method tdoaBeforeSamples; expose tdoaBefore; return tdoaBefore
::method tdoaAfterSamples; expose tdoaAfter; return tdoaAfter
::method status; expose status; return status
::method resolved
  expose status ambiguous
  if status\='MEASURED' then return .false
  return \ambiguous
::method tsv
  return self~feed||'09'x||self~leftFile||'09'x||self~rightFile||'09'x||self~edgeSerial||'09'x||self~boundaryStepSamples||'09'x||self~cumulativeCorrectionSamples||'09'x||self~confidence||'09'x||self~evidenceCount||'09'x||self~status||'09'x||self~rmsSamples||'09'x||self~excludedCount||'09'x||self~tdoaBeforeSamples||'09'x||self~tdoaAfterSamples

::class AudioV9FileEdgeAlignmentSolver public
::method init
  expose rmsTolerance maxRemovals maxEvaluations ambiguitySamples
  use strict arg rmsToleranceValue=4,maxRemovalsValue=3,maxEvaluationsValue=10000,ambiguitySamplesValue=8
  rmsTolerance=rmsToleranceValue+0; maxRemovals=maxRemovalsValue+0; maxEvaluations=maxEvaluationsValue+0; ambiguitySamples=ambiguitySamplesValue+0
  if rmsTolerance<0 | ambiguitySamples<0 then raise syntax 88.900 array('edge solver tolerances must be non-negative')
::method solve
  expose rmsTolerance maxRemovals maxEvaluations ambiguitySamples
  use strict arg observations,previousCorrection=0
  if \observations~isA(.Array) then raise syntax 88.900 array('file-edge solver requires Array')
  if observations~items<2 then raise syntax 88.900 array('file-edge solver requires at least two observations')
  first=observations[1]; feed=first~feed; left=first~leftFile; right=first~rightFile; edge=first~edgeSerial
  fit=.array~new; totalScore=0
  do o over observations
    if \o~isA(.AudioV9FileEdgeObservation) then raise syntax 88.900 array('file-edge observation required')
    if o~feed\=feed | o~leftFile\=left | o~rightFile\=right | o~edgeSerial\=edge then raise syntax 88.900 array('file-edge observations refer to different edges')
    fit~append(o~fitObservation); totalScore=totalScore+o~score
  end
  scorer=.AudioV9BoundaryStepFitScorer~new
  criterion=.MLFitCriterion~new(rmsTolerance,'LOWER_IS_BETTER')
  search=.MLWobbleSetSearch~new(scorer,criterion,maxRemovals,maxEvaluations)
  analysis=search~analyze(fit)
  if \analysis~fitRestored then return .AudioV9FileEdgeSolution~new(feed,left,right,edge,0,previousCorrection,0,observations~items,.true,analysis~baseline~value,0,0,0,'UNRESOLVED')
  sets=analysis~restoringSets~toArray
  best=.nil; second=.nil
  do ws over sets
    c=self~candidate(observations,ws,totalScore,scorer)
    if best==.nil then do; best=c; iterate; end
    if self~better(c,best) then do; second=best; best=c; iterate; end
    if second==.nil then second=c
    else if self~better(c,second) then second=c
  end
  ambiguous=.false
  if second\==.nil then do
    if abs(best['step']-second['step'])>ambiguitySamples & second['support']>=best['support']*.85 then ambiguous=.true
  end
  status='MEASURED'; if ambiguous then status='AMBIGUOUS'
  correction=previousCorrection+best['step']
  return .AudioV9FileEdgeSolution~new(feed,left,right,edge,best['step'],correction,best['confidence'],best['count'],ambiguous,best['rms'],best['excluded'],best['tdoa_before'],best['tdoa_after'],status)
::method candidate private
  use strict arg observations,ws,totalScore,scorer
  excluded=.directory~new
  do ix over ws~indexes~toArray; excluded[ix]=1; end
  kept=.array~new; fit=.array~new; support=0; weighted=0; before=0; after=0
  do i=1 to observations~items
    if excluded~hasIndex(i) then iterate
    o=observations[i]; kept~append(o); fit~append(o~fitObservation); support=support+o~score; weighted=weighted+o~score*o~boundaryStepSamples; before=before+o~tdoaBeforeSamples; after=after+o~tdoaAfterSamples
  end
  if kept~items=0 then raise syntax 88.900 array('file-edge restoring set removed every observation')
  if support>0 then mean=weighted/support
  else do; mean=0; do o over kept; mean=mean+o~boundaryStepSamples; end; mean=mean/kept~items; end
  step=trunc(mean+0.5*sign(mean))
  a=scorer~assess(fit)
  c=.directory~new; c['step']=step; c['support']=support; c['count']=kept~items; c['rms']=a~value; c['excluded']=observations~items-kept~items
  c['confidence']=0; if totalScore>0 then c['confidence']=support/totalScore
  c['tdoa_before']=before/kept~items; c['tdoa_after']=after/kept~items
  return c
::method better private
  use strict arg a,b
  if a['support']>b['support'] then return .true
  if a['support']<b['support'] then return .false
  if a['rms']<b['rms'] then return .true
  if a['rms']>b['rms'] then return .false
  if abs(a['step'])<abs(b['step']) then return .true
  if abs(a['step'])>abs(b['step']) then return .false
  return a['step']<b['step']

::class AudioV9SourceSampleSlice public
::method init
  expose feed name nominalStart effectiveStart sliceStart sliceEnd offsetSamples sampleCount correction status sampleRate
  use strict arg feedValue,nameValue,nominalValue,effectiveValue,sliceStartValue,sliceEndValue,offsetValue,countValue,correctionValue,statusValue,sampleRateValue
  feed=feedValue~string~lower; name=nameValue~string; nominalStart=nominalValue+0; effectiveStart=effectiveValue+0
  sliceStart=sliceStartValue+0; sliceEnd=sliceEndValue+0; offsetSamples=offsetValue+0; sampleCount=countValue+0
  correction=correctionValue+0; status=statusValue~string; sampleRate=sampleRateValue+0
  if sampleCount<=0 | sliceEnd<=sliceStart | offsetSamples<0 then raise syntax 88.900 array('invalid source sample slice',feed,name)
::method feed; expose feed; return feed
::method name; expose name; return name
::method nominalSourceStart; expose nominalStart; return nominalStart
::method effectiveSourceStartSample; expose effectiveStart; return effectiveStart
::method sliceStartSample; expose sliceStart; return sliceStart
::method sliceEndSample; expose sliceEnd; return sliceEnd
::method offsetSamples; expose offsetSamples; return offsetSamples
::method expectedSamples; expose sampleCount; return sampleCount
::method correctionSamples; expose correction; return correction
::method edgeStatus; expose status; return status
::method sampleRate; expose sampleRate; return sampleRate
::method offsetSeconds; expose offsetSamples sampleRate; return offsetSamples/sampleRate
::method durationSeconds; expose sampleCount sampleRate; return sampleCount/sampleRate
::method sliceStartSeconds; expose sliceStart sampleRate; return sliceStart/sampleRate
::method sliceEndSeconds; expose sliceEnd sampleRate; return sliceEnd/sampleRate

::class AudioV9FileEdgeMap public
::method init
  expose byRight
  use strict arg solutions=.nil
  byRight=.directory~new
  if solutions\==.nil then do
    do s over solutions; self~put(s); end
  end
::method put
  expose byRight
  use strict arg solution
  if \solution~isA(.AudioV9FileEdgeSolution) then raise syntax 88.900 array('file-edge solution required')
  key=solution~feed||'|'||solution~rightFile
  if byRight~hasIndex(key) then raise syntax 88.900 array('duplicate file-edge solution',key)
  byRight[key]=solution; return self
::method forRight
  expose byRight
  use strict arg feed,rightFile
  key=feed~string~lower||'|'||rightFile~string
  if \byRight~hasIndex(key) then return .nil
  return byRight[key]
::method fromFile class
  use strict arg path
  m=self~new
  if path='' then return m
  call stream path,'C','OPEN READ'
  header=linein(path)
  expected='feed'||'09'x||'left_file'||'09'x||'right_file'||'09'x||'edge_serial'||'09'x||'boundary_step_samples'||'09'x||'cumulative_correction_samples'||'09'x||'confidence'||'09'x||'evidence_count'||'09'x||'status'||'09'x||'rms_samples'||'09'x||'excluded_count'||'09'x||'tdoa_before_samples'||'09'x||'tdoa_after_samples'
  if header\==expected then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('unexpected file-edge map schema',path); end
  do while lines(path)>0
    line=linein(path); if line='' then iterate
    f=line~makeArray('09'x); if f~items<>13 then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('bad file-edge map row width',f~items); end
    amb=.false; if f[9]~upper='AMBIGUOUS' then amb=.true; if f[9]~upper='UNRESOLVED' then amb=.true
    s=.AudioV9FileEdgeSolution~new(f[1],f[2],f[3],f[4],f[5],f[6],f[7],f[8],amb,f[10],f[11],f[12],f[13],f[9])
    m~put(s)
  end
  call stream path,'C','CLOSE'
  return m

::class AudioV9PiecewiseSourceClock public
::method init
  expose feed names sampleRate corrections statuses effectiveStarts edgeMap
  use strict arg feedValue,nameValues,sampleRateValue=8000,edgeMapValue=.nil
  feed=feedValue~string~lower; names=nameValues~copy; sampleRate=sampleRateValue+0
  if feed\='fc' then if feed\='fd' then raise syntax 88.900 array('piecewise clock feed must be fc/fd')
  if \names~isA(.Array) then raise syntax 88.900 array('piecewise clock needs Array source names')
  if names~items<2 then raise syntax 88.900 array('piecewise clock needs source names')
  if sampleRate<1 | sampleRate\=trunc(sampleRate) then raise syntax 88.900 array('piecewise clock sample rate must be integer')
  if edgeMapValue==.nil then edgeMap=.AudioV9FileEdgeMap~new; else edgeMap=edgeMapValue
  corrections=.array~new; statuses=.array~new; effectiveStarts=.array~new
  previous=0
  do i=1 to names~items
    nominal=.AudioV9VoiceClock~fromSourceName(names[i])*sampleRate
    if i=1 then do; correction=0; status='ANCHOR'; end
    else do
      sol=edgeMap~forRight(feed,names[i])
      if sol==.nil then do; correction=previous; status='PREDICTED'; end
      else if sol~resolved then do; correction=previous+sol~boundaryStepSamples; status='MEASURED'; end
      else do; correction=previous; status='PREDICTED'; end
    end
    effective=nominal+correction
    if i>1 then if effective<=effectiveStarts[i-1] then raise syntax 88.900 array('file-edge correction makes source clock non-monotonic',feed,names[i],correction)
    corrections~append(correction); statuses~append(status); effectiveStarts~append(effective); previous=correction
  end
::method correctionFor
  expose names corrections
  use strict arg name
  do i=1 to names~items; if names[i]=name then return corrections[i]; end
  raise syntax 88.900 array('source name absent from piecewise clock',name)
::method statusFor
  expose names statuses
  use strict arg name
  do i=1 to names~items; if names[i]=name then return statuses[i]; end
  raise syntax 88.900 array('source name absent from piecewise clock',name)
::method effectiveStartFor
  expose names effectiveStarts
  use strict arg name
  do i=1 to names~items; if names[i]=name then return effectiveStarts[i]; end
  raise syntax 88.900 array('source name absent from piecewise clock',name)
::method slices
  expose feed names sampleRate corrections statuses effectiveStarts
  use strict arg startSecond,endSecond
  globalStart=(startSecond+0)*sampleRate; globalEnd=(endSecond+0)*sampleRate
  if globalEnd<=globalStart then raise syntax 88.900 array('piecewise source range must be positive')
  out=.array~new
  do i=1 to names~items-1
    fileStart=effectiveStarts[i]; fileEnd=effectiveStarts[i+1]
    if fileEnd<=globalStart then iterate
    if fileStart>=globalEnd then leave
    a=globalStart; if fileStart>a then a=fileStart
    b=globalEnd; if fileEnd<b then b=fileEnd
    if b>a then do
      offset=a-fileStart; count=b-a
      out~append(.AudioV9SourceSampleSlice~new(feed,names[i],.AudioV9VoiceClock~fromSourceName(names[i]),fileStart,a,b,offset,count,corrections[i],statuses[i],sampleRate))
    end
  end
  if out~items=0 then raise syntax 88.900 array('piecewise source clock has no coverage',feed,startSecond,endSecond)
  if out[1]~sliceStartSample<>globalStart | out[out~items]~sliceEndSample<>globalEnd then raise syntax 88.900 array('piecewise source clock does not fully cover interval',feed,startSecond,endSecond)
  return out

::requires 'AudioV9VoiceCampaign.cls'
::requires 'MLWobblyFit.cls'
