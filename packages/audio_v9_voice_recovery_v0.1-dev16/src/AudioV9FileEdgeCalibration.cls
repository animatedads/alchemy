/* AudioV9FileEdgeCalibration.cls
 * dev6 corrected file-edge calibration model.
 *
 * Separate quantities:
 *   E = media extent residual (decoded extent - nominal filename spacing)
 *   C = camera/file clock step at the right-hand file start
 *   G = real seam gap/overlap, with G = C - E
 *   T = physical/path TDOA change across the edge
 *   L = observed cross-feed lag jump, with C = sign(feed) * (L - T)
 *       where sign(fc)=+1 and sign(fd)=-1 under the project lag convention.
 *
 * MEDIA_EXTENT never directly advances the source clock.  Correlated spatial
 * estimators are bundled and count as one candidate.  CLOCK_MEASURED requires
 * at least two independent candidate groups that agree inside the configured
 * sample tolerance.  Diagnostic exclusions may never reduce authority to a
 * single survivor.
 */
::options numeric inherit

::class AudioV9FileEdgeEvidence public
::method init
  expose id feed leftFile rightFile edgeSerial kind estimator bundle group valueSamples score sourceFamily tdoaChange tdoaKnown note
  use strict arg idValue,feedValue,leftValue,rightValue,edgeValue,kindValue,estimatorValue,bundleValue,groupValue,valueValue,scoreValue=1,sourceFamilyValue='UNLABELLED',tdoaChangeValue=0,tdoaKnownValue=.false,noteValue=''
  id=idValue~string; feed=feedValue~string~lower; leftFile=leftValue~string; rightFile=rightValue~string
  edgeSerial=edgeValue+0; kind=kindValue~string~upper; estimator=estimatorValue~string~upper
  bundle=bundleValue~string; group=groupValue~string; valueSamples=valueValue+0; score=scoreValue+0
  sourceFamily=sourceFamilyValue~string; tdoaChange=tdoaChangeValue+0; tdoaKnown=tdoaKnownValue; note=noteValue~string
  if feed\='fc' then if feed\='fd' then raise syntax 88.900 array('edge evidence feed must be fc/fd',feed)
  if valueSamples\=trunc(valueSamples) then raise syntax 88.900 array('edge evidence value must be whole samples',valueSamples)
  if tdoaChange\=trunc(tdoaChange) then raise syntax 88.900 array('TDOA change must be whole samples',tdoaChange)
  if score<0 then raise syntax 88.900 array('edge evidence score must be non-negative',score)
  valid=.array~of('MEDIA_EXTENT','SEAM_GAP','SPATIAL_LAG_JUMP','CLOCK_CANDIDATE')
  ok=.false; do v over valid; if kind=v then ok=.true; end
  if \ok then raise syntax 88.900 array('unsupported edge evidence kind',kind)
  if bundle='' then raise syntax 88.900 array('edge evidence bundle required',id)
  if group='' then raise syntax 88.900 array('edge evidence independent group required',id)
::method mediaExtent class
  use strict arg idValue,feedValue,leftValue,rightValue,sampleRateValue,decodedSamplesValue,scoreValue=1,bundleValue='MEDIA',noteValue=''
  sr=sampleRateValue+0; decoded=decodedSamplesValue+0
  if sr<1 then raise syntax 88.900 array('media extent sample rate must be positive',sr)
  if sr\=trunc(sr) then raise syntax 88.900 array('media extent sample rate must be integer',sr)
  if decoded<0 then raise syntax 88.900 array('decoded sample count must be non-negative',decoded)
  if decoded\=trunc(decoded) then raise syntax 88.900 array('decoded sample count must be whole',decoded)
  leftStart=.AudioV9VoiceClock~fromSourceName(leftValue)
  rightStart=.AudioV9VoiceClock~fromSourceName(rightValue)
  nominal=(rightStart-leftStart)*sr
  residual=decoded-nominal
  return self~new(idValue,feedValue,leftValue,rightValue,rightStart,'MEDIA_EXTENT','DECODED_LENGTH',bundleValue,'MEDIA_EXTENT',residual,scoreValue,'CONTAINER_GEOMETRY',0,.false,noteValue)
