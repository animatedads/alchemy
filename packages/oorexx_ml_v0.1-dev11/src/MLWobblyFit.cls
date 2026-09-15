/* MLWobblyFit.cls
 *
 * Contextual fit-restoration diagnostics: observations are not declared bad
 * merely because setting them aside restores a particular model.  Exclusion
 * is diagnostic evidence.  Reassignment remains an explicit later action.
 */

::class MLFitAssessment public
::attribute value get
::attribute sampleCount get
::attribute modelTag get
::attribute evidence get
::method init
  expose value sampleCount modelTag evidence
  use strict arg value,sampleCount,modelTag='FIT',evidence=.nil
  if evidence==.nil then evidence=.directory~new
  value=value+0; sampleCount=sampleCount+0; modelTag=modelTag; evidence=.MLFrozenMap~new(evidence)
::method canonicalText
  return 'FIT|value='||self~value||'|n='||self~sampleCount||'|model='||self~modelTag||'|'||self~evidence~canonicalText

::class MLFitCriterion public
::attribute threshold get
::attribute direction get
::method init
  expose threshold direction
  use strict arg threshold,direction='LOWER_IS_BETTER'
  direction=direction~upper
  if direction<>'LOWER_IS_BETTER' & direction<>'HIGHER_IS_BETTER' then raise syntax 88.900 array('unknown fit direction',direction)
  threshold=threshold+0
::method accepts
  use strict arg assessment
  if self~direction='LOWER_IS_BETTER' then return assessment~value<=self~threshold
  return assessment~value>=self~threshold
::method improvement
  use strict arg baseline,newAssessment
  if self~direction='LOWER_IS_BETTER' then return baseline~value-newAssessment~value
  return newAssessment~value-baseline~value

::class MLWobbleCandidate public
::attribute index get
::attribute id get
::attribute fitWithout get
::attribute restoration get
::attribute restoresFit get
::method init
  expose index id fitWithout restoration restoresFit
  use strict arg index,id,fitWithout,restoration,restoresFit
  index=index+0; id=id; restoration=restoration+0; restoresFit=restoresFit

::class MLWobbleSet public
::attribute indexes get
::attribute ids get
::attribute assessment get
::attribute distance get
::attribute fraction get
::attribute restoration get
::method init
  expose indexes ids assessment distance fraction restoration
  use strict arg indexes,ids,assessment,totalCount,restoration
  indexes=.MLFrozenVector~new(indexes); ids=.MLFrozenVector~new(ids); assessment=assessment
  distance=indexes~items; if totalCount=0 then fraction=0; else fraction=distance/totalCount
  restoration=restoration+0
::method containsIndex
  use strict arg wanted
  do i over self~indexes~toArray; if i=wanted then return .true; end
  return .false
::method canonicalText
  return 'WOBBLESET|distance='||self~distance||'|fraction='||self~fraction||'|fit='||self~assessment~value||'|ids='||self~ids~canonicalText

::class MLWobbleParticipation public
::attribute index get
::attribute id get
::attribute count get
::attribute setCount get
::attribute fraction get
::method init
  expose index id count setCount fraction
  use strict arg index,id,count,setCount
  index=index+0; id=id; count=count+0; setCount=setCount+0
  if setCount=0 then fraction=0; else fraction=count/setCount

::class MLWobbleNorm public
::attribute observations get
::attribute meanFraction get
::attribute p50 get
::attribute p95 get
::method init
  expose observations meanFraction p50 p95 values
  use strict arg source
  if \source~isA(.Array) then raise syntax 88.900 array('MLWobbleNorm requires Array of historical wobble fractions')
  if source~items=0 then raise syntax 88.900 array('MLWobbleNorm requires at least one value')
  values=.array~new; total=0
  do v over source; x=v+0; if x<0 then raise syntax 88.900 array('negative wobble fraction'); values~append(x); total=total+x; end
  values~sort
  observations=values~items; meanFraction=total/observations
  p50=self~quantile(0.50); p95=self~quantile(0.95)
::method quantile
  expose values
  use strict arg q
  if q<=0 then return values[1]
  if q>=1 then return values[values~items]
  pos=1+q*(values~items-1); lo=pos%1; hi=lo; if pos>lo then hi=lo+1
  if hi>values~items then hi=values~items
  if lo<1 then lo=1
  frac=pos-lo
  return values[lo]+frac*(values[hi]-values[lo])
