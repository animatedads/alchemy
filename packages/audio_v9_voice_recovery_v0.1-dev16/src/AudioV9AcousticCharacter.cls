/* AudioV9AcousticCharacter.cls
 * dev2: box-derived acoustic character, source tracks and anonymous source families.
 * Classification is evidence, never permission to delete source material.
 */
::options numeric inherit

::class AudioV9AcousticCharacterSchema public
::method init
  expose closeSchema
  dims=.array~new
  dims~append(.MLCloseHashDimension~new('residual_motion_db',0,20,128,5,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('turn_db',0,30,128,5,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('active_fraction',0,1,128,5,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('width_db',0,40,96,2,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('range_db',0,60,96,2,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('spatial_coherence',0,1,128,6,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('ab_ratio_db',-40,40,128,2,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('crest',0,30,96,3,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('lag_abs_ms',0,500,128,3,'CLAMP'))
  closeSchema=.MLCloseHashSchema~new(dims,'AUDIO-V9-ACOUSTIC-CHARACTER/1')
::method closeSchema; expose closeSchema; return closeSchema
::method encode
  expose closeSchema
  use strict arg character
  if \character~isA(.AudioV9BoxCharacter) then raise syntax 88.900 array('acoustic schema requires AudioV9BoxCharacter')
  return closeSchema~encode(character~featureVector)
::method difference
  expose closeSchema
  use strict arg left,right
  return closeSchema~difference(self~encode(left),self~encode(right))
::method dominantCompatible
  expose closeSchema
  use strict arg left,right,maxDominant
  lv=left~featureVector; rv=right~featureVector
  do i=1 to closeSchema~featureCount
    dim=closeSchema~dimension(i)
    lc=dim~quantize(lv[i]); rc=dim~quantize(rv[i])
    if abs(lc-rc)*dim~importance>maxDominant then return .false
  end
  return .true

::class AudioV9BoxCharacter public
::method init
  expose id absoluteStartMs feed box spatial
  use strict arg idValue,absoluteStartValue,feedValue,boxValue,spatialValue=.nil
  id=idValue~string; absoluteStartMs=absoluteStartValue+0; feed=feedValue~string~upper; box=boxValue; spatial=spatialValue
  if \box~isA(.AudioV9SpectralBoxEvidence) then raise syntax 88.900 array('box character requires AudioV9SpectralBoxEvidence')
  if spatial\==.nil then do
    if \spatial~isA(.AudioV9SpatialMeasurement) then raise syntax 88.900 array('box character spatial evidence must be AudioV9SpatialMeasurement')
  end
::method id; expose id; return id
::method absoluteStartMs; expose absoluteStartMs; return absoluteStartMs
::method absoluteEndMs; expose absoluteStartMs box; return absoluteStartMs+(box~endMillis-box~startMillis)
::method feed; expose feed; return feed
::method box; expose box; return box
::method spatial; expose spatial; return spatial
::method residualMotionDb; expose box; return box~residualMotionDb
::method turnDb; expose box; return box~turnDb
::method activeFraction; expose box; return box~activeFraction
::method widthDb; expose box; return box~widthDb
::method rangeDb; expose box; return box~rangeDb
::method bandIndex; expose box; return box~bandIndex
::method centerHz; expose box; return box~centerHz
::method spatialCoherence
  expose spatial
  if spatial==.nil then return 0
  return spatial~refinedCoherence
::method ratioDb
  expose spatial
  if spatial==.nil then return 0
  return spatial~ratioDb
::method crest
  expose spatial
  if spatial==.nil then return 0
  if spatial~crestA>spatial~crestB then return spatial~crestA
  return spatial~crestB
::method lagAbsMs
  expose spatial
  if spatial==.nil then return 0
  return abs(spatial~refinedLagMs)
::method featureVector
  return .array~of(self~residualMotionDb,self~turnDb,self~activeFraction,self~widthDb,self~rangeDb,self~spatialCoherence,self~ratioDb,self~crest,self~lagAbsMs)
::method residualHash; expose box; return box~residualHash
::method midHash; expose box; return box~midHash
::method canonicalText
  return 'AUDIO_V9_BOX_CHARACTER/1|id='||self~id||'|time='||self~absoluteStartMs||'..'||self~absoluteEndMs||'|feed='||self~feed||'|band='||self~bandIndex||'|motion='||self~residualMotionDb||'|turn='||self~turnDb||'|active='||self~activeFraction||'|coherence='||self~spatialCoherence||'|ratioDb='||self~ratioDb||'|crest='||self~crest||'|lagAbsMs='||self~lagAbsMs

::class AudioV9AcousticTrack public
::method init
  expose id members temporalCache closeCache stats featureCache
  use strict arg idValue,sourceMembers
  id=idValue~string; members=.array~new; temporalCache=.directory~new; closeCache=.directory~new; stats=.directory~new
  if \sourceMembers~isA(.Array) | sourceMembers~items<1 then raise syntax 88.900 array('acoustic track requires nonempty Array')
  sums=.directory~new
  do key over .array~of('motion','turn','active','width','coherence','crest','lag','ratio','center'); sums[key]=0; end
  do x over sourceMembers
    if \x~isA(.AudioV9BoxCharacter) then raise syntax 88.900 array('acoustic track member must be AudioV9BoxCharacter')
    members~append(x)
    sums['motion']=sums['motion']+x~residualMotionDb; sums['turn']=sums['turn']+x~turnDb; sums['active']=sums['active']+x~activeFraction
    sums['width']=sums['width']+x~widthDb; sums['coherence']=sums['coherence']+x~spatialCoherence; sums['crest']=sums['crest']+x~crest
    sums['lag']=sums['lag']+x~lagAbsMs; sums['ratio']=sums['ratio']+x~ratioDb; sums['center']=sums['center']+x~centerHz
  end
  n=members~items
  do key over sums~allIndexes; stats[key]=sums[key]/n; end
  featureCache=.array~of(stats['motion'],stats['turn'],stats['active'],stats['width'],stats['coherence'],stats['crest'],stats['lag'],stats['ratio'],stats['center'])
::method id; expose id; return id
::method members; expose members; return members~copy
::method items; expose members; return members~items
::method last; expose members; return members[members~items]
::method feed; expose members; return members[1]~feed
::method startMs; expose members; return members[1]~absoluteStartMs
::method endMs; expose members; return members[members~items]~absoluteEndMs
::method durationMs; return self~endMs-self~startMs
::method mean
  expose stats
  use strict arg methodName
  k=methodName~string~upper
  select
    when k='RESIDUALMOTIONDB' then key='motion'
    when k='TURNDB' then key='turn'
    when k='ACTIVEFRACTION' then key='active'
    when k='WIDTHDB' then key='width'
    when k='SPATIALCOHERENCE' then key='coherence'
    when k='CREST' then key='crest'
    when k='LAGABSMS' then key='lag'
    when k='RATIODB' then key='ratio'
    when k='CENTERHZ' then key='center'
    otherwise raise syntax 88.900 array('unknown cached acoustic-track statistic',methodName)
  end
  return stats[key]
::method meanResidualMotion; return self~mean('RESIDUALMOTIONDB')
::method meanTurn; return self~mean('TURNDB')
::method meanActive; return self~mean('ACTIVEFRACTION')
::method meanWidth; return self~mean('WIDTHDB')
::method meanCoherence; return self~mean('SPATIALCOHERENCE')
::method meanCrest; return self~mean('CREST')
::method meanLagAbs; return self~mean('LAGABSMS')
::method meanRatioDb; return self~mean('RATIODB')
::method meanCenterHz; return self~mean('CENTERHZ')
::method featureVector
  expose featureCache
  return featureCache~copy
::method closeHash
  expose closeCache featureCache
  use strict arg schema
  key=schema~id
  if closeCache~hasIndex(key) then return closeCache[key]
  h=schema~encode(featureCache); closeCache[key]=h
  return h
::method temporalSeries
  expose members
  if members~items<3 then return .nil
  times=.array~new; motion=.array~new; turns=.array~new; active=.array~new; width=.array~new; coherence=.array~new; ratio=.array~new; lag=.array~new
  /* Temporal source shape is track-relative.  Absolute campaign epoch is provenance,
   * not acoustic identity, and relative milliseconds also avoid precision loss in
   * dependencies whose method-local numeric environment is narrower than ours. */
  baseTime=members[1]~absoluteStartMs
  do x over members
    times~append(x~absoluteStartMs-baseTime); motion~append(x~residualMotionDb); turns~append(x~turnDb); active~append(x~activeFraction); width~append(x~widthDb); coherence~append(x~spatialCoherence); ratio~append(x~ratioDb); lag~append(x~lagAbsMs)
  end
  names=.array~of('MOTION','TURN','ACTIVE','WIDTH','COHERENCE','AB_RATIO','LAG')
  values=.array~of(motion,turns,active,width,coherence,ratio,lag)
  weights=.array~of(5,5,5,2,6,3,3)
  return .MLTemporalPatternSeries~new(times,names,values,weights,self~id)
::method temporalHash
  expose temporalCache
  use strict arg schema=.nil
  series=self~temporalSeries
  if series==.nil then return .nil
  if schema==.nil then schema=.MLCylindricalTemporalPatternSchema~new(.MLTemporalPatternPolicy~new(24,32,32,72,36,36,1,8,4,8,10,.true,.true,1),'AUDIO-V9-ACOUSTIC-TRACK-TEMPORAL/1')
  key=schema~id
  if temporalCache~hasIndex(key) then return temporalCache[key]
  h=schema~encode(series); temporalCache[key]=h
  return h
::method canonicalText
  return 'AUDIO_V9_ACOUSTIC_TRACK/2|id='||self~id||'|members='||self~items||'|time='||self~startMs||'..'||self~endMs||'|motion='||self~meanResidualMotion||'|turn='||self~meanTurn||'|active='||self~meanActive||'|coherence='||self~meanCoherence||'|crest='||self~meanCrest||'|centerHz='||self~meanCenterHz

::class AudioV9TrackBuilder public
::method init
  expose schema maxGapMs maxBandDelta maxDominant
  use strict arg schemaValue=.nil,maxGapValue=750,maxBandDeltaValue=1,maxDominantValue=36
  if schemaValue==.nil then schema=.AudioV9AcousticCharacterSchema~new; else schema=schemaValue
  maxGapMs=maxGapValue+0; maxBandDelta=maxBandDeltaValue+0; maxDominant=maxDominantValue+0
::method build
  expose schema maxGapMs maxBandDelta maxDominant
  use strict arg characters
  if \characters~isA(.Array) then raise syntax 88.900 array('track builder requires Array')
  ordered=characters~copy; ordered~sortWith(.AudioV9CharacterTimeComparator~new)
  tracks=.array~new; active=.directory~new; prunedAt=.directory~new; nextId=1
  do c over ordered
    bestIndex=0; bestDiff=.nil; seen=.directory~new; candidates=.array~new
    lowBand=c~bandIndex-maxBandDelta; highBand=c~bandIndex+maxBandDelta
    do band=lowBand to highBand
      if band<0 then iterate
      key=c~feed||'|'||band
      if \active~hasIndex(key) then iterate
      bucket=active[key]
      /* Prune this feed/band bucket once per acoustic time.  A stale entry can
       * never satisfy maxGapMs, so removal cannot change track semantics. */
      needsPrune=.true
      if prunedAt~hasIndex(key) then do
        if prunedAt[key]=c~absoluteStartMs then needsPrune=.false
      end
      if needsPrune then do
        live=.array~new
        do ai over bucket
          last=tracks[ai]~last
          gap=c~absoluteStartMs-last~absoluteStartMs
          if gap<=maxGapMs then live~append(ai)
        end
        active[key]=live; bucket=live; prunedAt[key]=c~absoluteStartMs
      end
      do ai over bucket
        sk=ai~string
        if seen~hasIndex(sk) then iterate
        seen[sk]=.true; candidates~append(ai)
      end
    end
    /* Preserve the original all-track scan's tie authority: lowest creation
     * index wins when ML scores are equal.  Indexing may prune impossible
     * candidates but must not alter deterministic tie-breaking. */
    candidates~sortWith(.AudioV9TrackIndexComparator~new)
    do ai over candidates
      t=tracks[ai]; last=t~last
      gap=c~absoluteStartMs-last~absoluteStartMs
      if gap<=0 then iterate
      if gap>maxGapMs then iterate
      if c~feed\==last~feed then iterate
      if abs(c~bandIndex-last~bandIndex)>maxBandDelta then iterate
      /* This coordinate-wise check is exactly necessary for the existing
       * ML dominantDelta gate.  Full significance-ordered difference is only
       * constructed for candidates that can possibly pass that gate. */
      if \schema~dominantCompatible(last,c,maxDominant) then iterate
      d=schema~difference(last,c)
      if bestIndex=0 then do; bestIndex=ai; bestDiff=d; end
      else if d~score<bestDiff~score then do; bestIndex=ai; bestDiff=d; end
    end
    if bestIndex=0 then do
      arr=.array~of(c); tracks~append(.AudioV9AcousticTrack~new('TRACK_'||nextId,arr)); idx=tracks~items
      key=c~feed||'|'||c~bandIndex
      if \active~hasIndex(key) then active[key]=.array~new
      active[key]~append(idx); nextId=nextId+1
    end
    else do
      best=tracks[bestIndex]; oldLast=best~last; oldKey=oldLast~feed||'|'||oldLast~bandIndex
      arr=best~members; arr~append(c); tracks[bestIndex]=.AudioV9AcousticTrack~new(best~id,arr)
      newKey=c~feed||'|'||c~bandIndex
      if oldKey\==newKey then do
        oldBucket=.array~new
        if active~hasIndex(oldKey) then do ai over active[oldKey]; if ai<>bestIndex then oldBucket~append(ai); end
        active[oldKey]=oldBucket
        if \active~hasIndex(newKey) then active[newKey]=.array~new
        active[newKey]~append(bestIndex)
      end
    end
  end
  return tracks

::class AudioV9TrackIndexComparator private
::method compare
  use strict arg a,b
  if a+0<b+0 then return -1
  if a+0>b+0 then return 1
  return 0

::class AudioV9CharacterTimeComparator private
::method compare
  use strict arg a,b
  if a~absoluteStartMs<b~absoluteStartMs then return -1
  if a~absoluteStartMs>b~absoluteStartMs then return 1
  if a~bandIndex<b~bandIndex then return -1
  if a~bandIndex>b~bandIndex then return 1
  if a~id<b~id then return -1
  if a~id>b~id then return 1
  return 0

::class AudioV9AcousticCharacterAssembler public
::method init
  expose scanStepMs
  use strict arg scanStepValue=4000
  scanStepMs=scanStepValue+0
::method assemble
  expose scanStepMs
  use strict arg boxes,scan,absoluteChunkStartMs,feed
  if \boxes~isA(.Array) then raise syntax 88.900 array('character assembler requires box Array')
  if \scan~isA(.AudioV9SpatialScan) then raise syntax 88.900 array('character assembler requires spatial scan')
  feed=feed~string~upper; out=.array~new; rows=scan~rows
  do b over boxes
    ix=trunc(b~startMillis/scanStepMs)+1
    if ix<1 then ix=1
    if ix>rows~items then ix=rows~items
    absolute=(absoluteChunkStartMs+0)+b~startMillis
    id=feed||'|'||absolute||'|B'||b~bandIndex
    out~append(.AudioV9BoxCharacter~new(id,absolute,feed,b,rows[ix]~measurement))
  end
  return out

::class AudioV9SourceFamilyEvidence public
::method init
  expose voice alarm impulse background vocalisation
  use strict arg voiceValue,alarmValue,impulseValue,backgroundValue,vocalisationValue
  voice=voiceValue+0; alarm=alarmValue+0; impulse=impulseValue+0; background=backgroundValue+0; vocalisation=vocalisationValue+0
::method voice; expose voice; return voice
::method alarm; expose alarm; return alarm
::method impulse; expose impulse; return impulse
::method background; expose background; return background
::method vocalisation; expose vocalisation; return vocalisation
::method strongest
  expose voice alarm impulse background vocalisation
  label='VOICE_LIKE'; best=voice
  if alarm>best then do; best=alarm; label='ALARM_LIKE'; end
  if impulse>best then do; best=impulse; label='IMPACT_LIKE'; end
  if background>best then do; best=background; label='BACKGROUND_LIKE'; end
  if vocalisation>best then do; best=vocalisation; label='VOCALISATION_LIKE'; end
  return label
::method canonicalText
  return 'AUDIO_V9_SOURCE_FAMILY_EVIDENCE/1|voice='||self~voice||'|alarm='||self~alarm||'|impulse='||self~impulse||'|background='||self~background||'|vocalisation='||self~vocalisation||'|strongest='||self~strongest

/* These are deliberately conservative priors, not final class labels. */
::class AudioV9SourceFamilyScorer public
::method score
  use strict arg track
  motion=track~meanResidualMotion; turn=track~meanTurn; active=track~meanActive; coh=track~meanCoherence; crest=track~meanCrest; duration=track~durationMs
  voice=self~clip((motion/3+turn/4+active+coh)/4)
  impulse=self~clip((crest-5)/10)
  background=self~clip(1-(motion/2+turn/3+active)/3)
  alarm=self~clip((1-self~clip(motion/4))*.35 + (1-self~clip(turn/5))*.35 + self~clip(duration/8000)*.30)
  /* Cat/human separation is not guessed here. Vocalisation means structured nonstationary acoustic source. */
  vocal=self~clip((self~clip(motion/4)+self~clip(turn/6)+active)/3)
  return .AudioV9SourceFamilyEvidence~new(voice,alarm,impulse,background,vocal)
::method clip private
  use strict arg x
  if x<0 then return 0
  if x>1 then return 1
  return x

::class AudioV9SourceFamily public
::method init
  expose id tracks evidence label
  use strict arg idValue,sourceTracks,evidenceValue,labelValue='UNLABELLED'
  id=idValue~string; tracks=sourceTracks~copy; evidence=evidenceValue; label=labelValue~string~upper
::method id; expose id; return id
::method tracks; expose tracks; return tracks~copy
::method evidence; expose evidence; return evidence
::method label; expose label; return label
::method withLabel
  expose id tracks evidence
  use strict arg value
  return .AudioV9SourceFamily~new(id,tracks,evidence,value)
::method canonicalText
  expose tracks
  return 'AUDIO_V9_SOURCE_FAMILY/1|id='||self~id||'|tracks='||tracks~items||'|label='||self~label||'|'||self~evidence~canonicalText

::class AudioV9SourceFamilyClusterer public
::method init
  expose maxDominant maxTemporalDominant maxCenterDeltaHz temporalSchema closeSchema
  use strict arg maxDominantValue=28,maxTemporalDominantValue=120,maxCenterDeltaValue=750
  maxDominant=maxDominantValue+0; maxTemporalDominant=maxTemporalDominantValue+0; maxCenterDeltaHz=maxCenterDeltaValue+0
  temporalSchema=.MLCylindricalTemporalPatternSchema~new(.MLTemporalPatternPolicy~new(24,32,32,72,36,36,1,8,4,8,10,.true,.true,1),'AUDIO-V9-ACOUSTIC-TRACK-TEMPORAL/1')
  closeSchema=self~makeTrackSchema
::method cluster
  expose maxDominant maxTemporalDominant maxCenterDeltaHz closeSchema
  use strict arg tracks,maxComparisons=0
  if \tracks~isA(.Array) then raise syntax 88.900 array('source family clusterer requires Array')
  maxComparisons=maxComparisons+0
  if maxComparisons<0 then raise syntax 88.900 array('family comparison budget must be non-negative')
  comparisons=0
  ordered=tracks~copy; ordered~sortWith(.AudioV9TrackStartComparator~new)
  groups=.array~new; buckets=.directory~new; bucketHz=500
  do track over ordered
    tb=trunc(track~meanCenterHz/bucketHz); candidates=.array~new
    span=trunc(maxCenterDeltaHz/bucketHz)+1
    do bk=tb-span to tb+span
      key=bk~string
      if buckets~hasIndex(key) then do gi over buckets[key]; candidates~append(gi); end
    end
    best=0; bestScore=.nil
    do gi over candidates
      comparisons=comparisons+1
      if maxComparisons>0 then if comparisons>maxComparisons then raise syntax 88.900 array('CALIBRATION_COMPLEXITY_EXCEEDED','family_comparisons',comparisons,maxComparisons,ordered~items,groups~items)
      representative=groups[gi][1]
      if abs(representative~meanCenterHz-track~meanCenterHz)>maxCenterDeltaHz then iterate
      lh=representative~closeHash(closeSchema); rh=track~closeHash(closeSchema)
      if \self~hashWithinDominant(lh,rh,maxDominant) then iterate
      d=self~compareTracks(representative,track,.false)
      if d~at('compatible') then do
        if best=0 then do; best=gi; bestScore=d~at('score'); end
        else if d~at('score')<bestScore then do; best=gi; bestScore=d~at('score'); end
      end
    end
    if best=0 then do
      groups~append(.array~of(track)); gi=groups~items; key=tb~string
      if \buckets~hasIndex(key) then buckets[key]=.array~new
      buckets[key]~append(gi)
    end
    else groups[best]~append(track)
  end
  scorer=.AudioV9SourceFamilyScorer~new; out=.array~new
  do i=1 to groups~items
    sv=0;sa=0;si=0;sb=0;svo=0
    do t over groups[i]; e=scorer~score(t); sv=sv+e~voice; sa=sa+e~alarm; si=si+e~impulse; sb=sb+e~background; svo=svo+e~vocalisation; end
    n=groups[i]~items; ev=.AudioV9SourceFamilyEvidence~new(sv/n,sa/n,si/n,sb/n,svo/n)
    out~append(.AudioV9SourceFamily~new('FAMILY_'||right(i,4,'0'),groups[i],ev,'UNLABELLED'))
  end
  return out
::method compareTracks
  expose maxDominant maxTemporalDominant temporalSchema closeSchema
  use strict arg left,right,useTemporal=.true
  lh=left~closeHash(closeSchema); rh=right~closeHash(closeSchema); md=closeSchema~difference(lh,rh)
  outcome=.directory~new; outcome~put(md~dominantDelta,'meanDominant'); outcome~put(md~score,'meanScore'); outcome~put(0,'temporalDominant'); outcome~put(0,'temporalTotal')
  compatible=(md~dominantDelta<=maxDominant)
  if useTemporal then do
    lt=left~temporalHash(temporalSchema); rt=right~temporalHash(temporalSchema)
    if lt\==.nil then do
      if rt\==.nil then do
        td=temporalSchema~difference(lt,rt); outcome~put(td~dominantDelta,'temporalDominant'); outcome~put(td~totalDelta,'temporalTotal')
        if td~dominantDelta>maxTemporalDominant then compatible=.false
      end
    end
  end
  outcome~put(compatible,'compatible')
  /* significance-ordered mean score dominates; temporal total breaks close ties without hiding a large mean disagreement */
  outcome~put(md~score*1000000+outcome~at('temporalTotal'),'score')
  return outcome
::method hashWithinDominant private
  expose closeSchema
  use strict arg leftHash,rightHash,limit
  do i=1 to closeSchema~featureCount
    dim=closeSchema~dimension(i)
    if abs((leftHash~coordinate(i)+0)-(rightHash~coordinate(i)+0))*dim~importance>limit then return .false
  end
  return .true
::method trackSchema
  expose closeSchema
  return closeSchema
::method makeTrackSchema private
  dims=.array~new
  dims~append(.MLCloseHashDimension~new('motion',0,20,128,5,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('turn',0,30,128,5,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('active',0,1,128,5,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('width',0,40,96,2,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('coherence',0,1,128,6,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('crest',0,30,96,3,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('lag_abs',0,500,128,3,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('ab_ratio',-40,40,128,3,'CLAMP'))
  dims~append(.MLCloseHashDimension~new('center_hz',0,4000,128,2,'CLAMP'))
  return .MLCloseHashSchema~new(dims,'AUDIO-V9-SOURCE-FAMILY/2')

::class AudioV9TrackStartComparator private
::method compare
  use strict arg a,b
  if a~startMs<b~startMs then return -1
  if a~startMs>b~startMs then return 1
  if a~id<b~id then return -1
  if a~id>b~id then return 1
  return 0

/* Prototype labels are externally grounded names attached to acoustic families.
 * Clustering stays unsupervised; one confirmed exemplar can label every compatible appearance. */
::class AudioV9SourcePrototype public
::method init
  expose id label family provenance
  use strict arg idValue,labelValue,familyValue,provenanceValue='UNSPECIFIED'
  if \familyValue~isA(.AudioV9SourceFamily) then raise syntax 88.900 array('source prototype requires AudioV9SourceFamily')
  id=idValue~string; label=labelValue~string~upper; family=familyValue; provenance=provenanceValue~string
  if id='' | label='' then raise syntax 88.900 array('source prototype id/label may not be empty')
::method id; expose id; return id
::method label; expose label; return label
::method family; expose family; return family
::method provenance; expose provenance; return provenance

::class AudioV9PrototypeMatch public
::method init
  expose prototypeId label compatible score meanDominant temporalDominant provenance
  use strict arg prototypeIdValue,labelValue,compatibleValue,scoreValue,meanValue,temporalValue,provenanceValue
  prototypeId=prototypeIdValue~string; label=labelValue~string; compatible=(compatibleValue=.true); score=scoreValue+0; meanDominant=meanValue+0; temporalDominant=temporalValue+0; provenance=provenanceValue~string
::method prototypeId; expose prototypeId; return prototypeId
::method label; expose label; return label
::method compatible; expose compatible; return compatible
::method score; expose score; return score
::method meanDominant; expose meanDominant; return meanDominant
::method temporalDominant; expose temporalDominant; return temporalDominant
::method provenance; expose provenance; return provenance
::method canonicalText
  return 'AUDIO_V9_PROTOTYPE_MATCH/1|prototype='||self~prototypeId||'|label='||self~label||'|compatible='||self~compatible||'|score='||self~score||'|meanDominant='||self~meanDominant||'|temporalDominant='||self~temporalDominant||'|provenance='||self~provenance

::class AudioV9PrototypeMatchComparator private
::method compare
  use strict arg a,b
  if a~compatible & \b~compatible then return -1
  if b~compatible & \a~compatible then return 1
  if a~score<b~score then return -1
  if a~score>b~score then return 1
  if a~prototypeId<b~prototypeId then return -1
  if a~prototypeId>b~prototypeId then return 1
  return 0

::class AudioV9SourcePrototypeClassifier public
::method init
  expose comparer
  use strict arg comparerValue=.nil
  if comparerValue==.nil then comparer=.AudioV9SourceFamilyClusterer~new(22,90); else comparer=comparerValue
::method matches
  expose comparer
  use strict arg family,prototypes
  if \family~isA(.AudioV9SourceFamily) then raise syntax 88.900 array('prototype classifier requires source family')
  if \prototypes~isA(.Array) then raise syntax 88.900 array('prototype classifier requires prototype Array')
  ft=family~tracks; if ft~items<1 then raise syntax 88.900 array('source family has no tracks')
  out=.array~new
  do p over prototypes
    if \p~isA(.AudioV9SourcePrototype) then raise syntax 88.900 array('prototype Array contains wrong object')
    pt=p~family~tracks; if pt~items<1 then iterate
    d=comparer~compareTracks(ft[1],pt[1])
    out~append(.AudioV9PrototypeMatch~new(p~id,p~label,d~at('compatible'),d~at('score'),d~at('meanDominant'),d~at('temporalDominant'),p~provenance))
  end
  out~sortWith(.AudioV9PrototypeMatchComparator~new)
  return out
::method bestMatch
  use strict arg family,prototypes
  m=self~matches(family,prototypes)
  if m~items<1 then return .nil
  if \m[1]~compatible then return .nil
  return m[1]
::method classify
  use strict arg family,prototypes
  best=self~bestMatch(family,prototypes)
  if best==.nil then return family
  return family~withLabel(best~label)

/* Anonymous diarisation only.  A real-world person label requires external provenance. */
::class AudioV9AnonymousSpeakerCluster public
::method init
  expose id families
  use strict arg idValue,sourceFamilies
  id=idValue~string; families=sourceFamilies~copy
::method id; expose id; return id
::method families; expose families; return families~copy
::method canonicalText; expose families; return 'AUDIO_V9_ANONYMOUS_SPEAKER/1|id='||self~id||'|families='||families~items

::class AudioV9AnonymousDiarizer public
::method init
  expose familyComparer
  use strict arg familyComparerValue=.nil
  if familyComparerValue==.nil then familyComparer=.AudioV9SourceFamilyClusterer~new(22,90,1400); else familyComparer=familyComparerValue
::method cluster
  expose familyComparer
  use strict arg families,voiceThreshold=.45
  selected=.array~new
  do f over families
    blocked=.false
    label=f~label~upper
    if label='ALARM' | label='CAT' | label='CAMERA_PLAYBACK' | label='IMPACT' | label='BACKGROUND' then blocked=.true
    if \blocked then do
      if f~evidence~voice>=voiceThreshold then selected~append(f)
    end
  end
  groups=.array~new
  do f over selected
    ft=f~tracks; if ft~items<1 then iterate
    best=0; bestScore=.nil
    do g=1 to groups~items
      repFamily=groups[g][1]; rt=repFamily~tracks
      d=familyComparer~compareTracks(rt[1],ft[1])
      if d~at('compatible') then do
        if best=0 then do; best=g; bestScore=d~at('score'); end
        else if d~at('score')<bestScore then do; best=g; bestScore=d~at('score'); end
      end
    end
    if best=0 then groups~append(.array~of(f)); else groups[best]~append(f)
  end
  out=.array~new
  do i=1 to groups~items
    out~append(.AudioV9AnonymousSpeakerCluster~new('SPEAKER_'||right(i,4,'0'),groups[i]))
  end
  return out

::class AudioV9AcousticAnalysis public
::method init
  expose characters tracks families speakers
  use strict arg characterValues,trackValues,familyValues,speakerValues
  characters=characterValues~copy; tracks=trackValues~copy; families=familyValues~copy; speakers=speakerValues~copy
::method characters; expose characters; return characters~copy
::method tracks; expose tracks; return tracks~copy
::method families; expose families; return families~copy
::method speakers; expose speakers; return speakers~copy
::method write
  expose characters tracks families speakers
  use strict arg prefix
  cf=prefix||'.characters.tsv'; tf=prefix||'.tracks.tsv'; tmf=prefix||'.track_members.tsv'; ff=prefix||'.families.tsv'; af=prefix||'.appearances.tsv'; sf=prefix||'.speakers.tsv'
  call stream cf,'C','OPEN WRITE REPLACE'; call lineout cf,'id'||'09'x||'start_ms'||'09'x||'end_ms'||'09'x||'feed'||'09'x||'band'||'09'x||'center_hz'||'09'x||'motion'||'09'x||'turn'||'09'x||'active'||'09'x||'coherence'||'09'x||'ratio_db'||'09'x||'crest'||'09'x||'lag_abs_ms'
  do c over characters; call lineout cf,c~id||'09'x||c~absoluteStartMs||'09'x||c~absoluteEndMs||'09'x||c~feed||'09'x||c~bandIndex||'09'x||c~centerHz||'09'x||c~residualMotionDb||'09'x||c~turnDb||'09'x||c~activeFraction||'09'x||c~spatialCoherence||'09'x||c~ratioDb||'09'x||c~crest||'09'x||c~lagAbsMs; end; call stream cf,'C','CLOSE'
  call stream tf,'C','OPEN WRITE REPLACE'; call lineout tf,'track_id'||'09'x||'feed'||'09'x||'start_ms'||'09'x||'end_ms'||'09'x||'members'||'09'x||'motion'||'09'x||'turn'||'09'x||'active'||'09'x||'width'||'09'x||'coherence'||'09'x||'crest'||'09'x||'lag_abs_ms'||'09'x||'ratio_db'||'09'x||'center_hz'
  do t over tracks; call lineout tf,t~id||'09'x||t~feed||'09'x||t~startMs||'09'x||t~endMs||'09'x||t~items||'09'x||t~meanResidualMotion||'09'x||t~meanTurn||'09'x||t~meanActive||'09'x||t~meanWidth||'09'x||t~meanCoherence||'09'x||t~meanCrest||'09'x||t~meanLagAbs||'09'x||t~meanRatioDb||'09'x||t~meanCenterHz; end; call stream tf,'C','CLOSE'
  call stream tmf,'C','OPEN WRITE REPLACE'; call lineout tmf,'track_id'||'09'x||'character_id'||'09'x||'start_ms'||'09'x||'end_ms'||'09'x||'feed'||'09'x||'band'
  do t over tracks; do c over t~members; call lineout tmf,t~id||'09'x||c~id||'09'x||c~absoluteStartMs||'09'x||c~absoluteEndMs||'09'x||c~feed||'09'x||c~bandIndex; end; end; call stream tmf,'C','CLOSE'
  call stream ff,'C','OPEN WRITE REPLACE'; call lineout ff,'family_id'||'09'x||'label'||'09'x||'tracks'||'09'x||'voice'||'09'x||'alarm'||'09'x||'impact'||'09'x||'background'||'09'x||'vocalisation'||'09'x||'strongest'
  do f over families; e=f~evidence; call lineout ff,f~id||'09'x||f~label||'09'x||f~tracks~items||'09'x||e~voice||'09'x||e~alarm||'09'x||e~impulse||'09'x||e~background||'09'x||e~vocalisation||'09'x||e~strongest; end; call stream ff,'C','CLOSE'
  call stream af,'C','OPEN WRITE REPLACE'; call lineout af,'family_id'||'09'x||'track_id'||'09'x||'start_ms'||'09'x||'end_ms'||'09'x||'members'
  do f over families; do t over f~tracks; call lineout af,f~id||'09'x||t~id||'09'x||t~startMs||'09'x||t~endMs||'09'x||t~items; end; end; call stream af,'C','CLOSE'
  call stream sf,'C','OPEN WRITE REPLACE'; call lineout sf,'speaker_id'||'09'x||'family_id'
  do sp over speakers; do f over sp~families; call lineout sf,sp~id||'09'x||f~id; end; end; call stream sf,'C','CLOSE'
  return .array~of(cf,tf,tmf,ff,af,sf)

::class AudioV9AcousticAnalyzer public
::method init
  expose assembler trackBuilder familyClusterer diarizer
  assembler=.AudioV9AcousticCharacterAssembler~new(4000)
  trackBuilder=.AudioV9TrackBuilder~new(.AudioV9AcousticCharacterSchema~new,750,1,36)
  familyClusterer=.AudioV9SourceFamilyClusterer~new(28,120)
  diarizer=.AudioV9AnonymousDiarizer~new(.AudioV9SourceFamilyClusterer~new(22,90,1400))
::method analyze
  expose assembler trackBuilder familyClusterer diarizer
  use strict arg fcBoxes,fdBoxes,scan,absoluteChunkStartMs,prototypes=.nil,doDiarize=.false
  fc=assembler~assemble(fcBoxes,scan,absoluteChunkStartMs,'FC'); fd=assembler~assemble(fdBoxes,scan,absoluteChunkStartMs,'FD')
  chars=.array~new; do x over fc; chars~append(x); end; do x over fd; chars~append(x); end
  tracks=trackBuilder~build(chars); families=familyClusterer~cluster(tracks)
  if prototypes\==.nil then do
    classifier=.AudioV9SourcePrototypeClassifier~new(familyClusterer); labelled=.array~new
    do f over families; labelled~append(classifier~classify(f,prototypes)); end
    families=labelled
  end
  speakers=.array~new
  if doDiarize then speakers=diarizer~cluster(families,.45)
  return .AudioV9AcousticAnalysis~new(chars,tracks,families,speakers)

::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'AudioV9SpectralField.cls'
::requires 'MLCloseNeighbour.cls'
::requires 'MLTemporalPatternHash.cls'