::method seamGap class
  use strict arg idValue,feedValue,leftValue,rightValue,edgeValue,gapSamplesValue,scoreValue=1,bundleValue,groupValue,sourceFamilyValue='UNLABELLED',noteValue=''
  return self~new(idValue,feedValue,leftValue,rightValue,edgeValue,'SEAM_GAP','SAME_FEED_CONTINUITY',bundleValue,groupValue,gapSamplesValue,scoreValue,sourceFamilyValue,0,.false,noteValue)
::method spatialLagJump class
  use strict arg idValue,feedValue,leftValue,rightValue,edgeValue,lagJumpSamplesValue,scoreValue=1,bundleValue,groupValue,sourceFamilyValue='UNLABELLED',tdoaChangeValue=0,tdoaKnownValue=.false,estimatorValue='SPATIAL',noteValue=''
  return self~new(idValue,feedValue,leftValue,rightValue,edgeValue,'SPATIAL_LAG_JUMP',estimatorValue,bundleValue,groupValue,lagJumpSamplesValue,scoreValue,sourceFamilyValue,tdoaChangeValue,tdoaKnownValue,noteValue)
::method clockCandidate class
  use strict arg idValue,feedValue,leftValue,rightValue,edgeValue,clockSamplesValue,scoreValue=1,bundleValue,groupValue,sourceFamilyValue='UNLABELLED',estimatorValue='DIRECT_CLOCK',noteValue=''
  return self~new(idValue,feedValue,leftValue,rightValue,edgeValue,'CLOCK_CANDIDATE',estimatorValue,bundleValue,groupValue,clockSamplesValue,scoreValue,sourceFamilyValue,0,.false,noteValue)
::method id; expose id; return id
::method feed; expose feed; return feed
::method leftFile; expose leftFile; return leftFile
::method rightFile; expose rightFile; return rightFile
::method edgeSerial; expose edgeSerial; return edgeSerial
::method kind; expose kind; return kind
::method estimator; expose estimator; return estimator
::method bundleId; expose bundle; return bundle
::method independentGroup; expose group; return group
::method valueSamples; expose valueSamples; return valueSamples
::method score; expose score; return score
::method sourceFamily; expose sourceFamily; return sourceFamily
::method tdoaChangeSamples; expose tdoaChange; return tdoaChange
::method tdoaKnown; expose tdoaKnown; return tdoaKnown
::method note; expose note; return note
::method tsv
  known='0'; if self~tdoaKnown then known='1'
  return self~id||'09'x||self~feed||'09'x||self~leftFile||'09'x||self~rightFile||'09'x||self~edgeSerial||'09'x||self~kind||'09'x||self~estimator||'09'x||self~bundleId||'09'x||self~independentGroup||'09'x||self~valueSamples||'09'x||self~score||'09'x||self~sourceFamily||'09'x||self~tdoaChangeSamples||'09'x||known||'09'x||self~note
::method canonicalText
  return 'AUDIO_V9_FILE_EDGE_EVIDENCE/2|id='||self~id||'|feed='||self~feed||'|edge='||self~leftFile||'->'||self~rightFile||'|kind='||self~kind||'|bundle='||self~bundleId||'|group='||self~independentGroup||'|value='||self~valueSamples