::method percentileOf
  expose values
  use strict arg x
  count=0; do v over values; if v<=x then count=count+1; end
  return count/values~items
::method classify
  use strict arg fraction
  if fraction>self~p95 then return 'ABOVE_NORMATIVE_P95'
  if fraction>self~p50 then return 'ABOVE_NORMATIVE_MEDIAN'
  return 'WITHIN_NORMATIVE_RANGE'

::class MLWobbleReassignment public
::attribute id get
::attribute disposition get
::attribute target get
::attribute evidence get
::method init
  expose id disposition target evidence
  use strict arg id,disposition,target='',evidence=.nil
  if evidence==.nil then evidence=.directory~new
  id=id; disposition=disposition~upper; target=target; evidence=.MLFrozenMap~new(evidence)
::method canonicalText
  return 'REASSIGN|id='||self~id||'|disposition='||self~disposition||'|target='||self~target||'|'||self~evidence~canonicalText

::class MLWobbleAnalysis public
::attribute baseline get
::attribute criterion get
::attribute individualCandidates get
::attribute restoringSets get
::attribute distanceToFit get
::attribute normalizedDistance get
::attribute evaluations get
::attribute participation get
::attribute normative get
::method init
  expose baseline criterion individualCandidates restoringSets distanceToFit normalizedDistance evaluations participation normative
  use strict arg baseline,criterion,individualCandidates,restoringSets,totalCount,evaluations,normative=.nil
  baseline=baseline; criterion=criterion; individualCandidates=.MLFrozenVector~new(individualCandidates)
  restoringSets=.MLFrozenVector~new(restoringSets); evaluations=evaluations+0; normative=normative
  if restoringSets~items=0 then do; distanceToFit=-1; normalizedDistance=-1; end
  else do; distanceToFit=restoringSets[1]~distance; normalizedDistance=restoringSets[1]~fraction; end
  counts=.directory~new; ids=.directory~new
  do ws over restoringSets~toArray
    idxs=ws~indexes~toArray; names=ws~ids~toArray
    do j=1 to idxs~items
      key=idxs[j]; if \counts~hasIndex(key) then counts[key]=0
      counts[key]=counts[key]+1; ids[key]=names[j]
    end
  end
  parts=.array~new; keys=counts~allIndexes; keys~sort
  do key over keys; parts~append(.MLWobbleParticipation~new(key,ids[key],counts[key],restoringSets~items)); end
  participation=.MLFrozenVector~new(parts)
::method fitRestored; return self~restoringSets~items>0
::method normativeClass
  expose normative
  if normative==.nil | self~normalizedDistance<0 then return 'NO_NORM'
  return normative~classify(self~normalizedDistance)
::method percentile
  expose normative
  if normative==.nil | self~normalizedDistance<0 then return -1
  return normative~percentileOf(self~normalizedDistance)

::class MLWobbleSetSearch public
::method init
  expose scorer criterion maxRemovals maxEvaluations
  use strict arg scorer,criterion,maxRemovals=4,maxEvaluations=100000
  if maxRemovals<0 then raise syntax 88.900 array('negative maxRemovals')
  if maxEvaluations<1 then raise syntax 88.900 array('maxEvaluations must be positive')
  scorer=scorer; criterion=criterion; maxRemovals=maxRemovals+0; maxEvaluations=maxEvaluations+0
