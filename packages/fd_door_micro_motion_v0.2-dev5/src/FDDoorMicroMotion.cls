/*
 * FDDoorMicroMotion.cls
 * v0.2-dev5 — standard-starter-owned, multi-file wall-clock-windowed, night-vision capable, relocation-aware, checkpointable
 * FD / F11 door micro-motion analyser.
 *
 * Evidence boundary:
 * - visual only; no audio inputs or audio-derived timing;
 * - decoded video PTS relative to the first decoded frame is analysis time;
 * - camera/scene relocation suspends micro-motion authority until the door is
 *   re-acquired and stable;
 * - displacement is pixels/sub-pixels only;
 * - explicit user exclusion windows are decoded but not analysed.
 */

::class FDDoorMicroMotionVersion public
::constant VERSION '0.2-dev5'
::constant API 'fd.door.micro.motion/0.2'
::constant MIGRATION_API 'migratable.job/0.2'
::constant SAMPLE_SCHEMA 'FD_DOOR_MICRO_SAMPLE_V3'
::constant EVENT_SCHEMA 'FD_VISUAL_MECHANICAL_EVENT_V3'
::constant EPOCH_SCHEMA 'FD_CAMERA_GEOMETRY_EPOCH_V2'
::constant RUN_SCHEMA 'FD_DOOR_MICRO_RUN_V4'
::constant RELOCATION_SCHEMA 'FD_CAMERA_RELOCATION_V2'
::constant EXCLUSION_SCHEMA 'FD_ANALYSIS_EXCLUSION_V1'
::constant CHECKPOINT_SCHEMA 'FD_MIGRATION_CHECKPOINT_V1'
::constant PART_SCHEMA 'FD_OUTPUT_PART_V1'
::constant BUNDLE_SCHEMA 'FD_MIGRATION_BUNDLE_V1'


::class FDAnalysisExclusion public
::attribute id get
::attribute startMs get
::attribute endMs get
::attribute reason get
::method init
  expose id startMs endMs reason
  use strict arg idArg,startArg,endArg,reasonArg='USER_DECLARED_EXCLUSION'
  id=idArg~string; startMs=startArg+0; endMs=endArg+0; reason=reasonArg~string
  if id='' | startMs<0 | endMs<=startMs then raise syntax 88.900 array('invalid FD analysis exclusion')
::method contains
  expose startMs endMs
  use strict arg ms
  return ms>=startMs & ms<endMs
::method canonical
  expose id startMs endMs reason
  return id||':'||startMs||':'||endMs||':'||reason


/* Camera wall-clock arithmetic is deliberately timezone-free.  The burned-in
 * camera clock is the authority; we only need exact differences between local
 * calendar timestamps spanning a small number of days. */
::class FDWallClock public
::method parse class
  use strict arg text
  s=text~strip
  if s='' then raise syntax 88.900 array('empty FD wall-clock timestamp')
  s=s~changestr('T',' ')
  parse var s datePart ' ' timePart
  parse var datePart y '-' mo '-' d
  parse var timePart hh ':' mm ':' secPart
  if y='' | mo='' | d='' | hh='' | mm='' | secPart='' then raise syntax 88.900 array('invalid FD wall-clock timestamp',text)
  dot=secPart~pos('.')
  if dot>0 then do
    ss=secPart~substr(1,dot-1)
    frac=secPart~substr(dot+1)
  end
  else do; ss=secPart; frac=''; end
  if frac='' then ms=0
  else do
    digits=frac
    if digits~length<3 then digits=digits||copies('0',3-digits~length)
    if digits~length>3 then digits=digits~substr(1,3)
    ms=digits+0
  end
  y=y+0; mo=mo+0; d=d+0; hh=hh+0; mm=mm+0; ss=ss+0
  if mo<1 | mo>12 | d<1 | d>31 | hh<0 | hh>23 | mm<0 | mm>59 | ss<0 | ss>59 | ms<0 | ms>999 then raise syntax 88.900 array('invalid FD wall-clock timestamp',text)
  ord=self~dayOrdinal(y,mo,d)
  parts=.directory~new
  parts['DAY']=ord
  parts['TOD_MS']=(((hh*60)+mm)*60+ss)*1000+ms
  parts['TEXT']=self~canonical(y,mo,d,hh,mm,ss,ms)
  return parts