::class AudioV9FileEdgeCalibrationSolution public
::method init
  expose feed leftFile rightFile edgeSerial extent extentStatus clockStep cumulative gap gapStatus status candidateCount independentSupport spread seamSupport spatialSupport directSupport reason
  use strict arg feedValue,leftValue,rightValue,edgeValue,extentValue,extentStatusValue,clockValue,cumulativeValue,gapValue,gapStatusValue,statusValue,candidateCountValue,independentSupportValue,spreadValue,seamSupportValue,spatialSupportValue,directSupportValue,reasonValue=''
  feed=feedValue~string~lower; leftFile=leftValue~string; rightFile=rightValue~string; edgeSerial=edgeValue+0
  extent=extentValue+0; extentStatus=extentStatusValue~string~upper; clockStep=clockValue+0; cumulative=cumulativeValue+0; gap=gapValue+0; gapStatus=gapStatusValue~string~upper; status=statusValue~string~upper
  candidateCount=candidateCountValue+0; independentSupport=independentSupportValue+0; spread=spreadValue+0
  seamSupport=seamSupportValue+0; spatialSupport=spatialSupportValue+0; directSupport=directSupportValue+0; reason=reasonValue~string
::method feed; expose feed; return feed
::method leftFile; expose leftFile; return leftFile
::method rightFile; expose rightFile; return rightFile
::method edgeSerial; expose edgeSerial; return edgeSerial
::method mediaExtentResidualSamples; expose extent; return extent
::method mediaExtentStatus; expose extentStatus; return extentStatus
::method clockStepSamples; expose clockStep; return clockStep
::method cumulativeCorrectionSamples; expose cumulative; return cumulative
::method seamGapSamples; expose gap; return gap
::method seamGapStatus; expose gapStatus; return gapStatus
::method status; expose status; return status
::method candidateCount; expose candidateCount; return candidateCount
::method independentSupport; expose independentSupport; return independentSupport
::method spreadSamples; expose spread; return spread
::method seamSupport; expose seamSupport; return seamSupport
::method spatialSupport; expose spatialSupport; return spatialSupport
::method directSupport; expose directSupport; return directSupport
::method reason; expose reason; return reason
::method resolved
  expose status
  return status='CLOCK_MEASURED'
::method tsv
  return self~feed||'09'x||self~leftFile||'09'x||self~rightFile||'09'x||self~edgeSerial||'09'x||self~mediaExtentResidualSamples||'09'x||self~mediaExtentStatus||'09'x||self~clockStepSamples||'09'x||self~cumulativeCorrectionSamples||'09'x||self~seamGapSamples||'09'x||self~seamGapStatus||'09'x||self~status||'09'x||self~candidateCount||'09'x||self~independentSupport||'09'x||self~spreadSamples||'09'x||self~seamSupport||'09'x||self~spatialSupport||'09'x||self~directSupport||'09'x||self~reason

::class AudioV9FileEdgeCalibrationSolver public
::method init
  expose extentTolerance agreementTolerance minIndependent
  use strict arg extentToleranceValue=4,agreementToleranceValue=8,minIndependentValue=2
  extentTolerance=extentToleranceValue+0; agreementTolerance=agreementToleranceValue+0; minIndependent=minIndependentValue+0
  if extentTolerance<0 then raise syntax 88.900 array('extent tolerance must be non-negative')
  if agreementTolerance<0 then raise syntax 88.900 array('agreement tolerance must be non-negative')
  if minIndependent<2 then raise syntax 88.900 array('clock measurement requires at least two independent groups')