::method scorer; expose scorer; return scorer
::method criterion; expose criterion; return criterion
::method maxRemovals; expose maxRemovals; return maxRemovals
::method maxEvaluations; expose maxEvaluations; return maxEvaluations
::method analyze
  expose scorer criterion maxRemovals maxEvaluations
  use strict arg observations,normative=.nil
  if \observations~isA(.Array) then raise syntax 88.900 array('wobble analysis requires Array')
  n=observations~items; if n<2 then raise syntax 88.900 array('wobble analysis requires at least two observations')
  baseline=scorer~assess(observations); evals=1
  individuals=.array~new
  do i=1 to n
    subset=self~without(observations,.array~of(i)); a=scorer~assess(subset); evals=evals+1
    if evals>maxEvaluations then raise syntax 88.900 array('wobble evaluation budget exceeded',evals,maxEvaluations)
    individuals~append(.MLWobbleCandidate~new(i,self~obsId(observations[i],i),a,criterion~improvement(baseline,a),criterion~accepts(a)))
  end
  sets=.array~new
  if criterion~accepts(baseline) then sets~append(.MLWobbleSet~new(.array~new,.array~new,baseline,n,0))
  else do k=1 to maxRemovals while sets~items=0
    if k>n-1 then leave
    masks=self~combinations(n,k)
    do idxs over masks
      evals=evals+1; if evals>maxEvaluations then raise syntax 88.900 array('wobble evaluation budget exceeded',evals,maxEvaluations)
      subset=self~without(observations,idxs); a=scorer~assess(subset)
      if criterion~accepts(a) then do
        names=.array~new; do ix over idxs; names~append(self~obsId(observations[ix],ix)); end
        sets~append(.MLWobbleSet~new(idxs,names,a,n,criterion~improvement(baseline,a)))
      end
    end
  end
  return .MLWobbleAnalysis~new(baseline,criterion,individuals,sets,n,evals,normative)
::method obsId private
  use strict arg obs,index
  if obs~isA(.Directory) & obs~hasIndex('id') then return obs['id']
  return 'OBS-'||index
::method without private
  use strict arg observations,indexes
  skip=.directory~new; do i over indexes; skip[i]=1; end
  out=.array~new; do i=1 to observations~items; if \skip~hasIndex(i) then out~append(observations[i]); end
  return out
::method combinations private
  use strict arg n,k
  out=.array~new
  current=.array~new
  self~combineRec(1,n,k,current,out)
  return out
::method combineRec private
  use strict arg start,n,remaining,current,out
  if remaining=0 then do; copy=.array~new; do x over current; copy~append(x); end; out~append(copy); return; end
  last=n-remaining+1
  do i=start to last
    current~append(i); self~combineRec(i+1,n,remaining-1,current,out); current~remove(current~items)
  end

/* Reference scorer for the canonical radar/sonar/telemetry demo.  It fits
 * y = intercept + slope*x and publishes RMS residual as fit value. */

::class MLWobbleStudy subclass MLDriveableObject public
::method init
  use strict arg stableId='WOBBLE-STUDY'
  initial=.directory~new; initial['analysisCount']=0; initial['lastAnalysis']=.nil
  self~init:super(stableId,'WOBBLE_STUDY',initial)
::method record
  use strict arg analysis,tag='WOBBLE_ANALYSIS'
  changes=.directory~new; changes['analysisCount']=self~at('analysisCount')+1; changes['lastAnalysis']=analysis
  self~mutate(changes,tag); return analysis
::method analyze
  use strict arg search,observations,normative=.nil,tag='WOBBLE_ANALYSIS'
  analysis=search~analyze(observations,normative); return self~record(analysis,tag)
::method lastAnalysis
  return self~at('lastAnalysis')
::method analysisCount
  return self~at('analysisCount')

::class MLLinearTrackFitScorer public
::method assess
  use strict arg observations
  n=observations~items; if n<2 then raise syntax 88.900 array('linear track fit needs at least two observations')
  sx=0; sy=0; sxx=0; sxy=0
  do o over observations
    x=o['x']+0; y=o['y']+0; sx=sx+x; sy=sy+y; sxx=sxx+x*x; sxy=sxy+x*y
  end
  den=n*sxx-sx*sx
  if abs(den)<1e-15 then raise syntax 88.900 array('linear track fit singular x geometry')
  slope=(n*sxy-sx*sy)/den; intercept=(sy-slope*sx)/n
  ss=0; maxAbs=0
  do o over observations
    e=(o['y']+0)-(intercept+slope*(o['x']+0)); ss=ss+e*e; if abs(e)>maxAbs then maxAbs=abs(e)
  end
  rms=self~sqrt(ss/n)
  ev=.directory~new; ev['slope']=slope; ev['intercept']=intercept; ev['rms']=rms; ev['max_abs_residual']=maxAbs
  return .MLFitAssessment~new(rms,n,'LINEAR_TRACK',ev)
::method sqrt private
  use strict arg x
  numeric digits 40
  if x<0 then raise syntax 88.900 array('square root requires non-negative value',x)
  if x=0 then return 0
  if x<1 then g=1; else g=x
  do i=1 to 48; g=(g+x/g)/2; end
  return g

::requires "MLCore.cls"