::method dayOrdinal class
  use strict arg y,mo,d
  y=y+0; mo=mo+0; d=d+0
  y1=y-1
  days=365*y1 + (y1%4) - (y1%100) + (y1%400)
  mdays=.array~of(31,28,31,30,31,30,31,31,30,31,30,31)
  leap=((y//4)=0 & ((y//100)<>0 | (y//400)=0))
  if leap then mdays[2]=29
  maxd=mdays[mo]
  if d>maxd then raise syntax 88.900 array('invalid FD wall-clock calendar date',y,mo,d)
  do i=1 to mo-1; days+=mdays[i]; end
  return days+d-1

::method canonical class
  use strict arg y,mo,d,hh,mm,ss,ms=0
  return right(y,4,'0')||'-'||right(mo,2,'0')||'-'||right(d,2,'0')||'T'||right(hh,2,'0')||':'||right(mm,2,'0')||':'||right(ss,2,'0')||'.'||right(ms,3,'0')

::method differenceMs class
  use strict arg originText,targetText
  a=self~parse(originText); b=self~parse(targetText)
  dayDiff=(b['DAY']-a['DAY'])
  return (dayDiff*86400000)+(b['TOD_MS']-a['TOD_MS'])


::class FDDoorMicroMotionConfig public
::attribute sampleEveryFrames
::attribute relocationPixels
::attribute relocationStableFrames
::attribute trackingSearchPixels
::attribute minimumEdgeScore
::attribute calibrationFrames
::attribute minimumGlobalStepPixels
::attribute minimumDoorResidualPixels
::attribute sigmaMultiplier
::attribute eventGapMs
::attribute maximumFrames
::attribute referenceMediaMs
::attribute bootstrapFrameXLo
::attribute bootstrapFrameXHi
::attribute fullSearchXLo
::attribute fullSearchXHi
::attribute fingerprintGapTolerance
::attribute fingerprintScaleTolerance
::attribute fingerprintTopEdges
::attribute locatorMinimumScore
::attribute locatorValidationFrames
::attribute locatorAppearanceMinRatio
::attribute locatorAppearanceMaxRatio
::attribute decoderPrerollMs
::attribute controlPollFrames
::attribute analysisStartMs
::attribute analysisEndMs
::attribute wallClockOrigin
::attribute analysisWallStart
::attribute analysisWallEnd
::attribute exclusions get

::method init
  expose sampleEveryFrames relocationPixels relocationStableFrames trackingSearchPixels minimumEdgeScore calibrationFrames minimumGlobalStepPixels minimumDoorResidualPixels sigmaMultiplier eventGapMs maximumFrames referenceMediaMs bootstrapFrameXLo bootstrapFrameXHi fullSearchXLo fullSearchXHi fingerprintGapTolerance fingerprintScaleTolerance fingerprintTopEdges locatorMinimumScore locatorValidationFrames locatorAppearanceMinRatio locatorAppearanceMaxRatio decoderPrerollMs controlPollFrames analysisStartMs analysisEndMs wallClockOrigin analysisWallStart analysisWallEnd exclusions
  sampleEveryFrames=1
  relocationPixels=12.0
  relocationStableFrames=5
  trackingSearchPixels=6
  minimumEdgeScore=1.5
  calibrationFrames=120
  minimumGlobalStepPixels=0.10
  minimumDoorResidualPixels=0.12
  sigmaMultiplier=5.0
  eventGapMs=240
  maximumFrames=0
  referenceMediaMs=0
  bootstrapFrameXLo=0.24
  bootstrapFrameXHi=0.39
  fullSearchXLo=0.03
  fullSearchXHi=0.94
  fingerprintGapTolerance=0.28
  fingerprintScaleTolerance=0.20
  fingerprintTopEdges=18
  locatorMinimumScore=5.0
  locatorValidationFrames=0
  locatorAppearanceMinRatio=0.58
  locatorAppearanceMaxRatio=2.20
  decoderPrerollMs=2500
  controlPollFrames=30
  analysisStartMs=0
  analysisEndMs=-1
  wallClockOrigin=''
  analysisWallStart=''
  analysisWallEnd=''
  exclusions=.array~new


::method setWallWindow
  expose analysisStartMs analysisEndMs wallClockOrigin analysisWallStart analysisWallEnd
  use strict arg originText,startText,endText
  origin=.FDWallClock~parse(originText); start=.FDWallClock~parse(startText); finish=.FDWallClock~parse(endText)
  rawStart=.FDWallClock~differenceMs(origin['TEXT'],start['TEXT'])
  rawEnd=.FDWallClock~differenceMs(origin['TEXT'],finish['TEXT'])
  if rawEnd<=0 then raise syntax 88.900 array('FD analysis wall window ends before source origin',originText,startText,endText)
  if rawEnd<=rawStart then raise syntax 88.900 array('FD analysis wall window is empty',startText,endText)
  analysisStartMs=rawStart
  if analysisStartMs<0 then analysisStartMs=0
  analysisEndMs=rawEnd
  wallClockOrigin=origin['TEXT']; analysisWallStart=start['TEXT']; analysisWallEnd=finish['TEXT']
  return self

::method addWallExclusion
  expose wallClockOrigin
  use strict arg id,startText,endText,reason='USER_DECLARED_SCENE_OCCLUSION'
  if wallClockOrigin='' then raise syntax 88.900 array('setWallWindow must precede addWallExclusion')
  rawStart=.FDWallClock~differenceMs(wallClockOrigin,startText)
  rawEnd=.FDWallClock~differenceMs(wallClockOrigin,endText)
  if rawEnd<=rawStart then raise syntax 88.900 array('FD wall exclusion is empty',startText,endText)
  if rawEnd<=0 then return .nil
  if rawStart<0 then rawStart=0
  return self~addExclusion(.FDAnalysisExclusion~new(id,rawStart,rawEnd,reason))

::method addExclusion
  expose exclusions
  use strict arg exclusion
  if exclusion==.nil | \exclusion~isA(.FDAnalysisExclusion) then raise syntax 88.900 array('FDAnalysisExclusion required')
  exclusions~append(exclusion)
  return exclusion

::method exclusionAt
  expose exclusions
  use strict arg ms
  do e over exclusions
    if e~contains(ms) then return e
  end
  return .nil

::method compactText
  expose sampleEveryFrames relocationPixels relocationStableFrames trackingSearchPixels minimumEdgeScore calibrationFrames minimumGlobalStepPixels minimumDoorResidualPixels sigmaMultiplier eventGapMs maximumFrames referenceMediaMs bootstrapFrameXLo bootstrapFrameXHi fullSearchXLo fullSearchXHi fingerprintGapTolerance fingerprintScaleTolerance fingerprintTopEdges locatorMinimumScore locatorValidationFrames locatorAppearanceMinRatio locatorAppearanceMaxRatio decoderPrerollMs controlPollFrames analysisStartMs analysisEndMs wallClockOrigin analysisWallStart analysisWallEnd exclusions
  x='FDDMM4|STEP='||sampleEveryFrames||'|RELOC='||relocationPixels||'|STABLE='||relocationStableFrames||'|TRACK='||trackingSearchPixels||'|EDGE='||minimumEdgeScore||'|CAL='||calibrationFrames||'|GMIN='||minimumGlobalStepPixels||'|DMIN='||minimumDoorResidualPixels||'|SIG='||sigmaMultiplier||'|GAP='||eventGapMs||'|MAX='||maximumFrames||'|REFMS='||referenceMediaMs||'|BOOT='||bootstrapFrameXLo||','||bootstrapFrameXHi||'|SEARCH='||fullSearchXLo||','||fullSearchXHi||'|GAPTOL='||fingerprintGapTolerance||'|SCALETOL='||fingerprintScaleTolerance||'|TOP='||fingerprintTopEdges||'|LOCSCORE='||locatorMinimumScore||'|LOCVALID='||locatorValidationFrames||'|APPMIN='||locatorAppearanceMinRatio||'|APPMAX='||locatorAppearanceMaxRatio||'|PREROLL='||decoderPrerollMs||'|POLL='||controlPollFrames||'|ASTART='||analysisStartMs||'|AEND='||analysisEndMs||'|WORIGIN='||wallClockOrigin||'|WSTART='||analysisWallStart||'|WEND='||analysisWallEnd
  do e over exclusions; x=x||'|EX='||e~canonical; end
  return x

::method nightF11 class
  c=self~new
  /* Generic FD night-IR profile.  The first usable frame in the requested
     analysis window may establish the fingerprint; after that, relocation
     reacquisition uses the retained F11 fingerprint. */
  c~referenceMediaMs=-1
  c~bootstrapFrameXLo=0.18
  c~bootstrapFrameXHi=0.50
  c~fullSearchXLo=0.02
  c~fullSearchXHi=0.66
  return c

::method tp00000Night class
  /* Compatibility profile for the original single-file qualification.  It no
     longer carries a hard-coded exclusion; exclusions are job/window data. */
  c=self~nightF11
  c~referenceMediaMs=5575000
  c~bootstrapFrameXLo=0.25
  c~bootstrapFrameXHi=0.38
  return c

::method fromCompactText class
  use strict arg text
  c=self~new
  rest=text~string
  parse var rest marker '|' rest
  if marker<>'FDDMM4' then raise syntax 88.900 array('unsupported FD compact config',marker)
  do while rest<>''
    parse var rest token '|' rest
    if token='' then iterate
    eq=token~pos('='); if eq=0 then iterate
    key=token~substr(1,eq-1); value=token~substr(eq+1)
    select
      when key='STEP' then c~sampleEveryFrames=value+0
      when key='RELOC' then c~relocationPixels=value+0
      when key='STABLE' then c~relocationStableFrames=value+0
      when key='TRACK' then c~trackingSearchPixels=value+0
      when key='EDGE' then c~minimumEdgeScore=value+0
      when key='CAL' then c~calibrationFrames=value+0
      when key='GMIN' then c~minimumGlobalStepPixels=value+0
      when key='DMIN' then c~minimumDoorResidualPixels=value+0
      when key='SIG' then c~sigmaMultiplier=value+0
      when key='GAP' then c~eventGapMs=value+0
      when key='MAX' then c~maximumFrames=value+0
      when key='REFMS' then c~referenceMediaMs=value+0
      when key='BOOT' then do; parse var value a ',' b; c~bootstrapFrameXLo=a+0; c~bootstrapFrameXHi=b+0; end
      when key='SEARCH' then do; parse var value a ',' b; c~fullSearchXLo=a+0; c~fullSearchXHi=b+0; end
      when key='GAPTOL' then c~fingerprintGapTolerance=value+0
      when key='SCALETOL' then c~fingerprintScaleTolerance=value+0
      when key='TOP' then c~fingerprintTopEdges=value+0
      when key='LOCSCORE' then c~locatorMinimumScore=value+0
      when key='LOCVALID' then c~locatorValidationFrames=value+0
      when key='APPMIN' then c~locatorAppearanceMinRatio=value+0
      when key='APPMAX' then c~locatorAppearanceMaxRatio=value+0
      when key='PREROLL' then c~decoderPrerollMs=value+0
      when key='POLL' then c~controlPollFrames=value+0
      when key='ASTART' then c~analysisStartMs=value+0
      when key='AEND' then c~analysisEndMs=value+0
      when key='WORIGIN' then c~wallClockOrigin=value
      when key='WSTART' then c~analysisWallStart=value
      when key='WEND' then c~analysisWallEnd=value
      when key='EX' then do
        parse var value xid ':' xs ':' xe ':' why
        c~addExclusion(.FDAnalysisExclusion~new(xid,xs+0,xe+0,why))
      end
      otherwise nop
    end
  end
  return c


::class FDEdgeMeasurement public
::attribute position get
::attribute score get
::attribute signedScore get
::attribute valid get
::method init
  expose position score signedScore valid
  use strict arg p,s,ss,v
  position=p+0; score=s+0; signedScore=ss+0; valid=(v==.true)


::class FDDoorFingerprint public
::attribute panelX get
::attribute doorX get
::attribute frameX get
::attribute panelDoorGap get
::attribute doorFrameGap get
::attribute panelSign get
::attribute doorSign get
::attribute frameSign get
::attribute referenceWidth get
::attribute score get
::attribute appearanceContrast get
::method init
  expose panelX doorX frameX panelDoorGap doorFrameGap panelSign doorSign frameSign referenceWidth score appearanceContrast
  use strict arg p,d,f,ps,ds,fs,w,scoreArg,appearanceArg=0
  panelX=p+0; doorX=d+0; frameX=f+0
  panelDoorGap=doorX-panelX; doorFrameGap=frameX-doorX
  panelSign=ps+0; doorSign=ds+0; frameSign=fs+0; referenceWidth=w+0; score=scoreArg+0; appearanceContrast=appearanceArg+0
  if panelDoorGap<=0 | doorFrameGap<=0 | referenceWidth<=0 then raise syntax 88.900 array('invalid door fingerprint')
::method canonical
  expose panelX doorX frameX panelDoorGap doorFrameGap panelSign doorSign frameSign referenceWidth score appearanceContrast
  return panelX||','||doorX||','||frameX||','||panelDoorGap||','||doorFrameGap||','||panelSign||','||doorSign||','||frameSign||','||referenceWidth||','||score||','||appearanceContrast


::class FDDoorAnchor public
::attribute panelX get
::attribute doorX get
::attribute frameX get
::attribute scale get
::attribute score get
::method init
  expose panelX doorX frameX scale score
  use strict arg p,d,f,s,sc
  panelX=p+0; doorX=d+0; frameX=f+0; scale=s+0; score=sc+0


::class FDMicroSample public
::attribute sampleIndex get
::attribute timeMs get
::attribute pts get
::attribute epochId get
::attribute geometryState get
::attribute frameUpperX get
::attribute frameLowerX get
::attribute doorUpperX get
::attribute doorLowerX get
::attribute floorLeftY get
::attribute floorRightY get
::attribute globalDxStep get
::attribute globalDyStep get
::attribute doorUpperResidualStep get
::attribute doorLowerResidualStep get
::attribute globalMagnitude get
::attribute doorMagnitude get
::attribute globalThreshold get
::attribute doorThreshold get
::attribute coherentGlobalX get
::attribute coherentGlobalY get
::attribute coherentDoor get
::attribute globalCandidate get
::attribute doorCandidate get
::attribute combinedCandidate get
::attribute probeAgreement get
::attribute locatorScore get
::attribute frameUpperScore get
::attribute frameLowerScore get
::attribute doorUpperScore get
::attribute doorLowerScore get

::method init
  expose sampleIndex timeMs pts epochId geometryState frameUpperX frameLowerX doorUpperX doorLowerX floorLeftY floorRightY globalDxStep globalDyStep doorUpperResidualStep doorLowerResidualStep globalMagnitude doorMagnitude globalThreshold doorThreshold coherentGlobalX coherentGlobalY coherentDoor globalCandidate doorCandidate combinedCandidate probeAgreement locatorScore frameUpperScore frameLowerScore doorUpperScore doorLowerScore
  use strict arg idx,ms,p,eid,state,fu,fl,du,dl,fyl,fyr,gdx,gdy,dur,dlr,gmag,dmag,gth,dth,cgx,cgy,cd,gc,dc,cc,agree,lscore,fus,fls,dus,dls
  sampleIndex=idx+0; timeMs=ms+0; pts=p+0; epochId=eid~string; geometryState=state~string
  frameUpperX=fu+0; frameLowerX=fl+0; doorUpperX=du+0; doorLowerX=dl+0; floorLeftY=fyl+0; floorRightY=fyr+0
  globalDxStep=gdx+0; globalDyStep=gdy+0; doorUpperResidualStep=dur+0; doorLowerResidualStep=dlr+0
  globalMagnitude=gmag+0; doorMagnitude=dmag+0; globalThreshold=gth+0; doorThreshold=dth+0
  coherentGlobalX=(cgx==.true); coherentGlobalY=(cgy==.true); coherentDoor=(cd==.true)
  globalCandidate=(gc==.true); doorCandidate=(dc==.true); combinedCandidate=(cc==.true); probeAgreement=agree+0
  locatorScore=lscore+0; frameUpperScore=fus+0; frameLowerScore=fls+0; doorUpperScore=dus+0; doorLowerScore=dls+0


::class FDGeometryEpoch public
::attribute id get
::attribute startMs get
::attribute endMs
::attribute pose get
::attribute stableSamples
::attribute panelAnchorX get
::attribute doorAnchorX get
::attribute frameAnchorX get
::attribute locatorScore get
::method init
  expose id startMs endMs pose stableSamples panelAnchorX doorAnchorX frameAnchorX locatorScore
  use strict arg eid,start,poseName,p,d,f,score
  id=eid~string; startMs=start+0; endMs=start+0; pose=poseName~string; stableSamples=0
  panelAnchorX=p+0; doorAnchorX=d+0; frameAnchorX=f+0; locatorScore=score+0
::method touch
  expose endMs stableSamples
  use strict arg ms
  endMs=ms+0; stableSamples+=1


::class FDCameraRelocation public
::attribute id get
::attribute startMs get
::attribute endMs
::attribute reason get
::attribute fromEpoch get
::attribute toEpoch
::method init
  expose id startMs endMs reason fromEpoch toEpoch
  use strict arg rid,start,why,fromId=''
  id=rid~string; startMs=start+0; endMs=start+0; reason=why~string; fromEpoch=fromId~string; toEpoch=''
::method close
  expose endMs toEpoch
  use strict arg ms,toId=''
  endMs=ms+0; toEpoch=toId~string
::method durationMs
  expose startMs endMs
  return endMs-startMs


::class FDExclusionEvidence public
::attribute id get
::attribute startMs get
::attribute endMs
::attribute reason get
::attribute skippedFrames
::method init
  expose id startMs endMs reason skippedFrames
  use strict arg eid,start,why
  id=eid~string; startMs=start+0; endMs=start+0; reason=why~string; skippedFrames=0
::method noteFrame
  expose endMs skippedFrames
  use strict arg ms
  endMs=ms+0; skippedFrames+=1
::method durationMs
  expose startMs endMs
  return endMs-startMs


::class FDMechanicalEvent public
::attribute id get
::attribute classification get
::attribute startMs get
::attribute peakMs get
::attribute endMs get
::attribute confidence get
::attribute epochId get
::attribute peakGlobalPixels get
::attribute peakDoorPixels get
::attribute probeAgreement get
::attribute samples get
::method init
  expose id classification startMs peakMs endMs confidence epochId peakGlobalPixels peakDoorPixels probeAgreement samples
  use strict arg eid,className,startArg,peakArg,endArg,epochArg,pg,pd,agree,n
  id=eid~string; classification=className~string; startMs=startArg+0; peakMs=peakArg+0; endMs=endArg+0; epochId=epochArg~string
  peakGlobalPixels=pg+0; peakDoorPixels=pd+0; probeAgreement=agree+0; samples=n+0
  confidence=0.55
  if classification='FD_COMBINED_MECHANICAL_RESPONSE' then confidence=0.80
  else if classification='FD_DOOR_MICRO_DEFLECTION' then confidence=0.70
  else if classification='FD_GLOBAL_MICRO_VIBRATION' then confidence=0.65
  if probeAgreement>=3 then confidence+=0.10
  if confidence>1 then confidence=1
::method durationMs
  expose startMs endMs
  return endMs-startMs


::class FDNoiseModel public
::attribute count
::attribute globalMean
::attribute globalM2
::attribute doorMean
::attribute doorM2
::method init
  expose count globalMean globalM2 doorMean doorM2
  count=0; globalMean=0; globalM2=0; doorMean=0; doorM2=0
::method add
  expose count globalMean globalM2 doorMean doorM2
  use strict arg g,d
  count+=1
  delta=g-globalMean; globalMean=globalMean+(delta/count); globalM2=globalM2+delta*(g-globalMean)
  delta=d-doorMean; doorMean=doorMean+(delta/count); doorM2=doorM2+delta*(d-doorMean)
::method globalSigma
  expose count globalM2
  if count<2 then return 0
  return FDSqrt(globalM2/(count-1))
::method doorSigma
  expose count doorM2
  if count<2 then return 0
  return FDSqrt(doorM2/(count-1))


::class FDEventAccumulator public
::attribute active
::attribute currentClass
::attribute startMs
::attribute peakMs
::attribute endMs
::attribute epochId
::attribute peakGlobal
::attribute peakDoor
::attribute probeAgreement
::attribute sampleCount
::attribute lastMs
::attribute eventNo
::attribute gapMs

::method init
  expose active currentClass startMs peakMs endMs epochId peakGlobal peakDoor probeAgreement sampleCount lastMs eventNo gapMs
  use strict arg gapArg=240
  active=.false; currentClass=''; startMs=0; peakMs=0; endMs=0; epochId=''; peakGlobal=0; peakDoor=0; probeAgreement=0; sampleCount=0; lastMs=-1; eventNo=0; gapMs=gapArg+0

::method classFor private
  use strict arg s
  if s~combinedCandidate then return 'FD_COMBINED_MECHANICAL_RESPONSE'
  if s~doorCandidate then return 'FD_DOOR_MICRO_DEFLECTION'
  if s~globalCandidate then return 'FD_GLOBAL_MICRO_VIBRATION'
  return ''

::method classPriority private
  use strict arg c
  if c='FD_COMBINED_MECHANICAL_RESPONSE' then return 3
  if c='FD_DOOR_MICRO_DEFLECTION' then return 2
  if c='FD_GLOBAL_MICRO_VIBRATION' then return 1
  return 0

::method consume
  expose active currentClass startMs peakMs endMs epochId peakGlobal peakDoor probeAgreement sampleCount lastMs gapMs
  use strict arg s,writer
  c=self~classFor(s)
  if c='' then return .false
  if active & (s~timeMs-lastMs>gapMs | s~epochId<>epochId) then self~flush(writer)
  if \active then do
    active=.true; currentClass=c; startMs=s~timeMs; peakMs=s~timeMs; endMs=s~timeMs; epochId=s~epochId
    peakGlobal=s~globalMagnitude; peakDoor=s~doorMagnitude; probeAgreement=s~probeAgreement; sampleCount=1; lastMs=s~timeMs
    return .true
  end
  if self~classPriority(c)>self~classPriority(currentClass) then currentClass=c
  endMs=s~timeMs; lastMs=s~timeMs; sampleCount+=1
  if s~probeAgreement>probeAgreement then probeAgreement=s~probeAgreement
  if s~globalMagnitude+s~doorMagnitude > peakGlobal+peakDoor then do
    peakMs=s~timeMs; peakGlobal=s~globalMagnitude; peakDoor=s~doorMagnitude
  end
  else do
    if s~globalMagnitude>peakGlobal then peakGlobal=s~globalMagnitude
    if s~doorMagnitude>peakDoor then peakDoor=s~doorMagnitude
  end
  return .true

::method flush
  expose active currentClass startMs peakMs endMs epochId peakGlobal peakDoor probeAgreement sampleCount eventNo lastMs
  use strict arg writer
  if \active then return .nil
  eventNo+=1
  ev=.FDMechanicalEvent~new('FDM'||right(eventNo,6,'0'),currentClass,startMs,peakMs,endMs,epochId,peakGlobal,peakDoor,probeAgreement,sampleCount)
  writer~writeEvent(ev)
  active=.false; currentClass=''; startMs=0; peakMs=0; endMs=0; epochId=''; peakGlobal=0; peakDoor=0; probeAgreement=0; sampleCount=0; lastMs=-1
  return ev


/* Generic deterministic checkpoint key/value state. */
::class FDCheckpointState public
::attribute values get
::method init
  expose values
  values=.directory~new
::method put
  expose values
  use strict arg key,value
  values[key~string]=value~string
  return value
::method get
  expose values
  use arg key,default=''
  if values~hasIndex(key~string) then return values[key~string]
  return default
::method require
  expose values
  use strict arg key
  if \values~hasIndex(key~string) then raise syntax 88.900 array('checkpoint key missing',key)
  return values[key~string]
::method canonical
  expose values
  keys=.array~new
  do k over values~allIndexes; keys~append(k~string); end
  keys~sort
  out=''
  do k over keys
    v=values[k]
    out=out||k~length||':'||k||v~length||':'||v||'1e'x
  end
  return out
::method write
  use strict arg path
  out=.CSVStream~new(path,.false); out~delimiter='09'x; out~open('write replace')
  if out~state<>'READY' then raise syntax 88.900 array('cannot write checkpoint',path,out~description)
  out~csvLineOut(.array~of('schema','key','value'))
  keys=.array~new; do k over self~values~allIndexes; keys~append(k~string); end; keys~sort
  do k over keys; out~csvLineOut(.array~of(.FDDoorMicroMotionVersion~CHECKPOINT_SCHEMA,k,self~values[k])); end
  out~close
  return path
::method read class
  use strict arg path
  if stream(path,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('checkpoint not found',path)
  st=self~new
  inp=.CSVStream~new(path,.false); inp~delimiter='09'x; inp~open('read')
  if inp~state<>'READY' then raise syntax 88.900 array('cannot read checkpoint',path,inp~description)
  first=.true
  do while inp~chars>0
    row=inp~csvLineIn
    if row==.nil | row~items=0 then iterate
    if first then do; first=.false; iterate; end
    /* CSVStream legitimately returns two items when the final TSV field is
       empty.  Empty checkpoint values are meaningful (for example no active
       event class), so preserve them rather than treating them as malformed. */
    if row~items<2 then raise syntax 88.900 array('bad checkpoint row',path)
    if row[1]<>.FDDoorMicroMotionVersion~CHECKPOINT_SCHEMA then raise syntax 88.900 array('checkpoint schema mismatch',row[1])
    value=''
    if row~items>=3 then value=row[3]
    st~put(row[2],value)
  end
  inp~close
  return st


/* -------------------------------------------------------------------------
 * Portable migration bundle.
 *
 * Migratable Job v0.2 keeps checkpoint data movement separate from resume
 * delivery.  For this analyser the transferable checkpoint object is one
 * uncompressed, digest-bound tar file containing the logical checkpoint and
 * every immutable evidence shard committed before the safe point.
 * ------------------------------------------------------------------------- */
::class FDFileUtil public
::method shellQuote class
  use strict arg text
  return "'"||text~string~changestr("'","'\\''")||"'"
::method baseName class
  use strict arg path
  name=path~string; last=0
  do i=1 to name~length
    ch=name~substr(i,1); if ch='/' | ch='\\' then last=i
  end
  if last>0 then name=name~substr(last+1)
  return name
::method parentDir class
  use strict arg path
  text=path~string; last=0
  do i=1 to text~length
    if text~substr(i,1)='/' then last=i
  end
  if last=0 then return '.'
  if last=1 then return '/'
  return text~substr(1,last-1)
::method ensureDir class
  use strict arg path
  address system 'mkdir -p -- '||self~shellQuote(path)
  if rc<>0 then raise syntax 88.900 array('cannot create directory',path)
  return .true
::method removeTree class
  use strict arg path
  if path='' | path='/' then raise syntax 88.900 array('unsafe remove-tree path',path)
  address system 'rm -rf -- '||self~shellQuote(path)
  if rc<>0 then raise syntax 88.900 array('cannot remove path',path)
  return .true
::method sha256 class
  use strict arg path
  if stream(path,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('cannot hash missing file',path)
  tmp=path||'.sha256.tmp'
  address system 'sha256sum -- '||self~shellQuote(path)||' > '||self~shellQuote(tmp)
  if rc<>0 then raise syntax 88.900 array('sha256sum failed',path)
  line=linein(tmp); call stream tmp,'C','CLOSE'
  address system 'rm -f -- '||self~shellQuote(tmp)
  parse var line digest .
  digest=digest~strip~lower
  if digest~length<>64 then raise syntax 88.900 array('invalid sha256 result',path,digest)
  return digest
::method copyExact class
  use strict arg source,destination
  if stream(source,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('copy source missing',source)
  if stream(destination,'C','QUERY EXISTS')<>'' then do
    if self~sha256(source)=self~sha256(destination) then return .true
    raise syntax 88.900 array('destination exists with different content',destination)
  end
  tmp=destination||'.tmp'
  address system 'cp -- '||self~shellQuote(source)||' '||self~shellQuote(tmp)
  if rc<>0 then raise syntax 88.900 array('copy failed',source,destination)
  address system 'mv -f -- '||self~shellQuote(tmp)||' '||self~shellQuote(destination)
  if rc<>0 then raise syntax 88.900 array('atomic copy commit failed',destination)
  return .true


::class FDMigrationBundleMaterialization public
::attribute checkpointPath get
::attribute partCount get
::attribute outputPrefix get
::attribute manifestPath get
::method init
  expose checkpointPath partCount outputPrefix manifestPath
  use strict arg checkpointArg,partArg,prefixArg,manifestArg
  checkpointPath=checkpointArg~string; partCount=partArg+0; outputPrefix=prefixArg~string; manifestPath=manifestArg~string


::class FDMigrationBundle public
::constant SCHEMA 'FD_MIGRATION_BUNDLE_V1'
::method writeManifest private class
  use strict arg path,values
  out=.CSVStream~new(path,.false); out~delimiter='09'x; out~open('write replace')
  if out~state<>'READY' then raise syntax 88.900 array('cannot write migration bundle manifest',path)
  out~csvLineOut(.array~of('schema','key','value'))
  keys=.array~new; do k over values~allIndexes; keys~append(k~string); end; keys~sort
  do k over keys; out~csvLineOut(.array~of(self~SCHEMA,k,values[k])); end
  out~close
  return path
::method readManifest class
  use strict arg path
  if stream(path,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('migration bundle manifest missing',path)
  v=.directory~new
  inp=.CSVStream~new(path,.false); inp~delimiter='09'x; inp~open('read')
  if inp~state<>'READY' then raise syntax 88.900 array('cannot read migration bundle manifest',path)
  first=.true
  do while inp~chars>0
    row=inp~csvLineIn
    if row==.nil | row~items=0 then iterate
    if first then do; first=.false; iterate; end
    if row~items<2 | row[1]<>self~SCHEMA then do; inp~close; raise syntax 88.900 array('migration bundle manifest schema mismatch',path); end
    value=''
    if row~items>=3 then value=row[3]
    v[row[2]]=value
  end
  inp~close
  return v
::method create class
  use strict arg bundlePath,checkpointPath,prefix,partCount,sourceName,requestId='',migrationId='',jobId='',checkpointId=''
  if bundlePath='' | checkpointPath='' | prefix='' | partCount<1 then raise syntax 88.900 array('invalid migration bundle request')
  stage=bundlePath||'.stage'; tmp=bundlePath||'.tmp'
  .FDFileUtil~removeTree(stage); .FDFileUtil~ensureDir(stage||'/parts')
  .FDFileUtil~copyExact(checkpointPath,stage||'/checkpoint.tsv')
  do p=1 to partCount
    tag=right(p,5,'0')
    do kind over .array~of('samples','events','epochs','relocations','exclusions')
      source=prefix||'.'||kind||'.part'||tag||'.tsv'
      target=stage||'/parts/'||kind||'.part'||tag||'.tsv'
      .FDFileUtil~copyExact(source,target)
    end
  end
  values=.directory~new
  values['version']=.FDDoorMicroMotionVersion~VERSION
  values['api']=.FDDoorMicroMotionVersion~API
  values['migration_api']=.FDDoorMicroMotionVersion~MIGRATION_API
  values['source_file']=sourceName
  values['output_base_name']=.FDFileUtil~baseName(prefix)
  values['checkpoint_file']='checkpoint.tsv'
  values['checkpoint_sha256']=.FDFileUtil~sha256(stage||'/checkpoint.tsv')
  values['part_count']=partCount
  values['request_id']=requestId
  values['migration_id']=migrationId
  values['job_id']=jobId
  values['checkpoint_id']=checkpointId
  self~writeManifest(stage||'/bundle.tsv',values)
  address system 'rm -f -- '||.FDFileUtil~shellQuote(tmp)||' '||.FDFileUtil~shellQuote(bundlePath)
  address system 'LC_ALL=C tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C '||.FDFileUtil~shellQuote(stage)||' -cf '||.FDFileUtil~shellQuote(tmp)||' bundle.tsv checkpoint.tsv parts'
  if rc<>0 then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('cannot create migration bundle',bundlePath); end
  address system 'mv -f -- '||.FDFileUtil~shellQuote(tmp)||' '||.FDFileUtil~shellQuote(bundlePath)
  if rc<>0 then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('cannot commit migration bundle',bundlePath); end
  .FDFileUtil~removeTree(stage)
  return 'sha256:'||.FDFileUtil~sha256(bundlePath)
::method validateListing private class
  use strict arg bundlePath,stateDir
  listPath=stateDir||'/bundle.list.tmp'
  address system 'tar -tf '||.FDFileUtil~shellQuote(bundlePath)||' > '||.FDFileUtil~shellQuote(listPath)
  if rc<>0 then raise syntax 88.900 array('cannot list migration bundle',bundlePath)
  ok=.true
  do while lines(listPath)>0
    name=linein(listPath)~strip
    if name='' then iterate
    if name~startsWith('/') | name~pos('..')>0 | name~pos('\\')>0 then do; ok=.false; leave; end
    if name='bundle.tsv' | name='checkpoint.tsv' | name='parts/' then iterate
    if name~startsWith('parts/') then do
      tail=name~substr(7)
      if tail~pos('/')=0 & (tail~startsWith('samples.part') | tail~startsWith('events.part') | tail~startsWith('epochs.part') | tail~startsWith('relocations.part') | tail~startsWith('exclusions.part')) & tail~endsWith('.tsv') then iterate
    end
    ok=.false; leave
  end
  call stream listPath,'C','CLOSE'; address system 'rm -f -- '||.FDFileUtil~shellQuote(listPath)
  if \ok then raise syntax 88.900 array('unsafe or unexpected migration bundle member',name)
  return .true
::method materialize class
  use strict arg bundlePath,outputPrefix,stateDir,expectedDigest='',expectedCheckpointId=''
  .FDFileUtil~ensureDir(stateDir); .FDFileUtil~ensureDir(.FDFileUtil~parentDir(outputPrefix))
  if stream(bundlePath,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('migration bundle missing',bundlePath)
  expected=expectedDigest~string~lower
  if expected~startsWith('sha256:') then expected=expected~substr(8)
  actual=.FDFileUtil~sha256(bundlePath)
  if expected<>'' & actual<>expected then raise syntax 88.900 array('migration bundle digest mismatch',expected,actual)
  self~validateListing(bundlePath,stateDir)
  stage=stateDir||'/bundle.extract.tmp'
  .FDFileUtil~removeTree(stage); .FDFileUtil~ensureDir(stage)
  address system 'tar -xf '||.FDFileUtil~shellQuote(bundlePath)||' -C '||.FDFileUtil~shellQuote(stage)
  if rc<>0 then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('cannot extract migration bundle',bundlePath); end
  m=self~readManifest(stage||'/bundle.tsv')
  if \m~hasIndex('version') | m['version']<>.FDDoorMicroMotionVersion~VERSION then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('migration bundle executable revision mismatch'); end
  if \m~hasIndex('output_base_name') | m['output_base_name']<>.FDFileUtil~baseName(outputPrefix) then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('migration bundle logical output-prefix mismatch'); end
  if expectedCheckpointId<>'' then do
    if \m~hasIndex('checkpoint_id') | m['checkpoint_id']<>expectedCheckpointId then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('migration bundle checkpoint id mismatch'); end
  end
  if \m~hasIndex('part_count') then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('migration bundle part count missing'); end
  partCount=m['part_count']+0; if partCount<1 then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('migration bundle part count invalid'); end
  if \m~hasIndex('checkpoint_sha256') then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('migration bundle checkpoint digest missing'); end
  if .FDFileUtil~sha256(stage||'/checkpoint.tsv')<>m['checkpoint_sha256'] then do; .FDFileUtil~removeTree(stage); raise syntax 88.900 array('checkpoint digest mismatch inside migration bundle'); end
  do p=1 to partCount
    tag=right(p,5,'0')
    do kind over .array~of('samples','events','epochs','relocations','exclusions')
      source=stage||'/parts/'||kind||'.part'||tag||'.tsv'
      target=outputPrefix||'.'||kind||'.part'||tag||'.tsv'
      .FDFileUtil~copyExact(source,target)
    end
  end
  checkpointId=m['checkpoint_id']; if checkpointId='' then checkpointId='unknown'
  checkpointPath=stateDir||'/resume.'||checkpointId||'.tsv'
  .FDFileUtil~copyExact(stage||'/checkpoint.tsv',checkpointPath)
  manifestPath=stateDir||'/bundle.'||checkpointId||'.tsv'
  .FDFileUtil~copyExact(stage||'/bundle.tsv',manifestPath)
  .FDFileUtil~removeTree(stage)
  return .FDMigrationBundleMaterialization~new(checkpointPath,partCount,outputPrefix,manifestPath)


::routine FDSqrt public
  use strict arg x
  if x<=0 then return 0
  guess=x; if guess<1 then guess=1
  do 14; guess=(guess+(x/guess))/2; end
  return guess

::routine FDSign public
  use strict arg x
  if x>0 then return 1
  if x<0 then return -1
  return 0

::routine FDMax public
  use strict arg a,b
  if a>b then return a
  return b

::routine FDMin public
  use strict arg a,b
  if a<b then return a
  return b

::requires 'csvStream.cls'

/* -------------------------------------------------------------------------
 * Night-vision door geometry.
 *
 * The supplied tp00000 reference view shows a distinctive three-edge vertical
 * fingerprint on the F11 door/frame: an inner panel/leaf feature, the door-leaf
 * edge, and the fixed frame/jamb edge.  We learn exact spacing and gradient
 * polarity from a clear reference frame, then use that learned fingerprint to
 * re-find the door after camera relocation.  No audio or semantic event times
 * participate in geometry acquisition.
 * ------------------------------------------------------------------------- */
::class FDNightDoorGeometryModel public
::attribute config get
::method init
  expose config
  use strict arg cfg
  config=cfg

::method pixel private
  use strict arg plane,lineSize,x,y,width,height
  xx=trunc(x); yy=trunc(y)
  if xx<0 then xx=0; if xx>=width then xx=width-1
  if yy<0 then yy=0; if yy>=height then yy=height-1
  return c2d(plane~substr((yy*lineSize)+xx+1,1))

::method verticalEdgeAt private
  expose config
  use strict arg plane,width,height,lineSize,x,yLo,yHi
  xx=trunc(x); y1=trunc(height*yLo); y2=trunc(height*yHi)
  if xx<2 | xx>width-3 | y2<=y1 then return .FDEdgeMeasurement~new(xx,0,0,.false)
  stride=(y2-y1)%40; if stride<2 then stride=2
  absSum=0; signedSum=0; n=0
  do y=y1 to y2 by stride
    a=self~pixel(plane,lineSize,xx-1,y,width,height); b=self~pixel(plane,lineSize,xx+1,y,width,height)
    g=(b-a)/2; absSum+=abs(g); signedSum+=g; n+=1
  end
  if n=0 then return .FDEdgeMeasurement~new(xx,0,0,.false)
  score=absSum/n; signed=signedSum/n
  return .FDEdgeMeasurement~new(xx,score,signed,score>=config~minimumEdgeScore)

::method verticalEdgeTrack
  expose config
  use strict arg plane,width,height,lineSize,centre,yLo,yHi,radius=0
  if radius<=0 then radius=config~trackingSearchPixels
  x1=trunc(centre-radius); x2=trunc(centre+radius)
  if x1<2 then x1=2; if x2>width-3 then x2=width-3
  scores=.directory~new; signs=.directory~new; bestX=0; best=-1
  do x=x1 to x2
    m=self~verticalEdgeAt(plane,width,height,lineSize,x,yLo,yHi)
    scores[x]=m~score; signs[x]=m~signedScore
    if m~score>best then do; best=m~score; bestX=x; end
  end
  if bestX=0 then return .FDEdgeMeasurement~new(0,0,0,.false)
  centreScore=scores[bestX]
  left=centreScore; right=centreScore
  if scores~hasIndex(bestX-1) then left=scores[bestX-1]
  if scores~hasIndex(bestX+1) then right=scores[bestX+1]
  off=0; denom=left-(2*centreScore)+right
  if denom<>0 then off=0.5*(left-right)/denom
  if off>0.5 then off=0.5; if off< -0.5 then off=-0.5
  signed=signs[bestX]
  return .FDEdgeMeasurement~new(bestX+off,centreScore,signed,centreScore>=config~minimumEdgeScore)

::method horizontalEdgeAt private
  expose config
  use strict arg plane,width,height,lineSize,y,xLo,xHi
  yy=trunc(y); x1=trunc(width*xLo); x2=trunc(width*xHi)
  if yy<2 | yy>height-3 | x2<=x1 then return .FDEdgeMeasurement~new(yy,0,0,.false)
  stride=(x2-x1)%40; if stride<2 then stride=2
  absSum=0; signedSum=0; n=0
  do x=x1 to x2 by stride
    a=self~pixel(plane,lineSize,x,yy-1,width,height); b=self~pixel(plane,lineSize,x,yy+1,width,height)
    g=(b-a)/2; absSum+=abs(g); signedSum+=g; n+=1
  end
  if n=0 then return .FDEdgeMeasurement~new(yy,0,0,.false)
  score=absSum/n; signed=signedSum/n
  return .FDEdgeMeasurement~new(yy,score,signed,score>=config~minimumEdgeScore)

::method horizontalEdgeBroad private
  expose config
  use strict arg plane,width,height,lineSize,yLo,yHi,xLo,xHi
  y1=trunc(height*yLo); y2=trunc(height*yHi)
  if y1<2 then y1=2; if y2>height-3 then y2=height-3
  bestY=0; best=-1; scores=.directory~new; signs=.directory~new
  do y=y1 to y2
    m=self~horizontalEdgeAt(plane,width,height,lineSize,y,xLo,xHi)
    scores[y]=m~score; signs[y]=m~signedScore
    if m~score>best then do; best=m~score; bestY=y; end
  end
  if bestY=0 then return .FDEdgeMeasurement~new(0,0,0,.false)
  c=scores[bestY]; l=c; r=c
  if scores~hasIndex(bestY-1) then l=scores[bestY-1]
  if scores~hasIndex(bestY+1) then r=scores[bestY+1]
  off=0; denom=l-(2*c)+r
  if denom<>0 then off=0.5*(l-r)/denom
  if off>0.5 then off=0.5; if off< -0.5 then off=-0.5
  return .FDEdgeMeasurement~new(bestY+off,c,signs[bestY],c>=config~minimumEdgeScore)

::method horizontalEdgeTrack private
  expose config
  use strict arg plane,width,height,lineSize,centre,xLo,xHi,radius=0
  if radius<=0 then radius=config~trackingSearchPixels
  y1=trunc(centre-radius); y2=trunc(centre+radius)
  if y1<2 then y1=2; if y2>height-3 then y2=height-3
  bestY=0; best=-1; scores=.directory~new; signs=.directory~new
  do y=y1 to y2
    m=self~horizontalEdgeAt(plane,width,height,lineSize,y,xLo,xHi)
    scores[y]=m~score; signs[y]=m~signedScore
    if m~score>best then do; best=m~score; bestY=y; end
  end
  if bestY=0 then return .FDEdgeMeasurement~new(0,0,0,.false)
  c=scores[bestY]; l=c; r=c
  if scores~hasIndex(bestY-1) then l=scores[bestY-1]
  if scores~hasIndex(bestY+1) then r=scores[bestY+1]
  off=0; denom=l-(2*c)+r
  if denom<>0 then off=0.5*(l-r)/denom
  if off>0.5 then off=0.5; if off< -0.5 then off=-0.5
  return .FDEdgeMeasurement~new(bestY+off,c,signs[bestY],c>=config~minimumEdgeScore)

::method topVerticalEdges
  expose config
  use strict arg plane,width,height,lineSize,xLo,xHi,yLo,yHi,maxCount=0
  if maxCount<=0 then maxCount=config~fingerprintTopEdges
  x1=trunc(width*xLo); x2=trunc(width*xHi)
  if x1<2 then x1=2; if x2>width-3 then x2=width-3
  measurements=.directory~new
  do x=x1 to x2
    measurements[x]=self~verticalEdgeAt(plane,width,height,lineSize,x,yLo,yHi)
  end
  suppressed=.set~new; edgeList=.array~new
  minSep=trunc(width*0.010); if minSep<6 then minSep=6
  do pick=1 to maxCount
    bestX=0; best=-1
    do x=x1 to x2
      if suppressed~hasIndex(x) then iterate
      m=measurements[x]
      if m~score>best then do; best=m~score; bestX=x; end
    end
    if bestX=0 | best<config~minimumEdgeScore then leave
    edgeList~append(measurements[bestX])
    do s=bestX-minSep to bestX+minSep; suppressed~put(s); end
  end
  /* small arrays: deterministic insertion sort by x position */
  do i=2 to edgeList~items
    current=edgeList[i]; j=i-1
    do while j>=1
      if edgeList[j]~position<=current~position then leave
      edgeList[j+1]=edgeList[j]; j-=1
    end
    edgeList[j+1]=current
  end
  return edgeList

::method doorAppearanceContrast private
  /* Night-IR appearance guard.  It deliberately uses contrast, not absolute
     luminance, so moderate IR exposure changes do not invalidate relocation
     reacquisition.  The patch spans the distinctive lock/panel area on the
     door side of the fixed jamb. */
  use strict arg plane,width,height,lineSize,panelX,doorX,frameX
  span=frameX-panelX
  if span<=4 then return 0
  x1=trunc(frameX-(1.15*span)); x2=trunc(frameX-(0.50*(frameX-doorX)))
  y1=trunc(height*0.30); y2=trunc(height*0.53)
  if x1<1 then x1=1; if x2>width-2 then x2=width-2
  if y1<1 then y1=1; if y2>height-2 then y2=height-2
  if x2<=x1 | y2<=y1 then return 0
  n=0; mean=0; m2=0
  do y=y1 to y2 by 2
    row=(y*lineSize)+1
    do x=x1 to x2 by 2
      v=c2d(plane~substr(row+x,1)); n+=1
      delta=v-mean; mean=mean+(delta/n); m2=m2+delta*(v-mean)
    end
  end
  if n<2 then return 0
  return FDSqrt(m2/(n-1))

::method calibrateFingerprint
  expose config
  use strict arg plane,width,height,lineSize
  edges=self~topVerticalEdges(plane,width,height,lineSize,config~bootstrapFrameXLo,config~bootstrapFrameXHi,0.10,0.70,14)
  if edges~items<3 then return .nil
  minGap=width*0.012; maxGap=width*0.050; bestScore=-1; best=.nil
  do i=1 to edges~items-2
    do j=i+1 to edges~items-1
      do k=j+1 to edges~items
        p=edges[i]; d=edges[j]; f=edges[k]
        g1=d~position-p~position; g2=f~position-d~position
        if g1<minGap | g1>maxGap | g2<minGap | g2>maxGap then iterate
        ratio=g1/g2; if ratio<0.55 | ratio>1.80 then iterate
        du=self~verticalEdgeTrack(plane,width,height,lineSize,d~position,0.20,0.42,3)
        dl=self~verticalEdgeTrack(plane,width,height,lineSize,d~position,0.35,0.60,3)
        fu=self~verticalEdgeTrack(plane,width,height,lineSize,f~position,0.20,0.42,3)
        fl=self~verticalEdgeTrack(plane,width,height,lineSize,f~position,0.35,0.60,3)
        if \du~valid | \dl~valid | \fu~valid | \fl~valid then iterate
        score=p~score+d~score+f~score+du~score+dl~score+fu~score+fl~score
        if score>bestScore then do
          appearance=self~doorAppearanceContrast(plane,width,height,lineSize,p~position,d~position,f~position)
          if appearance<=0 then iterate
          bestScore=score
          best=.FDDoorFingerprint~new(p~position,d~position,f~position,p~signedScore,d~signedScore,f~signedScore,width,score,appearance)
        end
      end
    end
  end
  return best

::method polarityFactor private
  use strict arg referenceSigned,candidateSigned
  rs=FDSign(referenceSigned); cs=FDSign(candidateSigned)
  if rs=0 | cs=0 then return 1.0
  if rs=cs then return 1.15
  return 0.60

::method verticalEdgeExpected private
  expose config
  use strict arg plane,width,height,lineSize,centre,yLo,yHi,radius=10
  x1=trunc(centre-radius); x2=trunc(centre+radius)
  if x1<2 then x1=2; if x2>width-3 then x2=width-3
  best=.nil; bestMetric=-999999
  do x=x1 to x2
    m=self~verticalEdgeAt(plane,width,height,lineSize,x,yLo,yHi)
    if \m~valid then iterate
    metric=m~score-(abs(x-centre)*0.12)
    if metric>bestMetric then do; bestMetric=metric; best=m; end
  end
  if best==.nil then return .FDEdgeMeasurement~new(centre,0,0,.false)
  return self~verticalEdgeTrack(plane,width,height,lineSize,best~position,yLo,yHi,1)

::method locateDoor
  expose config
  use strict arg plane,width,height,lineSize,fingerprint
  if fingerprint==.nil then return .nil
  edges=self~topVerticalEdges(plane,width,height,lineSize,config~fullSearchXLo,config~fullSearchXHi,0.10,0.70,config~fingerprintTopEdges)
  if edges~items<1 then return .nil
  bestScore=-1; best=.nil; scaleTol=config~fingerprintScaleTolerance; gapTol=config~fingerprintGapTolerance
  baseScale=width/fingerprint~referenceWidth
  if baseScale<=0 then return .nil
  do f over edges
    do scale100=80 to 120 by 5
      localScale=scale100/100
      scale=baseScale*localScale
      expectedDoor=f~position-(fingerprint~doorFrameGap*scale)
      d=self~verticalEdgeExpected(plane,width,height,lineSize,expectedDoor,0.10,0.70,10)
      if \d~valid then iterate
      expectedPanel=d~position-(fingerprint~panelDoorGap*scale)
      p=self~verticalEdgeExpected(plane,width,height,lineSize,expectedPanel,0.10,0.70,10)
      if \p~valid then iterate
      g1=d~position-p~position; g2=f~position-d~position
      if g1<=0 | g2<=0 then iterate
      s1=g1/(fingerprint~panelDoorGap*baseScale); s2=g2/(fingerprint~doorFrameGap*baseScale)
      if s1<(1-scaleTol) | s1>(1+scaleTol) | s2<(1-scaleTol) | s2>(1+scaleTol) then iterate
      if abs(s1-s2)>gapTol then iterate
      avgScale=(s1+s2)/2
      du=self~verticalEdgeTrack(plane,width,height,lineSize,d~position,0.20,0.42,3)
      dl=self~verticalEdgeTrack(plane,width,height,lineSize,d~position,0.35,0.60,3)
      fu=self~verticalEdgeTrack(plane,width,height,lineSize,f~position,0.20,0.42,3)
      fl=self~verticalEdgeTrack(plane,width,height,lineSize,f~position,0.35,0.60,3)
      if \du~valid | \dl~valid | \fu~valid | \fl~valid then iterate
      appearance=self~doorAppearanceContrast(plane,width,height,lineSize,p~position,d~position,f~position)
      if fingerprint~appearanceContrast>0 then do
        if appearance<=0 then iterate
        appearanceRatio=appearance/fingerprint~appearanceContrast
        if appearanceRatio<config~locatorAppearanceMinRatio | appearanceRatio>config~locatorAppearanceMaxRatio then iterate
      end
      else appearanceRatio=1.0
      score=(p~score*self~polarityFactor(fingerprint~panelSign,p~signedScore)) +,
            (d~score*self~polarityFactor(fingerprint~doorSign,d~signedScore)) +,
            (f~score*self~polarityFactor(fingerprint~frameSign,f~signedScore)) +,
            du~score+dl~score+fu~score+fl~score -,
            (abs(s1-s2)*4) + FDMax(0,3.0-(abs(appearanceRatio-1.0)*6.0))
      if score>bestScore then do
        bestScore=score; best=.FDDoorAnchor~new(p~position,d~position,f~position,avgScale,score)
      end
    end
  end
  if best==.nil then return .nil
  if best~score<config~locatorMinimumScore then return .nil
  return best

::method acquireTrackedGeometry
  expose config
  use strict arg plane,width,height,lineSize,anchor
  d=.directory~new
  d['PANEL_X']=anchor~panelX
  d['LOCATOR_SCORE']=anchor~score
  d['DOOR_UP']=self~verticalEdgeTrack(plane,width,height,lineSize,anchor~doorX,0.20,0.42,config~trackingSearchPixels)
  d['DOOR_LO']=self~verticalEdgeTrack(plane,width,height,lineSize,anchor~doorX,0.35,0.60,config~trackingSearchPixels)
  d['FRAME_UP']=self~verticalEdgeTrack(plane,width,height,lineSize,anchor~frameX,0.20,0.42,config~trackingSearchPixels)
  d['FRAME_LO']=self~verticalEdgeTrack(plane,width,height,lineSize,anchor~frameX,0.35,0.60,config~trackingSearchPixels)
  frameX=(d['FRAME_UP']~position+d['FRAME_LO']~position)/2
  xLo=(frameX/width)+0.055; xMid=(frameX/width)+0.26; xHi=(frameX/width)+0.47
  if xLo<0.05 then xLo=0.05; if xHi>0.97 then xHi=0.97
  if xMid>xHi-0.05 then xMid=(xLo+xHi)/2
  floorL=self~horizontalEdgeBroad(plane,width,height,lineSize,0.48,0.86,xLo,xMid)
  if floorL~valid then floorR=self~horizontalEdgeTrack(plane,width,height,lineSize,floorL~position,xMid,xHi,14)
  else floorR=.FDEdgeMeasurement~new(0,0,0,.false)
  d['FLOOR_L']=floorL; d['FLOOR_R']=floorR
  return d

::method trackGeometry
  expose config
  use strict arg plane,width,height,lineSize,previous
  d=.directory~new
  d['PANEL_X']=previous['PANEL_X']
  d['LOCATOR_SCORE']=previous['LOCATOR_SCORE']
  d['DOOR_UP']=self~verticalEdgeTrack(plane,width,height,lineSize,previous['DOOR_UP']~position,0.20,0.42,config~trackingSearchPixels)
  d['DOOR_LO']=self~verticalEdgeTrack(plane,width,height,lineSize,previous['DOOR_LO']~position,0.35,0.60,config~trackingSearchPixels)
  d['FRAME_UP']=self~verticalEdgeTrack(plane,width,height,lineSize,previous['FRAME_UP']~position,0.20,0.42,config~trackingSearchPixels)
  d['FRAME_LO']=self~verticalEdgeTrack(plane,width,height,lineSize,previous['FRAME_LO']~position,0.35,0.60,config~trackingSearchPixels)
  frameX=(d['FRAME_UP']~position+d['FRAME_LO']~position)/2
  xLo=(frameX/width)+0.055; xMid=(frameX/width)+0.26; xHi=(frameX/width)+0.47
  if xLo<0.05 then xLo=0.05; if xHi>0.97 then xHi=0.97
  if xMid>xHi-0.05 then xMid=(xLo+xHi)/2
  if previous['FLOOR_L'] \== .nil & previous['FLOOR_L']~valid then d['FLOOR_L']=self~horizontalEdgeTrack(plane,width,height,lineSize,previous['FLOOR_L']~position,xLo,xMid,config~trackingSearchPixels)
  else d['FLOOR_L']=self~horizontalEdgeBroad(plane,width,height,lineSize,0.48,0.86,xLo,xMid)
  if d['FLOOR_L']~valid then do
    if previous['FLOOR_R'] \== .nil & previous['FLOOR_R']~valid then d['FLOOR_R']=self~horizontalEdgeTrack(plane,width,height,lineSize,previous['FLOOR_R']~position,xMid,xHi,config~trackingSearchPixels)
    else d['FLOOR_R']=self~horizontalEdgeTrack(plane,width,height,lineSize,d['FLOOR_L']~position,xMid,xHi,14)
  end
  else d['FLOOR_R']=.FDEdgeMeasurement~new(0,0,0,.false)
  return d

::method validGeometry
  use strict arg d
  if d==.nil then return .false
  do k over .array~of('DOOR_UP','DOOR_LO','FRAME_UP','FRAME_LO')
    if \d~hasIndex(k) then return .false
    if d[k]==.nil | \d[k]~valid then return .false
  end
  return .true

::method anchorFromGeometry
  use strict arg geometry
  panel=geometry['PANEL_X']+0
  door=(geometry['DOOR_UP']~position+geometry['DOOR_LO']~position)/2
  frame=(geometry['FRAME_UP']~position+geometry['FRAME_LO']~position)/2
  return .FDDoorAnchor~new(panel,door,frame,1.0,geometry['LOCATOR_SCORE'])


/* Immutable output shards. A migration closes the current part; destination
 * resume always starts the next part. Final canonical TSVs are deterministic
 * CSVStream merges of those immutable shards. */
::class FDShardWriter public
::attribute prefix get
::attribute partNo get
::attribute sourceName get
::attribute sampleOut private
::attribute eventOut private
::attribute epochOut private
::attribute relocationOut private
::attribute exclusionOut private
::attribute closed private

::method init
  expose prefix partNo sourceName sampleOut eventOut epochOut relocationOut exclusionOut closed
  use strict arg prefixArg,partArg,sourceArg
  prefix=prefixArg~string; partNo=partArg+0; sourceName=sourceArg~string; closed=.false
  if prefix='' | partNo<1 then raise syntax 88.900 array('invalid FD shard writer')
  sampleOut=self~openTsv(self~partPath('samples'))
  eventOut=self~openTsv(self~partPath('events'))
  epochOut=self~openTsv(self~partPath('epochs'))
  relocationOut=self~openTsv(self~partPath('relocations'))
  exclusionOut=self~openTsv(self~partPath('exclusions'))
  sampleOut~csvLineOut(.FDShardWriter~sampleHeader)
  eventOut~csvLineOut(.FDShardWriter~eventHeader)
  epochOut~csvLineOut(.FDShardWriter~epochHeader)
  relocationOut~csvLineOut(.FDShardWriter~relocationHeader)
  exclusionOut~csvLineOut(.FDShardWriter~exclusionHeader)

::method partPath
  expose prefix partNo
  use strict arg kind
  return prefix||'.'||kind||'.part'||right(partNo,5,'0')||'.tsv'

::method openTsv private
  use strict arg path
  out=.CSVStream~new(path,.false); out~delimiter='09'x; out~open('write replace')
  if out~state<>'READY' then raise syntax 88.900 array('cannot open TSV shard',path,out~description)
  return out

::method sampleHeader class
  return .array~of('schema','source_file','sample','time_ms','time_hms','pts','epoch_id','geometry_state',,
    'frame_upper_x','frame_lower_x','door_upper_x','door_lower_x','floor_left_y','floor_right_y',,
    'global_dx_step_px','global_dy_step_px','door_upper_residual_step_px','door_lower_residual_step_px',,
    'global_magnitude_px','door_magnitude_px','global_threshold_px','door_threshold_px',,
    'coherent_global_x','coherent_global_y','coherent_door','global_candidate','door_candidate','combined_candidate',,
    'probe_agreement','locator_score','frame_upper_score','frame_lower_score','door_upper_score','door_lower_score')
::method eventHeader class
  return .array~of('schema','source_file','event_id','class','start_ms','start_hms','peak_ms','peak_hms','end_ms','end_hms','duration_ms','confidence','epoch_id','peak_global_px','peak_door_px','probe_agreement','samples')
::method epochHeader class
  return .array~of('schema','source_file','epoch_id','pose','start_ms','start_hms','end_ms','end_hms','duration_ms','stable_samples','panel_anchor_x','door_anchor_x','frame_anchor_x','locator_score')
::method relocationHeader class
  return .array~of('schema','source_file','relocation_id','reason','start_ms','start_hms','end_ms','end_hms','duration_ms','from_epoch','to_epoch')
::method exclusionHeader class
  return .array~of('schema','source_file','exclusion_id','reason','start_ms','start_hms','end_ms','end_hms','duration_ms','skipped_frames')

::method writeSample
  expose sampleOut sourceName closed
  use strict arg s
  if closed then raise syntax 88.900 array('FD shard writer is closed')
  sampleOut~csvLineOut(.array~of(.FDDoorMicroMotionVersion~SAMPLE_SCHEMA,sourceName,s~sampleIndex,trunc(s~timeMs+0.5),.FDShardWriter~formatTimeMs(s~timeMs),s~pts,s~epochId,s~geometryState,s~frameUpperX,s~frameLowerX,s~doorUpperX,s~doorLowerX,s~floorLeftY,s~floorRightY,s~globalDxStep,s~globalDyStep,s~doorUpperResidualStep,s~doorLowerResidualStep,s~globalMagnitude,s~doorMagnitude,s~globalThreshold,s~doorThreshold,s~coherentGlobalX,s~coherentGlobalY,s~coherentDoor,s~globalCandidate,s~doorCandidate,s~combinedCandidate,s~probeAgreement,s~locatorScore,s~frameUpperScore,s~frameLowerScore,s~doorUpperScore,s~doorLowerScore))
  if sampleOut~state='ERROR' then raise syntax 88.900 array('sample TSV write failed',sampleOut~lastDataError)

::method writeEvent
  expose eventOut sourceName closed
  use strict arg e
  if closed then raise syntax 88.900 array('FD shard writer is closed')
  eventOut~csvLineOut(.array~of(.FDDoorMicroMotionVersion~EVENT_SCHEMA,sourceName,e~id,e~classification,trunc(e~startMs+0.5),.FDShardWriter~formatTimeMs(e~startMs),trunc(e~peakMs+0.5),.FDShardWriter~formatTimeMs(e~peakMs),trunc(e~endMs+0.5),.FDShardWriter~formatTimeMs(e~endMs),trunc(e~durationMs+0.5),e~confidence,e~epochId,e~peakGlobalPixels,e~peakDoorPixels,e~probeAgreement,e~samples))
  if eventOut~state='ERROR' then raise syntax 88.900 array('event TSV write failed',eventOut~lastDataError)

::method writeEpoch
  expose epochOut sourceName closed
  use strict arg e
  if closed then raise syntax 88.900 array('FD shard writer is closed')
  epochOut~csvLineOut(.array~of(.FDDoorMicroMotionVersion~EPOCH_SCHEMA,sourceName,e~id,e~pose,trunc(e~startMs+0.5),.FDShardWriter~formatTimeMs(e~startMs),trunc(e~endMs+0.5),.FDShardWriter~formatTimeMs(e~endMs),trunc(e~endMs-e~startMs+0.5),e~stableSamples,e~panelAnchorX,e~doorAnchorX,e~frameAnchorX,e~locatorScore))
  if epochOut~state='ERROR' then raise syntax 88.900 array('epoch TSV write failed',epochOut~lastDataError)

::method writeRelocation
  expose relocationOut sourceName closed
  use strict arg r
  if closed then raise syntax 88.900 array('FD shard writer is closed')
  relocationOut~csvLineOut(.array~of(.FDDoorMicroMotionVersion~RELOCATION_SCHEMA,sourceName,r~id,r~reason,trunc(r~startMs+0.5),.FDShardWriter~formatTimeMs(r~startMs),trunc(r~endMs+0.5),.FDShardWriter~formatTimeMs(r~endMs),trunc(r~durationMs+0.5),r~fromEpoch,r~toEpoch))
  if relocationOut~state='ERROR' then raise syntax 88.900 array('relocation TSV write failed',relocationOut~lastDataError)

::method writeExclusion
  expose exclusionOut sourceName closed
  use strict arg e
  if closed then raise syntax 88.900 array('FD shard writer is closed')
  exclusionOut~csvLineOut(.array~of(.FDDoorMicroMotionVersion~EXCLUSION_SCHEMA,sourceName,e~id,e~reason,trunc(e~startMs+0.5),.FDShardWriter~formatTimeMs(e~startMs),trunc(e~endMs+0.5),.FDShardWriter~formatTimeMs(e~endMs),trunc(e~durationMs+0.5),e~skippedFrames))
  if exclusionOut~state='ERROR' then raise syntax 88.900 array('exclusion TSV write failed',exclusionOut~lastDataError)

::method close
  expose sampleOut eventOut epochOut relocationOut exclusionOut closed
  if closed then return .true
  sampleOut~close; eventOut~close; epochOut~close; relocationOut~close; exclusionOut~close
  closed=.true
  return .true

::method formatTimeMs class
  use strict arg milliseconds
  if milliseconds<0 then milliseconds=0
  total=trunc(milliseconds+0.5); h=total%3600000; remain=total//3600000; m=remain%60000; remain=remain//60000; s=remain%1000; ms=remain//1000
  return right(h,2,'0')||':'||right(m,2,'0')||':'||right(s,2,'0')||'.'||right(ms,3,'0')

::method mergeKind class
  use strict arg prefix,kind,partCount,header
  target=prefix||'.'||kind||'.tsv'
  out=.CSVStream~new(target,.false); out~delimiter='09'x; out~open('write replace')
  if out~state<>'READY' then raise syntax 88.900 array('cannot create merged TSV',target)
  out~csvLineOut(header)
  do part=1 to partCount
    path=prefix||'.'||kind||'.part'||right(part,5,'0')||'.tsv'
    if stream(path,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('missing immutable output shard',path)
    inp=.CSVStream~new(path,.false); inp~delimiter='09'x; inp~open('read')
    if inp~state<>'READY' then raise syntax 88.900 array('cannot read output shard',path)
    first=.true
    do while inp~chars>0
      row=inp~csvLineIn
      if row==.nil | row~items=0 then iterate
      if first then do; first=.false; iterate; end
      out~csvLineOut(row)
    end
    inp~close
  end
  out~close
  return target

::method mergeAll class
  use strict arg prefix,partCount
  paths=.array~new
  paths~append(self~mergeKind(prefix,'samples',partCount,.FDShardWriter~sampleHeader))
  paths~append(self~mergeKind(prefix,'events',partCount,.FDShardWriter~eventHeader))
  paths~append(self~mergeKind(prefix,'epochs',partCount,.FDShardWriter~epochHeader))
  paths~append(self~mergeKind(prefix,'relocations',partCount,.FDShardWriter~relocationHeader))
  paths~append(self~mergeKind(prefix,'exclusions',partCount,.FDShardWriter~exclusionHeader))
  return paths

::method writePartsManifest class
  use strict arg prefix,partCount,sourceName,status='OPEN'
  path=prefix||'.parts.tsv'
  out=.CSVStream~new(path,.false); out~delimiter='09'x; out~open('write replace')
  if out~state<>'READY' then raise syntax 88.900 array('cannot write part manifest',path)
  out~csvLineOut(.array~of('schema','source_file','part','status','samples_path','events_path','epochs_path','relocations_path','exclusions_path'))
  do p=1 to partCount
    tag=right(p,5,'0')
    out~csvLineOut(.array~of(.FDDoorMicroMotionVersion~PART_SCHEMA,sourceName,p,status,prefix||'.samples.part'||tag||'.tsv',prefix||'.events.part'||tag||'.tsv',prefix||'.epochs.part'||tag||'.tsv',prefix||'.relocations.part'||tag||'.tsv',prefix||'.exclusions.part'||tag||'.tsv'))
  end
  out~close
  return path

::method writeRun class
  use strict arg prefix,state,status,configText,sourcePath,sourceName,sourceEvidenceRef=''
  path=prefix||'.run.tsv'
  out=.CSVStream~new(path,.false); out~delimiter='09'x; out~open('write replace')
  if out~state<>'READY' then raise syntax 88.900 array('cannot write FD run TSV',path)
  out~csvLineOut(.array~of('schema','version','api','migration_api','status','source_path','source_file','source_evidence_ref','decoded_frames','eligible_frames','analysed_frames','excluded_frames','samples_emitted','events','epochs','relocations','exclusions','first_pts','last_pts','time_base_num','time_base_den','last_relative_ms','analysis_start_ms','analysis_end_ms','wall_clock_origin','analysis_wall_start','analysis_wall_end','output_parts','checkpoint_generation','audio_used','config'))
  out~csvLineOut(.array~of(.FDDoorMicroMotionVersion~RUN_SCHEMA,.FDDoorMicroMotionVersion~VERSION,.FDDoorMicroMotionVersion~API,.FDDoorMicroMotionVersion~MIGRATION_API,status,sourcePath,sourceName,sourceEvidenceRef,state~get('decoded_frames','0'),state~get('eligible_frames','0'),state~get('analysed_frames','0'),state~get('excluded_frames','0'),state~get('samples_emitted','0'),state~get('event_no','0'),state~get('epoch_no','0'),state~get('relocation_no','0'),state~get('exclusion_no','0'),state~get('origin_pts','0'),state~get('last_pts','0'),state~get('time_base_num','0'),state~get('time_base_den','1'),state~get('last_ms','0'),state~get('analysis_start_ms','0'),state~get('analysis_end_ms','-1'),state~get('wall_clock_origin',''),state~get('analysis_wall_start',''),state~get('analysis_wall_end',''),state~get('part_no','0'),state~get('checkpoint_generation','0'),'NO',configText))
  out~close
  return path


::class FDDecodedFrame public
::attribute pts get
::attribute width get
::attribute height get
::attribute lineSize get
::attribute plane get
::method init
  expose pts width height lineSize plane
  use strict arg p,w,h,ls,bytes=''
  pts=p+0; width=w+0; height=h+0; lineSize=ls+0; plane=bytes


/* Iterative FFmpeg video decoder. The returned luma plane is copied before the
 * AVFrame is unreferenced, so callers never retain process-local FFmpeg state. */
::class FDVideoDecoder public
::attribute sourcePath get
::attribute timeBaseNum get
::attribute timeBaseDen get
::attribute selectedStream get
::attribute opened get
::attribute formatBridgePath get
::attribute codecBridgePath get
::attribute utilBridgePath get

::method init
  expose sourcePath formatBridgePath codecBridgePath utilBridgePath opened timeBaseNum timeBaseDen selectedStream formatLibrary codecLibrary utilLibrary context formatView streamView codecParameters codecContext decoder packet packetView frame frameView eof
  use strict arg path,formatBridge='camera_ffmpeg_avformat.bridge.json',codecBridge='camera_ffmpeg_avcodec.bridge.json',utilBridge='camera_ffmpeg_avutil.bridge.json'
  sourcePath=path~string; formatBridgePath=formatBridge~string; codecBridgePath=codecBridge~string; utilBridgePath=utilBridge~string
  opened=.false; timeBaseNum=0; timeBaseDen=1; selectedStream=-1; eof=.false
  formatLibrary=.nil; codecLibrary=.nil; utilLibrary=.nil; context=.nil; formatView=.nil; streamView=.nil; codecParameters=.nil; codecContext=.nil; decoder=.nil; packet=.nil; packetView=.nil; frame=.nil; frameView=.nil

::method open
  expose sourcePath formatBridgePath codecBridgePath utilBridgePath opened timeBaseNum timeBaseDen selectedStream formatLibrary codecLibrary utilLibrary context formatView streamView codecParameters codecContext decoder packet packetView frame frameView eof
  if opened then return .true
  if stream(sourcePath,'C','QUERY EXISTS')=='' then return .false
  formatLibrary=.foreign~load(formatBridgePath); codecLibrary=.foreign~load(codecBridgePath); utilLibrary=.foreign~load(utilBridgePath)
  openedResult=formatLibrary~open_input(.foreign~out,sourcePath,.nil,.nil)
  if openedResult~returnValue<>0 then return .false
  context=openedResult~out('context')
  if formatLibrary~find_stream_info(context,.nil)<0 then return .false
  best=formatLibrary~find_best_stream_decoder(context,0,-1,-1,.foreign~out,0)
  if \best~isA(.ForeignResult) | best~returnValue<0 then return .false
  selectedStream=best~returnValue; decoder=best~out('decoder')
  formatView=formatLibrary~structView('AVFormatContext',context)
  streamsAddress=formatView~get('streams'); streamAddress=.foreign~pointerAt(streamsAddress,selectedStream)
  streamView=formatLibrary~structView('AVStream',streamAddress)
  timeBaseNum=streamView~get('time_base_num'); timeBaseDen=streamView~get('time_base_den'); if timeBaseDen=0 then timeBaseDen=1
  codecParameters=codecLibrary~structView('AVCodecParameters',streamView~get('codecpar'))
  codecContext=codecLibrary~alloc_context(decoder)
  if codecLibrary~parameters_to_context(codecContext,codecParameters)<0 then return .false
  if codecLibrary~open_codec(codecContext,decoder,.nil)<0 then return .false
  packet=codecLibrary~packet_alloc; packetView=codecLibrary~structView('AVPacket',packet)
  frame=utilLibrary~frame_alloc; frameView=utilLibrary~structView('AVFrame',frame)
  opened=.true; eof=.false
  return .true

::method nextFrame
  expose opened selectedStream formatLibrary codecLibrary utilLibrary context codecContext packet packetView frame frameView eof
  use arg copyPlane=.true
  if \opened then return .nil
  do forever
    receiveStatus=codecLibrary~receive_frame(codecContext,frame)
    if receiveStatus>=0 then do
      p=frameView~get('pts'); w=frameView~get('width'); h=frameView~get('height'); ls=frameView~get('linesize0'); bytes=''
      if copyPlane & w>0 & h>0 & ls>0 then do
        addr=frameView~get('data0')
        if addr<>0 then bytes=.foreign~peekBytes(addr,ls*h)
      end
      utilLibrary~frame_unref(frame)
      return .FDDecodedFrame~new(p,w,h,ls,bytes)
    end
    if eof then return .nil
    packetReady=.false
    do while \packetReady
      readStatus=formatLibrary~read_frame(context,packet)
      if readStatus<0 then do; eof=.true; leave; end
      if packetView~get('stream_index')=selectedStream then do
        sendStatus=codecLibrary~send_packet(codecContext,packet)
        codecLibrary~packet_unref(packet)
        if sendStatus>=0 then packetReady=.true
      end
      else codecLibrary~packet_unref(packet)
    end
    if eof & \packetReady then return .nil
  end

::method seekPts
  expose opened selectedStream formatLibrary codecLibrary context codecContext packet frame utilLibrary eof
  use strict arg targetPts
  if \opened then return .false
  rc=formatLibrary~seek_frame(context,selectedStream,trunc(targetPts),1) /* AVSEEK_FLAG_BACKWARD */
  if rc<0 then return .false
  codecLibrary~flush_buffers(codecContext)
  codecLibrary~packet_unref(packet); utilLibrary~frame_unref(frame); eof=.false
  return .true

::method close
  expose opened formatLibrary codecLibrary utilLibrary context formatView streamView codecParameters codecContext decoder packet packetView frame frameView
  if \opened then return .true
  if packetView \== .nil then packetView~close
  if packet \== .nil then packet~close
  if frameView \== .nil then frameView~close
  if frame \== .nil then frame~close
  if codecParameters \== .nil then codecParameters~close
  if streamView \== .nil then streamView~close
  if formatView \== .nil then formatView~close
  if codecContext \== .nil then codecContext~close
  if decoder \== .nil then decoder~close
  if context \== .nil then context~close
  if utilLibrary \== .nil then utilLibrary~close
  if codecLibrary \== .nil then codecLibrary~close
  if formatLibrary \== .nil then formatLibrary~close
  opened=.false
  return .true


::class FDReferenceFrameReader public
::method readAtMs class
  use strict arg sourcePath,targetMs,formatBridge='camera_ffmpeg_avformat.bridge.json',codecBridge='camera_ffmpeg_avcodec.bridge.json',utilBridge='camera_ffmpeg_avutil.bridge.json'
  dec=.FDVideoDecoder~new(sourcePath,formatBridge,codecBridge,utilBridge)
  if \dec~open then return .nil
  first=dec~nextFrame(.false)
  if first==.nil then do; dec~close; return .nil; end
  origin=first~pts
  targetPts=origin + ((targetMs*dec~timeBaseDen)/(dec~timeBaseNum*1000))
  if \dec~seekPts(targetPts) then do; dec~close; return .nil; end
  selected=.nil
  do forever
    f=dec~nextFrame(.true)
    if f==.nil then leave
    if f~pts>=targetPts then do; selected=f; leave; end
  end
  dec~close
  return selected


::class FDControlFile public
::constant SCHEMA 'FD_MIGRATION_CONTROL_V1'
::method write class
  use strict arg path,state
  out=.CSVStream~new(path,.false); out~delimiter='09'x; out~open('write replace')
  if out~state<>'READY' then raise syntax 88.900 array('cannot write FD control file',path)
  out~csvLineOut(.array~of('schema','key','value'))
  keys=.array~new; do k over state~values~allIndexes; keys~append(k~string); end; keys~sort
  do k over keys; out~csvLineOut(.array~of(self~SCHEMA,k,state~values[k])); end
  out~close
  return path
::method read class
  use strict arg path
  if stream(path,'C','QUERY EXISTS')=='' then return .nil
  state=.FDCheckpointState~new
  inp=.CSVStream~new(path,.false); inp~delimiter='09'x; inp~open('read')
  if inp~state<>'READY' then return .nil
  first=.true
  do while inp~chars>0
    row=inp~csvLineIn
    if row==.nil | row~items=0 then iterate
    if first then do; first=.false; iterate; end
    /* Preserve an intentionally empty final value.  CSVStream can represent
       that as a two-item row after parsing a trailing empty TSV field. */
    if row~items<2 then do; inp~close; return .nil; end
    if row[1]<>self~SCHEMA then do; inp~close; return .nil; end
    value=''
    if row~items>=3 then value=row[3]
    state~put(row[2],value)
  end
  inp~close
  return state


/* Stateful worker. Every decoded frame boundary is a migration-safe logical
 * boundary; external pause requests are polled at a bounded cadence and are
 * honoured only after the current frame's evidence has been committed. */
::class FDDoorMicroMotionWorker public
::attribute runStatus get
::attribute lastCheckpointPath get

::method init
  expose sourcePath sourceName config outputPrefix stateDir sourceEvidenceRef formatBridge codecBridge utilBridge geometryModel fingerprint decoder writer eventAcc noise decodedFrames eligibleFrames analysedFrames excludedFrames samplesEmitted epochNo relocationNo exclusionNo checkpointGeneration partNo originSet originPts lastPts lastMs timeBaseNum timeBaseDen geometryState previousGeometry stableCount reacquireCounter currentEpoch currentRelocation currentExclusion previousValid prevGlobalX prevGlobalY prevDoorUpperRel prevDoorLowerRel prevFloorL prevFloorR prevFloorValid locatorValidationCounter runStatus lastCheckpointPath lastPauseRequestId resumeCheckpointPath discardUntilPts
  use strict arg sourceArg,cfg,prefixArg,stateDirArg,sourceEvidenceArg='',resumePath='',formatArg='camera_ffmpeg_avformat.bridge.json',codecArg='camera_ffmpeg_avcodec.bridge.json',utilArg='camera_ffmpeg_avutil.bridge.json'
  sourcePath=sourceArg~string; config=cfg; outputPrefix=prefixArg~string; stateDir=stateDirArg~string; sourceEvidenceRef=sourceEvidenceArg~string
  resumeCheckpointPath=resumePath~string; formatBridge=formatArg~string; codecBridge=codecArg~string; utilBridge=utilArg~string
  if sourcePath='' | outputPrefix='' | stateDir='' then raise syntax 88.900 array('source, output prefix and state directory are required')
  sourceName=self~baseName(sourcePath)
  geometryModel=.FDNightDoorGeometryModel~new(config); fingerprint=.nil; decoder=.nil; writer=.nil; eventAcc=.FDEventAccumulator~new(config~eventGapMs); noise=.FDNoiseModel~new
  decodedFrames=0; eligibleFrames=0; analysedFrames=0; excludedFrames=0; samplesEmitted=0; epochNo=0; relocationNo=0; exclusionNo=0; checkpointGeneration=0; partNo=0
  originSet=.false; originPts=0; lastPts=0; lastMs=0; timeBaseNum=0; timeBaseDen=1
  geometryState='ACQUIRING'; previousGeometry=.nil; stableCount=0; reacquireCounter=0; currentEpoch=.nil; currentRelocation=.nil; currentExclusion=.nil
  previousValid=.false; prevGlobalX=0; prevGlobalY=0; prevDoorUpperRel=0; prevDoorLowerRel=0; prevFloorL=0; prevFloorR=0; prevFloorValid=.false
  locatorValidationCounter=0; runStatus='INIT'; lastCheckpointPath=''; lastPauseRequestId=''; discardUntilPts=''

::method baseName private
  use strict arg path
  name=path; last=0
  do i=1 to name~length
    ch=name~substr(i,1); if ch='/' | ch='\\' then last=i
  end
  if last>0 then name=name~substr(last+1)
  return name

::method ensureStateDir private
  expose stateDir
  q=self~shellQuote(stateDir)
  address system 'mkdir -p '||q
  if rc<>0 then raise syntax 88.900 array('cannot create FD state directory',stateDir)

::method shellQuote private
  use strict arg text
  /* POSIX single-quote escaping: ' -> '\'' */
  return "'"||text~changestr("'","'\\''")||"'"

::method boolText private
  use strict arg v
  if v==.true then return '1'
  return '0'

::method textBool private
  use strict arg v
  return v='1' | v~caselessEquals('TRUE')

::method newEdge private
  use strict arg position,score,signed,valid
  return .FDEdgeMeasurement~new(position+0,score+0,signed+0,self~textBool(valid))


::method putEdge private
  use strict arg st,prefix,m
  if m==.nil then do
    st~put(prefix||'_valid','0'); st~put(prefix||'_position','0'); st~put(prefix||'_score','0'); st~put(prefix||'_signed','0'); return
  end
  st~put(prefix||'_valid',self~boolText(m~valid)); st~put(prefix||'_position',m~position); st~put(prefix||'_score',m~score); st~put(prefix||'_signed',m~signedScore)

::method getEdge private
  use strict arg st,prefix
  return self~newEdge(st~get(prefix||'_position','0'),st~get(prefix||'_score','0'),st~get(prefix||'_signed','0'),st~get(prefix||'_valid','0'))

::method snapshotState
  expose sourcePath sourceName config outputPrefix stateDir sourceEvidenceRef fingerprint decodedFrames eligibleFrames analysedFrames excludedFrames samplesEmitted epochNo relocationNo exclusionNo checkpointGeneration partNo originSet originPts lastPts lastMs timeBaseNum timeBaseDen geometryState previousGeometry stableCount reacquireCounter currentEpoch currentRelocation currentExclusion previousValid prevGlobalX prevGlobalY prevDoorUpperRel prevDoorLowerRel prevFloorL prevFloorR prevFloorValid locatorValidationCounter eventAcc noise lastPauseRequestId
  st=.FDCheckpointState~new
  st~put('version',.FDDoorMicroMotionVersion~VERSION); st~put('api',.FDDoorMicroMotionVersion~API); st~put('migration_api',.FDDoorMicroMotionVersion~MIGRATION_API)
  st~put('source_path',sourcePath); st~put('source_name',sourceName); st~put('source_evidence_ref',sourceEvidenceRef); st~put('output_prefix',outputPrefix); st~put('output_base_name',self~baseName(outputPrefix)); st~put('state_dir',stateDir); st~put('config',config~compactText)
  st~put('analysis_start_ms',config~analysisStartMs); st~put('analysis_end_ms',config~analysisEndMs); st~put('wall_clock_origin',config~wallClockOrigin); st~put('analysis_wall_start',config~analysisWallStart); st~put('analysis_wall_end',config~analysisWallEnd)
  st~put('decoded_frames',decodedFrames); st~put('eligible_frames',eligibleFrames); st~put('analysed_frames',analysedFrames); st~put('excluded_frames',excludedFrames); st~put('samples_emitted',samplesEmitted)
  st~put('epoch_no',epochNo); st~put('relocation_no',relocationNo); st~put('exclusion_no',exclusionNo); st~put('checkpoint_generation',checkpointGeneration); st~put('part_no',partNo)
  st~put('origin_set',self~boolText(originSet)); st~put('origin_pts',originPts); st~put('last_pts',lastPts); st~put('last_ms',lastMs); st~put('time_base_num',timeBaseNum); st~put('time_base_den',timeBaseDen)
  st~put('geometry_state',geometryState); st~put('stable_count',stableCount); st~put('reacquire_counter',reacquireCounter); st~put('locator_validation_counter',locatorValidationCounter); st~put('previous_valid',self~boolText(previousValid))
  st~put('prev_global_x',prevGlobalX); st~put('prev_global_y',prevGlobalY); st~put('prev_door_upper_rel',prevDoorUpperRel); st~put('prev_door_lower_rel',prevDoorLowerRel); st~put('prev_floor_l',prevFloorL); st~put('prev_floor_r',prevFloorR); st~put('prev_floor_valid',self~boolText(prevFloorValid))
  st~put('noise_count',noise~count); st~put('noise_global_mean',noise~globalMean); st~put('noise_global_m2',noise~globalM2); st~put('noise_door_mean',noise~doorMean); st~put('noise_door_m2',noise~doorM2)
  st~put('event_active',self~boolText(eventAcc~active)); st~put('event_class',eventAcc~currentClass); st~put('event_start_ms',eventAcc~startMs); st~put('event_peak_ms',eventAcc~peakMs); st~put('event_end_ms',eventAcc~endMs); st~put('event_epoch_id',eventAcc~epochId); st~put('event_peak_global',eventAcc~peakGlobal); st~put('event_peak_door',eventAcc~peakDoor); st~put('event_probe_agreement',eventAcc~probeAgreement); st~put('event_sample_count',eventAcc~sampleCount); st~put('event_last_ms',eventAcc~lastMs); st~put('event_no',eventAcc~eventNo)
  st~put('last_pause_request_id',lastPauseRequestId)
  if fingerprint \== .nil then do
    st~put('fingerprint_present','1'); st~put('fp_panel_x',fingerprint~panelX); st~put('fp_door_x',fingerprint~doorX); st~put('fp_frame_x',fingerprint~frameX); st~put('fp_panel_sign',fingerprint~panelSign); st~put('fp_door_sign',fingerprint~doorSign); st~put('fp_frame_sign',fingerprint~frameSign); st~put('fp_width',fingerprint~referenceWidth); st~put('fp_score',fingerprint~score); st~put('fp_appearance_contrast',fingerprint~appearanceContrast)
  end
  else st~put('fingerprint_present','0')
  if previousGeometry \== .nil then do
    st~put('previous_geometry_present','1'); st~put('previous_panel_x',previousGeometry['PANEL_X']); st~put('previous_locator_score',previousGeometry['LOCATOR_SCORE'])
    self~putEdge(st,'prev_door_up',previousGeometry['DOOR_UP']); self~putEdge(st,'prev_door_lo',previousGeometry['DOOR_LO']); self~putEdge(st,'prev_frame_up',previousGeometry['FRAME_UP']); self~putEdge(st,'prev_frame_lo',previousGeometry['FRAME_LO']); self~putEdge(st,'prev_floor_l_edge',previousGeometry['FLOOR_L']); self~putEdge(st,'prev_floor_r_edge',previousGeometry['FLOOR_R'])
  end
  else st~put('previous_geometry_present','0')
  if currentEpoch \== .nil then do
    st~put('epoch_present','1'); st~put('epoch_id',currentEpoch~id); st~put('epoch_start_ms',currentEpoch~startMs); st~put('epoch_end_ms',currentEpoch~endMs); st~put('epoch_pose',currentEpoch~pose); st~put('epoch_stable_samples',currentEpoch~stableSamples); st~put('epoch_panel_x',currentEpoch~panelAnchorX); st~put('epoch_door_x',currentEpoch~doorAnchorX); st~put('epoch_frame_x',currentEpoch~frameAnchorX); st~put('epoch_locator_score',currentEpoch~locatorScore)
  end
  else st~put('epoch_present','0')
  if currentRelocation \== .nil then do
    st~put('relocation_present','1'); st~put('relocation_id',currentRelocation~id); st~put('relocation_start_ms',currentRelocation~startMs); st~put('relocation_end_ms',currentRelocation~endMs); st~put('relocation_reason',currentRelocation~reason); st~put('relocation_from_epoch',currentRelocation~fromEpoch); st~put('relocation_to_epoch',currentRelocation~toEpoch)
  end
  else st~put('relocation_present','0')
  if currentExclusion \== .nil then do
    st~put('exclusion_present','1'); st~put('active_exclusion_id',currentExclusion~id); st~put('active_exclusion_start_ms',currentExclusion~startMs); st~put('active_exclusion_end_ms',currentExclusion~endMs); st~put('active_exclusion_reason',currentExclusion~reason); st~put('active_exclusion_frames',currentExclusion~skippedFrames)
  end
  else st~put('exclusion_present','0')
  return st

::method restoreState private
  expose sourcePath sourceName config outputPrefix stateDir sourceEvidenceRef fingerprint decodedFrames eligibleFrames analysedFrames excludedFrames samplesEmitted epochNo relocationNo exclusionNo checkpointGeneration partNo originSet originPts lastPts lastMs timeBaseNum timeBaseDen geometryState previousGeometry stableCount reacquireCounter currentEpoch currentRelocation currentExclusion previousValid prevGlobalX prevGlobalY prevDoorUpperRel prevDoorLowerRel prevFloorL prevFloorR prevFloorValid locatorValidationCounter eventAcc noise lastPauseRequestId resumeCheckpointPath
  st=.FDCheckpointState~read(resumeCheckpointPath)
  if st~require('version')<>.FDDoorMicroMotionVersion~VERSION then raise syntax 88.900 array('checkpoint executable revision mismatch',st~get('version'))
  checkpointSource=st~require('source_path')
  checkpointEvidence=st~get('source_evidence_ref','')
  if st~get('source_name','')<>sourceName then raise syntax 88.900 array('checkpoint source filename mismatch')
  if checkpointSource<>sourcePath then do
    /* Cross-node path rebasing is legal only when both sides carry the same
       strong source-evidence reference.  A mere filename is never enough. */
    if sourceEvidenceRef='' | checkpointEvidence='' | sourceEvidenceRef<>checkpointEvidence then raise syntax 88.900 array('checkpoint source path changed without matching source evidence')
  end
  if st~require('config')<>config~compactText then raise syntax 88.900 array('checkpoint config mismatch')
  if sourceEvidenceRef<>'' & checkpointEvidence<>'' & sourceEvidenceRef<>checkpointEvidence then raise syntax 88.900 array('checkpoint source evidence mismatch')
  if sourceEvidenceRef='' then sourceEvidenceRef=checkpointEvidence
  expectedBase=st~get('output_base_name',self~baseName(st~require('output_prefix')))
  if self~baseName(outputPrefix)<>expectedBase then raise syntax 88.900 array('checkpoint logical output-prefix mismatch')
  decodedFrames=st~get('decoded_frames','0')+0; eligibleFrames=st~get('eligible_frames','0')+0; analysedFrames=st~get('analysed_frames','0')+0; excludedFrames=st~get('excluded_frames','0')+0; samplesEmitted=st~get('samples_emitted','0')+0
  epochNo=st~get('epoch_no','0')+0; relocationNo=st~get('relocation_no','0')+0; exclusionNo=st~get('exclusion_no','0')+0; checkpointGeneration=st~get('checkpoint_generation','0')+0; partNo=st~get('part_no','0')+0
  originSet=self~textBool(st~get('origin_set','0')); originPts=st~get('origin_pts','0')+0; lastPts=st~get('last_pts','0')+0; lastMs=st~get('last_ms','0')+0; timeBaseNum=st~get('time_base_num','0')+0; timeBaseDen=st~get('time_base_den','1')+0
  geometryState=st~get('geometry_state','ACQUIRING'); stableCount=st~get('stable_count','0')+0; reacquireCounter=st~get('reacquire_counter','0')+0; locatorValidationCounter=st~get('locator_validation_counter','0')+0; previousValid=self~textBool(st~get('previous_valid','0'))
  prevGlobalX=st~get('prev_global_x','0')+0; prevGlobalY=st~get('prev_global_y','0')+0; prevDoorUpperRel=st~get('prev_door_upper_rel','0')+0; prevDoorLowerRel=st~get('prev_door_lower_rel','0')+0; prevFloorL=st~get('prev_floor_l','0')+0; prevFloorR=st~get('prev_floor_r','0')+0; prevFloorValid=self~textBool(st~get('prev_floor_valid','0'))
  noise=.FDNoiseModel~new; noise~count=st~get('noise_count','0')+0; noise~globalMean=st~get('noise_global_mean','0')+0; noise~globalM2=st~get('noise_global_m2','0')+0; noise~doorMean=st~get('noise_door_mean','0')+0; noise~doorM2=st~get('noise_door_m2','0')+0
  eventAcc=.FDEventAccumulator~new(config~eventGapMs); eventAcc~active=self~textBool(st~get('event_active','0')); eventAcc~currentClass=st~get('event_class',''); eventAcc~startMs=st~get('event_start_ms','0')+0; eventAcc~peakMs=st~get('event_peak_ms','0')+0; eventAcc~endMs=st~get('event_end_ms','0')+0; eventAcc~epochId=st~get('event_epoch_id',''); eventAcc~peakGlobal=st~get('event_peak_global','0')+0; eventAcc~peakDoor=st~get('event_peak_door','0')+0; eventAcc~probeAgreement=st~get('event_probe_agreement','0')+0; eventAcc~sampleCount=st~get('event_sample_count','0')+0; eventAcc~lastMs=st~get('event_last_ms','-1')+0; eventAcc~eventNo=st~get('event_no','0')+0
  lastPauseRequestId=st~get('last_pause_request_id','')
  fingerprint=.nil
  if self~textBool(st~get('fingerprint_present','0')) then fingerprint=.FDDoorFingerprint~new(st~get('fp_panel_x')+0,st~get('fp_door_x')+0,st~get('fp_frame_x')+0,st~get('fp_panel_sign')+0,st~get('fp_door_sign')+0,st~get('fp_frame_sign')+0,st~get('fp_width')+0,st~get('fp_score')+0,st~get('fp_appearance_contrast','0')+0)
  previousGeometry=.nil
  if self~textBool(st~get('previous_geometry_present','0')) then do
    previousGeometry=.directory~new; previousGeometry['PANEL_X']=st~get('previous_panel_x','0')+0; previousGeometry['LOCATOR_SCORE']=st~get('previous_locator_score','0')+0
    previousGeometry['DOOR_UP']=self~getEdge(st,'prev_door_up'); previousGeometry['DOOR_LO']=self~getEdge(st,'prev_door_lo'); previousGeometry['FRAME_UP']=self~getEdge(st,'prev_frame_up'); previousGeometry['FRAME_LO']=self~getEdge(st,'prev_frame_lo'); previousGeometry['FLOOR_L']=self~getEdge(st,'prev_floor_l_edge'); previousGeometry['FLOOR_R']=self~getEdge(st,'prev_floor_r_edge')
  end
  currentEpoch=.nil
  if self~textBool(st~get('epoch_present','0')) then do
    currentEpoch=.FDGeometryEpoch~new(st~get('epoch_id'),st~get('epoch_start_ms')+0,st~get('epoch_pose'),st~get('epoch_panel_x')+0,st~get('epoch_door_x')+0,st~get('epoch_frame_x')+0,st~get('epoch_locator_score')+0); currentEpoch~endMs=st~get('epoch_end_ms')+0; currentEpoch~stableSamples=st~get('epoch_stable_samples')+0
  end
  currentRelocation=.nil
  if self~textBool(st~get('relocation_present','0')) then do
    currentRelocation=.FDCameraRelocation~new(st~get('relocation_id'),st~get('relocation_start_ms')+0,st~get('relocation_reason'),st~get('relocation_from_epoch')); currentRelocation~endMs=st~get('relocation_end_ms')+0; currentRelocation~toEpoch=st~get('relocation_to_epoch','')
  end
  currentExclusion=.nil
  if self~textBool(st~get('exclusion_present','0')) then do
    currentExclusion=.FDExclusionEvidence~new(st~get('active_exclusion_id'),st~get('active_exclusion_start_ms')+0,st~get('active_exclusion_reason')); currentExclusion~endMs=st~get('active_exclusion_end_ms')+0; currentExclusion~skippedFrames=st~get('active_exclusion_frames')+0
  end
  return st


::method writeRunningMarker private
  expose stateDir sourcePath sourceName partNo checkpointGeneration lastPts lastMs runStatus
  st=.FDCheckpointState~new; st~put('status',runStatus); st~put('source_path',sourcePath); st~put('source_name',sourceName); st~put('part_no',partNo); st~put('checkpoint_generation',checkpointGeneration); st~put('last_pts',lastPts); st~put('last_ms',lastMs)
  .FDControlFile~write(stateDir||'/running.tsv',st)

::method prepare
  expose sourcePath config outputPrefix stateDir sourceEvidenceRef formatBridge codecBridge utilBridge geometryModel fingerprint decoder writer partNo timeBaseNum timeBaseDen resumeCheckpointPath discardUntilPts originSet originPts lastPts runStatus
  self~ensureStateDir
  if stream(sourcePath,'C','QUERY EXISTS')=='' then do; runStatus='SOURCE_NOT_FOUND'; return .false; end
  if resumeCheckpointPath<>'' then self~restoreState
  if fingerprint==.nil & config~referenceMediaMs>=0 then do
    ref=.FDReferenceFrameReader~readAtMs(sourcePath,config~referenceMediaMs,formatBridge,codecBridge,utilBridge)
    if ref \== .nil & ref~plane<>'' then fingerprint=geometryModel~calibrateFingerprint(ref~plane,ref~width,ref~height,ref~lineSize)
    /* Generic multi-file jobs may deliberately defer fingerprint acquisition
       until the first geometrically usable frame in their analysis window. */
  end
  decoder=.FDVideoDecoder~new(sourcePath,formatBridge,codecBridge,utilBridge)
  if \decoder~open then do; runStatus='OPEN_FAILED'; return .false; end
  if resumeCheckpointPath<>'' then do
    if decoder~timeBaseNum<>timeBaseNum | decoder~timeBaseDen<>timeBaseDen then do; runStatus='TIME_BASE_MISMATCH'; decoder~close; return .false; end
    partNo+=1
    writer=.FDShardWriter~new(outputPrefix,partNo,self~baseName(sourcePath))
    prerollPts=(config~decoderPrerollMs*timeBaseDen)/(timeBaseNum*1000)
    target=lastPts-prerollPts; if target<originPts then target=originPts
    if \decoder~seekPts(target) then do; runStatus='RESUME_SEEK_FAILED'; writer~close; decoder~close; return .false; end
    discardUntilPts=lastPts
  end
  else do
    timeBaseNum=decoder~timeBaseNum; timeBaseDen=decoder~timeBaseDen
    partNo=1; writer=.FDShardWriter~new(outputPrefix,partNo,self~baseName(sourcePath)); discardUntilPts=''
    if config~analysisStartMs>0 then do
      firstFrame=decoder~nextFrame(.false)
      if firstFrame==.nil then do; runStatus='SOURCE_EMPTY'; writer~close; decoder~close; return .false; end
      originPts=firstFrame~pts; originSet=.true
      targetPts=originPts+((config~analysisStartMs*timeBaseDen)/(timeBaseNum*1000))
      if \decoder~seekPts(targetPts) then do; runStatus='WINDOW_SEEK_FAILED'; writer~close; decoder~close; return .false; end
    end
  end
  runStatus='RUNNING'; self~writeRunningMarker
  return .true

::method closeCurrentEpoch private
  expose currentEpoch writer
  if currentEpoch==.nil then return .false
  writer~writeEpoch(currentEpoch); currentEpoch=.nil
  return .true

::method closeCurrentRelocation private
  expose currentRelocation writer lastMs
  use arg toEpoch=''
  if currentRelocation==.nil then return .false
  currentRelocation~close(lastMs,toEpoch); writer~writeRelocation(currentRelocation); currentRelocation=.nil
  return .true

::method beginRelocation private
  expose geometryState currentEpoch currentRelocation relocationNo writer eventAcc lastMs previousGeometry stableCount reacquireCounter previousValid noise prevFloorValid
  use strict arg reason
  fromId=''
  if currentEpoch \== .nil then do; fromId=currentEpoch~id; self~closeCurrentEpoch; end
  eventAcc~flush(writer)
  if currentRelocation==.nil then do
    relocationNo+=1; currentRelocation=.FDCameraRelocation~new('FDR'||right(relocationNo,5,'0'),lastMs,reason,fromId)
  end
  geometryState='RELOCATING'; previousGeometry=.nil; stableCount=0; reacquireCounter=0; previousValid=.false; prevFloorValid=.false; noise=.FDNoiseModel~new
  return .true

::method enterExclusion private
  expose currentExclusion exclusionNo geometryState currentEpoch currentRelocation writer eventAcc lastMs previousGeometry stableCount reacquireCounter previousValid noise prevFloorValid
  use strict arg exclusion
  if currentExclusion \== .nil then return .true
  if currentEpoch \== .nil then self~closeCurrentEpoch
  eventAcc~flush(writer)
  if currentRelocation \== .nil then self~closeCurrentRelocation('')
  exclusionNo+=1
  currentExclusion=.FDExclusionEvidence~new(exclusion~id,lastMs,exclusion~reason)
  geometryState='EXCLUDED'; previousGeometry=.nil; stableCount=0; reacquireCounter=0; previousValid=.false; prevFloorValid=.false; noise=.FDNoiseModel~new
  return .true

::method exitExclusion private
  expose currentExclusion writer geometryState previousGeometry stableCount reacquireCounter previousValid noise prevFloorValid
  if currentExclusion==.nil then return .false
  writer~writeExclusion(currentExclusion); currentExclusion=.nil
  geometryState='ACQUIRING'; previousGeometry=.nil; stableCount=0; reacquireCounter=0; previousValid=.false; prevFloorValid=.false; noise=.FDNoiseModel~new
  return .true

::method processFrame private
  expose config geometryModel fingerprint writer eventAcc noise analysedFrames samplesEmitted epochNo currentEpoch currentRelocation geometryState previousGeometry stableCount reacquireCounter previousValid prevGlobalX prevGlobalY prevDoorUpperRel prevDoorLowerRel prevFloorL prevFloorR prevFloorValid locatorValidationCounter lastMs lastPts
  use strict arg f
  analysedFrames+=1
  plane=f~plane; width=f~width; height=f~height; lineSize=f~lineSize
  if plane='' | width<=0 | height<=0 | lineSize<=0 then return .false

  if fingerprint==.nil then do
    reacquireCounter+=1
    if (reacquireCounter//4)<>1 then return .false
    candidateFp=geometryModel~calibrateFingerprint(plane,width,height,lineSize)
    if candidateFp==.nil then return .false
    fingerprint=candidateFp; previousGeometry=.nil; stableCount=0; reacquireCounter=0; geometryState='ACQUIRING'
  end

  if geometryState<>'STABLE' then do
    if previousGeometry==.nil then do
      reacquireCounter+=1
      if (reacquireCounter//4)<>1 then return .false
      anchor=geometryModel~locateDoor(plane,width,height,lineSize,fingerprint)
      if anchor==.nil then do; stableCount=0; return .false; end
      geometry=geometryModel~acquireTrackedGeometry(plane,width,height,lineSize,anchor)
      if \geometryModel~validGeometry(geometry) then do; stableCount=0; previousGeometry=.nil; return .false; end
      stableCount=1; previousGeometry=geometry
    end
    else do
      geometry=geometryModel~trackGeometry(plane,width,height,lineSize,previousGeometry)
      if \geometryModel~validGeometry(geometry) then do; stableCount=0; previousGeometry=.nil; return .false; end
      oldFrame=(previousGeometry['FRAME_UP']~position+previousGeometry['FRAME_LO']~position)/2
      newFrame=(geometry['FRAME_UP']~position+geometry['FRAME_LO']~position)/2
      oldDoor=(previousGeometry['DOOR_UP']~position+previousGeometry['DOOR_LO']~position)/2
      newDoor=(geometry['DOOR_UP']~position+geometry['DOOR_LO']~position)/2
      if abs(newFrame-oldFrame)<=2.0 & abs(newDoor-oldDoor)<=2.0 then stableCount+=1
      else stableCount=1
      previousGeometry=geometry
    end
    if stableCount>=config~relocationStableFrames then do
      epochNo+=1
      currentEpoch=.FDGeometryEpoch~new('FDE'||right(epochNo,5,'0'),lastMs,'NIGHT_IR_DYNAMIC',geometry['PANEL_X'],(geometry['DOOR_UP']~position+geometry['DOOR_LO']~position)/2,(geometry['FRAME_UP']~position+geometry['FRAME_LO']~position)/2,geometry['LOCATOR_SCORE'])
      if currentRelocation \== .nil then self~closeCurrentRelocation(currentEpoch~id)
      geometryState='STABLE'; noise=.FDNoiseModel~new; previousValid=.false; prevFloorValid=.false; locatorValidationCounter=0
    end
    return .true
  end

  geometry=geometryModel~trackGeometry(plane,width,height,lineSize,previousGeometry)
  if \geometryModel~validGeometry(geometry) then do; self~beginRelocation('DOOR_GEOMETRY_LOST'); return .false; end
  currentFrameX=(geometry['FRAME_UP']~position+geometry['FRAME_LO']~position)/2
  currentDoorX=(geometry['DOOR_UP']~position+geometry['DOOR_LO']~position)/2
  if currentEpoch \== .nil then do
    if abs(currentFrameX-currentEpoch~frameAnchorX)>config~relocationPixels | abs(currentDoorX-currentEpoch~doorAnchorX)>config~relocationPixels then do; self~beginRelocation('LARGE_FIELD_OF_VIEW_CHANGE'); return .false; end
  end

  if config~locatorValidationFrames>0 then do
    locatorValidationCounter+=1
    if locatorValidationCounter>=config~locatorValidationFrames then do
      locatorValidationCounter=0
      checkAnchor=geometryModel~locateDoor(plane,width,height,lineSize,fingerprint)
      if checkAnchor \== .nil then do
        if abs(checkAnchor~frameX-currentFrameX)>config~relocationPixels | abs(checkAnchor~doorX-currentDoorX)>config~relocationPixels then do; self~beginRelocation('DOOR_REACQUISITION_SHIFT'); return .false; end
        geometry['LOCATOR_SCORE']=checkAnchor~score
      end
    end
  end

  currentEpoch~touch(lastMs)
  globalX=currentFrameX
  doorUpperRel=geometry['DOOR_UP']~position-geometry['FRAME_UP']~position
  doorLowerRel=geometry['DOOR_LO']~position-geometry['FRAME_LO']~position
  floorValid=geometry['FLOOR_L']~valid & geometry['FLOOR_R']~valid
  if floorValid then globalY=(geometry['FLOOR_L']~position+geometry['FLOOR_R']~position)/2
  else globalY=prevGlobalY

  if previousValid then do
    frameUStep=geometry['FRAME_UP']~position-previousGeometry['FRAME_UP']~position
    frameLStep=geometry['FRAME_LO']~position-previousGeometry['FRAME_LO']~position
    gdx=globalX-prevGlobalX
    if floorValid & prevFloorValid then do
      floorLStep=geometry['FLOOR_L']~position-prevFloorL; floorRStep=geometry['FLOOR_R']~position-prevFloorR; gdy=globalY-prevGlobalY
    end
    else do; floorLStep=0; floorRStep=0; gdy=0; end
    doorUStep=doorUpperRel-prevDoorUpperRel; doorLStep=doorLowerRel-prevDoorLowerRel
    gmag=FDSqrt((gdx*gdx)+(gdy*gdy)); dmag=(abs(doorUStep)+abs(doorLStep))/2
    gth=config~minimumGlobalStepPixels; dth=config~minimumDoorResidualPixels
    if noise~count>=config~calibrationFrames then do
      x=config~sigmaMultiplier*noise~globalSigma; if x>gth then gth=x
      x=config~sigmaMultiplier*noise~doorSigma; if x>dth then dth=x
    end
    coherentX=(abs(frameUStep)>=gth & abs(frameLStep)>=gth & (frameUStep*frameLStep)>0 & abs(frameUStep-frameLStep)<=FDMax(0.30,gth*2.0))
    coherentY=.false
    if floorValid & prevFloorValid then coherentY=(abs(floorLStep)>=gth & abs(floorRStep)>=gth & (floorLStep*floorRStep)>0 & abs(floorLStep-floorRStep)<=FDMax(0.30,gth*2.0))
    coherentDoor=(abs(doorUStep)>=dth & abs(doorLStep)>=dth & (doorUStep*doorLStep)>0 & abs(doorUStep-doorLStep)<=FDMax(0.35,dth*2.5))
    globalCandidate=(coherentX | coherentY); doorCandidate=(dmag>=dth & coherentDoor); combinedCandidate=(globalCandidate & doorCandidate)
    agree=0
    if abs(frameUStep)>=gth then agree+=1; if abs(frameLStep)>=gth then agree+=1
    if floorValid & prevFloorValid then do; if abs(floorLStep)>=gth then agree+=1; if abs(floorRStep)>=gth then agree+=1; end
    if abs(doorUStep)>=dth then agree+=1; if abs(doorLStep)>=dth then agree+=1
    sample=.FDMicroSample~new(samplesEmitted+1,lastMs,lastPts,currentEpoch~id,geometryState,geometry['FRAME_UP']~position,geometry['FRAME_LO']~position,geometry['DOOR_UP']~position,geometry['DOOR_LO']~position,geometry['FLOOR_L']~position,geometry['FLOOR_R']~position,gdx,gdy,doorUStep,doorLStep,gmag,dmag,gth,dth,coherentX,coherentY,coherentDoor,globalCandidate,doorCandidate,combinedCandidate,agree,geometry['LOCATOR_SCORE'],geometry['FRAME_UP']~score,geometry['FRAME_LO']~score,geometry['DOOR_UP']~score,geometry['DOOR_LO']~score)
    writer~writeSample(sample); samplesEmitted+=1; eventAcc~consume(sample,writer)
    quietFixed=(abs(frameUStep-frameLStep)<=0.30 & abs(frameUStep)<=0.75 & abs(frameLStep)<=0.75)
    quietDoor=(abs(doorUStep-doorLStep)<=0.35 & abs(doorUStep)<=0.75 & abs(doorLStep)<=0.75)
    quietFloor=.true
    if floorValid & prevFloorValid then quietFloor=(abs(floorLStep-floorRStep)<=0.30 & abs(floorLStep)<=0.75 & abs(floorRStep)<=0.75)
    if \globalCandidate & \doorCandidate & quietFixed & quietDoor & quietFloor then noise~add(gmag,dmag)
  end

  prevGlobalX=globalX; prevGlobalY=globalY; prevDoorUpperRel=doorUpperRel; prevDoorLowerRel=doorLowerRel
  if floorValid then do; prevFloorL=geometry['FLOOR_L']~position; prevFloorR=geometry['FLOOR_R']~position; prevFloorValid=.true; end
  else prevFloorValid=.false
  previousValid=.true; previousGeometry=geometry
  return .true


::method checkpointForPause private
  expose stateDir writer decoder checkpointGeneration lastPauseRequestId lastCheckpointPath runStatus partNo outputPrefix sourceName sourceEvidenceRef lastPts lastMs
  use strict arg ctl
  requestId=ctl~get('request_id','')
  if requestId='' then requestId='pause-'||(checkpointGeneration+1)
  lastPauseRequestId=requestId; checkpointGeneration+=1
  writer~close
  partsManifest=.FDShardWriter~writePartsManifest(outputPrefix,partNo,sourceName,'CLOSED')
  st=self~snapshotState
  checkpointId=ctl~get('checkpoint_id','FDCK'||right(checkpointGeneration,6,'0'))
  migrationId=ctl~get('migration_id',''); jobId=ctl~get('job_id','')
  st~put('pause_request_id',requestId); st~put('migration_id',migrationId); st~put('job_id',jobId); st~put('checkpoint_id',checkpointId); st~put('source_node_id',ctl~get('source_node_id','')); st~put('source_placement_id',ctl~get('source_placement_id','')); st~put('source_ownership_epoch',ctl~get('source_ownership_epoch','0')); st~put('pause_requested_epoch_ms',ctl~get('now_epoch_ms','0'))
  finalPath=stateDir||'/checkpoint.'||right(checkpointGeneration,6,'0')||'.tsv'; tmpPath=finalPath||'.tmp'
  st~write(tmpPath)
  address system 'mv -f '||self~shellQuote(tmpPath)||' '||self~shellQuote(finalPath)
  if rc<>0 then do; runStatus='CHECKPOINT_RENAME_FAILED'; decoder~close; return .false; end
  lastCheckpointPath=finalPath

  /* The transfer object is one uncompressed, SHA-256-bound byte stream.  It
     contains the checkpoint plus every immutable evidence shard committed up
     to this safe frame boundary.  Storage Fabric can therefore resume/copy one
     object without losing pre-migration evidence. */
  bundlePath=stateDir||'/checkpoint.'||right(checkpointGeneration,6,'0')||'.fdmjob.tar'
  bundleDigest=.FDMigrationBundle~create(bundlePath,finalPath,outputPrefix,partNo,sourceName,requestId,migrationId,jobId,checkpointId)
  outputEvidence='fd-shards:'||partNo||':'||bundleDigest

  paused=.FDCheckpointState~new
  paused~put('status','PAUSED'); paused~put('request_id',requestId); paused~put('checkpoint_path',finalPath); paused~put('checkpoint_generation',checkpointGeneration); paused~put('part_no',partNo); paused~put('last_pts',lastPts); paused~put('last_ms',lastMs); paused~put('job_id',jobId); paused~put('migration_id',migrationId); paused~put('checkpoint_id',checkpointId)
  paused~put('checkpoint_transfer_ref',bundlePath); paused~put('checkpoint_state_ref',bundlePath); paused~put('checkpoint_state_digest',bundleDigest); paused~put('input_evidence_ref',sourceEvidenceRef); paused~put('output_evidence_ref',outputEvidence); paused~put('parts_manifest_path',partsManifest)
  paused~put('source_node_id',ctl~get('source_node_id','')); paused~put('source_placement_id',ctl~get('source_placement_id','')); paused~put('source_ownership_epoch',ctl~get('source_ownership_epoch','0')); paused~put('pause_requested_epoch_ms',ctl~get('now_epoch_ms','0'))
  .FDControlFile~write(stateDir||'/paused.tsv',paused)
  runStatus='PAUSED'; decoder~close; self~writeRunningMarker
  return .true

::method pollPause private
  expose stateDir lastPauseRequestId
  path=stateDir||'/pause.request.tsv'
  ctl=.FDControlFile~read(path)
  if ctl==.nil then return .false
  if \ctl~get('command','')~caselessEquals('PAUSE') then return .false
  requestId=ctl~get('request_id','')
  if requestId<>'' & requestId=lastPauseRequestId then return .false
  return self~checkpointForPause(ctl)

::method finish private
  expose writer decoder currentExclusion currentRelocation currentEpoch eventAcc lastMs outputPrefix partNo sourceName sourcePath sourceEvidenceRef config runStatus
  if currentExclusion \== .nil then do; currentExclusion~noteFrame(lastMs); self~exitExclusion; end
  eventAcc~flush(writer)
  if currentEpoch \== .nil then self~closeCurrentEpoch
  if currentRelocation \== .nil then self~closeCurrentRelocation('')
  writer~close; decoder~close
  .FDShardWriter~writePartsManifest(outputPrefix,partNo,sourceName,'COMPLETE')
  .FDShardWriter~mergeAll(outputPrefix,partNo)
  st=self~snapshotState
  runStatus='OK'
  .FDShardWriter~writeRun(outputPrefix,st,runStatus,config~compactText,sourcePath,sourceName,sourceEvidenceRef)
  self~writeRunningMarker
  return runStatus

::method run
  expose config decoder runStatus discardUntilPts originSet originPts lastPts lastMs timeBaseNum timeBaseDen decodedFrames eligibleFrames excludedFrames currentExclusion writer geometryState
  if \self~prepare then return runStatus
  do forever
    f=decoder~nextFrame(.true)
    if f==.nil then leave
    if discardUntilPts<>'' then do
      if f~pts<=discardUntilPts then iterate
      discardUntilPts=''
    end
    if \originSet then do; originPts=f~pts; originSet=.true; end
    candidatePts=f~pts; candidateMs=(candidatePts-originPts)*timeBaseNum*1000/timeBaseDen
    if config~analysisEndMs>=0 & candidateMs>=config~analysisEndMs then leave
    lastPts=candidatePts; lastMs=candidateMs
    decodedFrames+=1

    if lastMs<config~analysisStartMs then do
      if config~controlPollFrames<=1 | (decodedFrames//config~controlPollFrames)=0 then do
        if self~pollPause then return runStatus
      end
      iterate
    end

    exclusion=config~exclusionAt(lastMs)
    if exclusion \== .nil then do
      if currentExclusion==.nil then self~enterExclusion(exclusion)
      currentExclusion~noteFrame(lastMs); excludedFrames+=1
    end
    else do
      if currentExclusion \== .nil then self~exitExclusion
      eligibleFrames+=1
      if ((decodedFrames-1)//config~sampleEveryFrames)=0 then self~processFrame(f)
    end

    if config~controlPollFrames<=1 | (decodedFrames//config~controlPollFrames)=0 then do
      if self~pollPause then return runStatus
    end
    if config~maximumFrames>0 & decodedFrames>=config~maximumFrames then leave
  end
  return self~finish


::requires 'foreign.cls'