::method solve
  expose extentTolerance agreementTolerance minIndependent
  use strict arg observations,previousCorrection=0
  if \observations~isA(.Array) then raise syntax 88.900 array('edge calibration requires Array')
  if observations~items<1 then raise syntax 88.900 array('edge calibration requires at least one observation')
  first=observations[1]; feed=first~feed; left=first~leftFile; right=first~rightFile; edge=first~edgeSerial
  do o over observations
    if \o~isA(.AudioV9FileEdgeEvidence) then raise syntax 88.900 array('v2 edge evidence required')
    if o~feed\=feed then raise syntax 88.900 array('mixed feed in edge calibration')
    if o~leftFile\=left then raise syntax 88.900 array('mixed left file in edge calibration')
    if o~rightFile\=right then raise syntax 88.900 array('mixed right file in edge calibration')
    if o~edgeSerial\=edge then raise syntax 88.900 array('mixed edge serial in edge calibration')
  end

  extentInfo=self~resolveExtent(observations,extentTolerance)
  extent=extentInfo['value']; extentStatus=extentInfo['status']
  rawCandidates=.array~new

  do o over observations
    select
      when o~kind='SEAM_GAP' then do
        if extentStatus='MEASURED' then do
          c=.directory~new; c['value']=extent+o~valueSamples; c['score']=o~score; c['bundle']=o~bundleId; c['group']='SEAM|'||o~independentGroup; c['domain']='SEAM'; rawCandidates~append(c)
        end
      end
      when o~kind='SPATIAL_LAG_JUMP' then do
        if o~tdoaKnown then do
          residual=o~valueSamples-o~tdoaChangeSamples
          if feed='fd' then residual=-residual
          c=.directory~new; c['value']=residual; c['score']=o~score; c['bundle']=o~bundleId; c['group']='SPATIAL|'||o~independentGroup; c['domain']='SPATIAL'; rawCandidates~append(c)
        end
      end
      when o~kind='CLOCK_CANDIDATE' then do
        c=.directory~new; c['value']=o~valueSamples; c['score']=o~score; c['bundle']=o~bundleId; c['group']='DIRECT|'||o~independentGroup; c['domain']='DIRECT'; rawCandidates~append(c)
      end
      otherwise nop
    end
  end

  candidates=self~bundleCandidates(rawCandidates)
  if candidates~items=0 then do
    status='UNRESOLVED'; reason='no clock candidate'
    if extentStatus='MEASURED' then do; status='EXTENT_ONLY'; reason='media extent known but no independent clock evidence'; end
    return .AudioV9FileEdgeCalibrationSolution~new(feed,left,right,edge,extent,extentStatus,0,previousCorrection,0,'UNKNOWN',status,0,0,0,0,0,0,reason)
  end

  best=self~bestCluster(candidates,agreementTolerance)
  independent=best['independent']; spread=best['spread']; status='CLOCK_CANDIDATE'; reason='insufficient independent agreement'; clock=0; cumulative=previousCorrection
  if independent>=minIndependent then do
    competitor=self~competingCluster(candidates,best,agreementTolerance,minIndependent)
    if competitor then do; status='CLOCK_AMBIGUOUS'; reason='multiple independently-supported clock clusters'; end
    else do
      status='CLOCK_MEASURED'; reason='independent clock candidates agree'; clock=best['value']; cumulative=previousCorrection+clock
    end
  end

  gap=0; gapStatus='UNKNOWN'
  if status='CLOCK_MEASURED' then do
    if extentStatus='MEASURED' then do
      gap=clock-extent
      if gap=0 then gapStatus='CONTIGUOUS'
      else if gap>0 then gapStatus='GAP_MEASURED'
      else gapStatus='OVERLAP_MEASURED'
    end
  end

  return .AudioV9FileEdgeCalibrationSolution~new(feed,left,right,edge,extent,extentStatus,clock,cumulative,gap,gapStatus,status,candidates~items,independent,spread,best['seam'],best['spatial'],best['direct'],reason)

::method resolveExtent private
  use strict arg observations,tolerance
  bundles=.directory~new
  do o over observations
    if o~kind\='MEDIA_EXTENT' then iterate
    key=o~bundleId
    if \bundles~hasIndex(key) then do
      d=.directory~new; d['sum']=0; d['weight']=0; bundles[key]=d
    end
    d=bundles[key]; w=o~score; if w<=0 then w=1
    d['sum']=d['sum']+o~valueSamples*w; d['weight']=d['weight']+w
  end
  values=.array~new
  do k over bundles~allIndexes
    d=bundles[k]; values~append(d['sum']/d['weight'])
  end
  out=.directory~new; out['value']=0; out['status']='UNKNOWN'
  if values~items=0 then return out
  min=values[1]; max=values[1]; sum=0
  do v over values
    sum=sum+v; if v<min then min=v; if v>max then max=v
  end
  if max-min>tolerance then do; out['status']='AMBIGUOUS'; return out; end
  mean=sum/values~items; out['value']=self~roundSample(mean); out['status']='MEASURED'; return out

::method bundleCandidates private
  use strict arg raw
  bundles=.directory~new
  do c over raw
    key=c['domain']||'|'||c['bundle']
    if \bundles~hasIndex(key) then do
      d=.directory~new; d['sum']=0; d['weight']=0; d['group']=c['group']; d['domain']=c['domain']; bundles[key]=d
    end
    d=bundles[key]
    /* One bundle is one vote.  If a bundle mixes independent-group labels it
     * is malformed because correlated estimators may not manufacture votes. */
    if d['group']\=c['group'] then raise syntax 88.900 array('edge estimator bundle mixes independent groups',key,d['group'],c['group'])
    w=c['score']; if w<=0 then w=1
    d['sum']=d['sum']+c['value']*w; d['weight']=d['weight']+w
  end
  keys=.array~new; do k over bundles~allIndexes; keys~append(k); end; keys=self~sortStrings(keys)
  out=.array~new
  do k over keys
    d=bundles[k]; c=.directory~new; c['value']=self~roundSample(d['sum']/d['weight']); c['score']=d['weight']; c['group']=d['group']; c['domain']=d['domain']; c['bundle']=k; out~append(c)
  end
  return self~sortCandidates(out)

::method bestCluster private
  use strict arg candidates,tolerance
  best=.nil
  do i=1 to candidates~items
    cluster=.array~new; anchor=candidates[i]['value']
    do c over candidates
      if abs(c['value']-anchor)<=tolerance then cluster~append(c)
    end
    info=self~clusterInfo(cluster)
    if best==.nil then best=info
    else if self~clusterBetter(info,best) then best=info
  end
  return best

::method competingCluster private
  use strict arg candidates,best,tolerance,minIndependent
  do i=1 to candidates~items
    c=candidates[i]
    if abs(c['value']-best['value'])<=tolerance then iterate
    cluster=.array~new; anchor=c['value']
    do x over candidates
      if abs(x['value']-anchor)<=tolerance then cluster~append(x)
    end
    info=self~clusterInfo(cluster)
    if info['independent']>=minIndependent then return .true
  end
  return .false

::method clusterInfo private
  use strict arg cluster
  groups=.directory~new; sum=0; weight=0; min=.nil; max=.nil; seam=0; spatial=0; direct=0; bundles=.array~new
  do c over cluster
    groups[c['group']]=1; w=c['score']; if w<=0 then w=1
    sum=sum+c['value']*w; weight=weight+w
    if min==.nil then do; min=c['value']; max=c['value']; end
    else do; if c['value']<min then min=c['value']; if c['value']>max then max=c['value']; end
    if c['domain']='SEAM' then seam=seam+1
    else if c['domain']='SPATIAL' then spatial=spatial+1
    else if c['domain']='DIRECT' then direct=direct+1
    bundles~append(c['bundle'])
  end
  d=.directory~new; d['value']=self~roundSample(sum/weight); d['independent']=groups~items; d['score']=weight; d['spread']=max-min; d['seam']=seam; d['spatial']=spatial; d['direct']=direct; d['bundles']=bundles
  return d

::method clusterBetter private
  use strict arg a,b
  if a['independent']>b['independent'] then return .true
  if a['independent']<b['independent'] then return .false
  if a['score']>b['score'] then return .true
  if a['score']<b['score'] then return .false
  if a['spread']<b['spread'] then return .true
  if a['spread']>b['spread'] then return .false
  if abs(a['value'])<abs(b['value']) then return .true
  if abs(a['value'])>abs(b['value']) then return .false
  return a['value']<b['value']

::method sortCandidates private
  use strict arg input
  out=.array~new
  do c over input
    if out~items=0 then out~append(c)
    else do
      tmp=.array~new; placed=.false
      do i=1 to out~items
        if \placed then do
          before=.false
          if c['value']<out[i]['value'] then before=.true
          else if c['value']=out[i]['value'] then if c['bundle']<out[i]['bundle'] then before=.true
          if before then do; tmp~append(c); placed=.true; end
        end
        tmp~append(out[i])
      end
      if \placed then tmp~append(c)
      out=tmp
    end
  end
  return out

::method sortStrings private
  use strict arg input
  out=.array~new
  do v over input
    if out~items=0 then out~append(v)
    else do
      tmp=.array~new; placed=.false
      do i=1 to out~items
        if \placed then if v<out[i] then do; tmp~append(v); placed=.true; end
        tmp~append(out[i])
      end
      if \placed then tmp~append(v)
      out=tmp
    end
  end
  return out

::method roundSample private
  use strict arg x
  if x=0 then return 0
  return trunc(x+0.5*sign(x))

::class AudioV9EdgePathContinuityFitter public
::method init
  expose minPoints maxRms
  use strict arg minPointsValue=3,maxRmsSamplesValue=8
  minPoints=minPointsValue+0; maxRms=maxRmsSamplesValue+0
  if minPoints<2 then raise syntax 88.900 array('path continuity fit requires at least two points per side')
  if maxRms<0 then raise syntax 88.900 array('path continuity RMS threshold must be non-negative')
::method fit
  expose minPoints maxRms
  use strict arg idValue,feedValue,leftValue,rightValue,edgeSerialValue,sourceFamilyValue,pathIdValue,beforePoints,afterPoints,scoreValue=1
  if \beforePoints~isA(.Array) then raise syntax 88.900 array('before path points must be Array')
  if \afterPoints~isA(.Array) then raise syntax 88.900 array('after path points must be Array')
  if beforePoints~items<minPoints then return .nil
  if afterPoints~items<minPoints then return .nil
  b=self~regress(beforePoints,edgeSerialValue)
  a=self~regress(afterPoints,edgeSerialValue)
  if b['rms']>maxRms then return .nil
  if a['rms']>maxRms then return .nil
  jump=self~roundSample(a['intercept']-b['intercept'])
  score=scoreValue+0
  fitScore=1/(1+b['rms']+a['rms'])
  if score<=0 then score=fitScore
  else score=score*fitScore
  bundle='PATH|'||sourceFamilyValue||'|'||pathIdValue
  group='SOURCE|'||sourceFamilyValue
  note='CONTINUOUS_PATH_MODEL;before_rms='||b['rms']||';after_rms='||a['rms']||';before_slope='||b['slope']||';after_slope='||a['slope']||';before_intercept='||b['intercept']||';after_intercept='||a['intercept']
  /* TDOA change at the mathematical seam is zero under this explicitly
   * declared continuous-source/path model.  Motion on each side is carried by
   * the fitted slopes; a poor fit returns NIL and gains no clock authority. */
  return .AudioV9FileEdgeEvidence~spatialLagJump(idValue,feedValue,leftValue,rightValue,edgeSerialValue,jump,score,bundle,group,sourceFamilyValue,0,.true,'SOURCE_PATH_TREND',note)
::method regress private
  use strict arg points,edgeSerial
  sw=0; sx=0; sy=0; sxx=0; sxy=0
  do p over points
    x=(p['time_ms']+0)-(edgeSerial+0)*1000
    y=p['lag_samples']+0; w=p['score']+0; if w<=0 then w=1
    sw=sw+w; sx=sx+w*x; sy=sy+w*y; sxx=sxx+w*x*x; sxy=sxy+w*x*y
  end
  denom=sw*sxx-sx*sx
  if denom=0 then raise syntax 88.900 array('path continuity points have singular time geometry')
  slope=(sw*sxy-sx*sy)/denom; intercept=(sy-slope*sx)/sw
  ss=0
  do p over points
    x=(p['time_ms']+0)-(edgeSerial+0)*1000; y=p['lag_samples']+0; w=p['score']+0; if w<=0 then w=1
    e=y-(intercept+slope*x); ss=ss+w*e*e
  end
  d=.directory~new; d['slope']=slope; d['intercept']=intercept; d['rms']=self~sqrt(ss/sw); return d
::method sqrt private
  use strict arg x
  numeric digits 30
  if x<0 then raise syntax 88.900 array('sqrt requires non-negative value',x)
  if x=0 then return 0
  if x<1 then g=1; else g=x
  do i=1 to 48; g=(g+x/g)/2; end
  return g
::method roundSample private
  use strict arg x
  if x=0 then return 0
  return trunc(x+0.5*sign(x))

::class AudioV9FileEdgeCalibrationMap public
::method init
  expose byRight
  use strict arg solutions=.nil
  byRight=.directory~new
  if solutions\==.nil then do; do s over solutions; self~put(s); end; end
::method put
  expose byRight
  use strict arg solution
  if \solution~isA(.AudioV9FileEdgeCalibrationSolution) then raise syntax 88.900 array('v2 edge calibration solution required')
  key=solution~feed||'|'||solution~rightFile
  if byRight~hasIndex(key) then raise syntax 88.900 array('duplicate v2 edge solution',key)
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
  call stream path,'C','OPEN READ'
  header=linein(path)
  expected='feed'||'09'x||'left_file'||'09'x||'right_file'||'09'x||'edge_serial'||'09'x||'media_extent_residual_samples'||'09'x||'media_extent_status'||'09'x||'clock_step_samples'||'09'x||'cumulative_correction_samples'||'09'x||'seam_gap_samples'||'09'x||'seam_gap_status'||'09'x||'status'||'09'x||'candidate_count'||'09'x||'independent_support'||'09'x||'spread_samples'||'09'x||'seam_support'||'09'x||'spatial_support'||'09'x||'direct_support'||'09'x||'reason'
  if header\==expected then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('unsafe/unsupported edge map schema: dev6 requires calibration v2',path); end
  do while lines(path)>0
    line=linein(path); if line='' then iterate
    f=line~makeArray('09'x)
    if f~items<>18 then do; call stream path,'C','CLOSE'; raise syntax 88.900 array('bad v2 edge map row width',f~items); end
    s=.AudioV9FileEdgeCalibrationSolution~new(f[1],f[2],f[3],f[4],f[5],f[6],f[7],f[8],f[9],f[10],f[11],f[12],f[13],f[14],f[15],f[16],f[17],f[18])
    m~put(s)
  end
  call stream path,'C','CLOSE'; return m

::class AudioV9CalibratedSourceClock public
::method init
  expose feed names sampleRate corrections statuses effectiveStarts edgeMap
  use strict arg feedValue,nameValues,sampleRateValue=8000,edgeMapValue=.nil
  feed=feedValue~string~lower; names=nameValues~copy; sampleRate=sampleRateValue+0
  if feed\='fc' then if feed\='fd' then raise syntax 88.900 array('calibrated clock feed must be fc/fd')
  if \names~isA(.Array) then raise syntax 88.900 array('calibrated clock requires Array names')
  if names~items<2 then raise syntax 88.900 array('calibrated clock requires source names')
  if edgeMapValue==.nil then edgeMap=.AudioV9FileEdgeCalibrationMap~new; else edgeMap=edgeMapValue
  corrections=.array~new; statuses=.array~new; effectiveStarts=.array~new; previous=0
  do i=1 to names~items
    nominal=.AudioV9VoiceClock~fromSourceName(names[i])*sampleRate
    if i=1 then do; correction=0; status='ANCHOR'; end
    else do
      sol=edgeMap~forRight(feed,names[i])
      if sol==.nil then do; correction=previous; status='PREDICTED'; end
      else if sol~resolved then do; correction=sol~cumulativeCorrectionSamples; status='CLOCK_MEASURED'; end
      else do; correction=previous; status=sol~status; end
    end
    effective=nominal+correction
    if i>1 then if effective<=effectiveStarts[i-1] then raise syntax 88.900 array('calibrated correction makes clock non-monotonic',feed,names[i],correction)
    corrections~append(correction); statuses~append(status); effectiveStarts~append(effective); previous=correction
  end
::method correctionFor
  expose names corrections
  use strict arg name
  do i=1 to names~items; if names[i]=name then return corrections[i]; end
  raise syntax 88.900 array('source absent from calibrated clock',name)
::method statusFor
  expose names statuses
  use strict arg name
  do i=1 to names~items; if names[i]=name then return statuses[i]; end
  raise syntax 88.900 array('source absent from calibrated clock',name)
::method effectiveStartFor
  expose names effectiveStarts
  use strict arg name
  do i=1 to names~items; if names[i]=name then return effectiveStarts[i]; end
  raise syntax 88.900 array('source absent from calibrated clock',name)
::method slices
  expose feed names sampleRate corrections statuses effectiveStarts
  use strict arg startSecond,endSecond
  globalStart=(startSecond+0)*sampleRate; globalEnd=(endSecond+0)*sampleRate
  if globalEnd<=globalStart then raise syntax 88.900 array('calibrated source range must be positive')
  out=.array~new
  do i=1 to names~items-1
    fileStart=effectiveStarts[i]; fileEnd=effectiveStarts[i+1]
    if fileEnd<=globalStart then iterate
    if fileStart>=globalEnd then leave
    a=globalStart; if fileStart>a then a=fileStart
    b=globalEnd; if fileEnd<b then b=fileEnd
    if b>a then do
      offset=a-fileStart; count=b-a
      out~append(.AudioV9CalibratedSampleSlice~new(feed,names[i],.AudioV9VoiceClock~fromSourceName(names[i]),fileStart,a,b,offset,count,corrections[i],statuses[i],sampleRate))
    end
  end
  if out~items=0 then raise syntax 88.900 array('no calibrated source coverage',feed,startSecond,endSecond)
  if out[1]~sliceStartSample<>globalStart then raise syntax 88.900 array('calibrated source coverage does not start at request',feed,globalStart,out[1]~sliceStartSample)
  if out[out~items]~sliceEndSample<>globalEnd then raise syntax 88.900 array('calibrated source coverage does not end at request',feed,globalEnd,out[out~items]~sliceEndSample)
  return out

::class AudioV9CalibratedSampleSlice public
::method init
  expose feed name nominalStart effectiveStart sliceStart sliceEnd offsetSamples sampleCount correction status sampleRate
  use strict arg feedValue,nameValue,nominalValue,effectiveValue,sliceStartValue,sliceEndValue,offsetValue,countValue,correctionValue,statusValue,sampleRateValue
  feed=feedValue~string~lower; name=nameValue~string; nominalStart=nominalValue+0; effectiveStart=effectiveValue+0
  sliceStart=sliceStartValue+0; sliceEnd=sliceEndValue+0; offsetSamples=offsetValue+0; sampleCount=countValue+0
  correction=correctionValue+0; status=statusValue~string; sampleRate=sampleRateValue+0
  if sampleCount<=0 then raise syntax 88.900 array('invalid calibrated sample count',sampleCount)
  if sliceEnd<=sliceStart then raise syntax 88.900 array('invalid calibrated sample range',sliceStart,sliceEnd)
  if offsetSamples<0 then raise syntax 88.900 array('invalid calibrated source offset',offsetSamples)
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

::requires 'AudioV9VoiceCampaign.cls'
