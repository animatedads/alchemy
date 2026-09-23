/* ooRexx Vision 3D Reconstruction v0.1-dev9
 *
 * Native-cadence V5V / Line Assessment -> camera-motion constraints.
 *
 * Governing rule:
 *   every source frame participates in motion planning.  The hot path compares
 *   frame N with frame N+1 at the source timestamps; it must not silently
 *   decimate a ~30 fps source to a coarse 5 fps motion stream.
 *
 * Geometry identity remains conservative.  Line Assessment supplies frame-local
 * runs; VisionNativeLineTracker gives nearby like-oriented runs stable short-term
 * identities so VisionFrameGeometryComparator can compare distances, angles and
 * apparent scale from one native frame to the next.
 */

::class VisionNativeCadencePolicy public
::method init
  expose nominalFps maxFrameGapFactor requireSequentialFrames
  use strict arg nominalFps=30,maxFrameGapFactor=1.60,requireSequentialFrames=.true
  if nominalFps<=0 then raise syntax 40.900 array('nominalFps must be positive')
  if maxFrameGapFactor<1 then raise syntax 40.900 array('maxFrameGapFactor must be >= 1')
::attribute nominalFps get
::attribute maxFrameGapFactor get
::attribute requireSequentialFrames get
::method nominalDt
  expose nominalFps
  return 1/nominalFps

::class VisionNativeCadenceCheck public
::method init
  expose valid dt findings
  use strict arg valid,dt,findings
::attribute valid get
::attribute dt get
::attribute findings get

::class VisionNativeCadenceFeasibility public
::method check
  use strict arg previousFrameIndex,previousTimestamp,currentFrameIndex,currentTimestamp,policy=.nil
  if policy==.nil then policy=.VisionNativeCadencePolicy~new
  findings=.array~new
  dt=currentTimestamp-previousTimestamp
  if dt<=0 then findings~append('NON_POSITIVE_DT')
  if policy~requireSequentialFrames & currentFrameIndex<>previousFrameIndex+1 then -
    findings~append('NON_SEQUENTIAL_FRAME:'||previousFrameIndex||'->'||currentFrameIndex)
  if dt>0 then do
    maxDt=policy~nominalDt*policy~maxFrameGapFactor
    if dt>maxDt then findings~append('NATIVE_FRAME_GAP:'||dt||'>'||maxDt)
  end
  return .VisionNativeCadenceCheck~new(findings~items=0,dt,findings)

::class VisionNativeLineTrackerConfig public
::method init
  expose maxMidpointDistancePx maxLengthRatio minimumRun threshold
  use strict arg maxMidpointDistancePx=12,maxLengthRatio=2.5,minimumRun=3,threshold=2
  if maxMidpointDistancePx<=0 then raise syntax 40.900 array('maxMidpointDistancePx must be positive')
  if maxLengthRatio<=1 then raise syntax 40.900 array('maxLengthRatio must be > 1')
  if minimumRun<1 then raise syntax 40.900 array('minimumRun must be positive')
  if threshold<0 then raise syntax 40.900 array('threshold must be non-negative')
::attribute maxMidpointDistancePx get
::attribute maxLengthRatio get
::attribute minimumRun get
::attribute threshold get

::class VisionNativeLineTracker public
::method init
  expose nextId previousGeometry config
  use strict arg config=.nil
  if config==.nil then config=.VisionNativeLineTrackerConfig~new
  nextId=1; previousGeometry=.nil
::attribute previousGeometry get
::attribute config get

::method reset
  expose nextId previousGeometry
  nextId=1; previousGeometry=.nil; return self

/* Convert frame-local LineAssessment runs into short-term tracked line IDs. */
::method geometryFromAssessment
  expose nextId previousGeometry config
  use strict arg assessment,timestamp
  current=.VisionFrameGeometry~new(timestamp)
  usedPrevious=.directory~new
  runs=.array~new
  do r over assessment~horizontalRuns; runs~append(r); end
  do r over assessment~verticalRuns; runs~append(r); end

  do run over runs
    if run~direction='X' then orientation=90
    else orientation=0
    sx=run~startX; sy=run~startY; ex=run~endX; ey=run~endY
    mx=(sx+ex)/2; my=(sy+ey)/2
    length=max(1,run~length)
    lineId=''
    bestDistance=.nil

    if previousGeometry\==.nil then do id over previousGeometry~lines
      if usedPrevious~hasIndex(id) then iterate
      p=previousGeometry~lines[id]
      if abs(p~orientationDeg-orientation)>1 then iterate
      plength=max(1,p~length)
      ratio=length/plength
      if ratio>config~maxLengthRatio | ratio<1/config~maxLengthRatio then iterate
      dx=mx-p~midX; dy=my-p~midY
      distance=rx_v3nm_sqrt(dx*dx+dy*dy)
      if distance>config~maxMidpointDistancePx then iterate
      if bestDistance==.nil then do
        bestDistance=distance; lineId=id
      end
      else if distance<bestDistance then do
        bestDistance=distance; lineId=id
      end
    end

    if lineId='' then do
      lineId='L'||nextId; nextId=nextId+1
    end
    else usedPrevious[lineId]=1

    confidence=min(1,max(0,run~meanStrength/(run~meanStrength+config~threshold+0.000001)))
    current~addLine(.VisionTrackedImageLine~new(lineId,sx,sy,ex,ey,orientation,confidence,'LINE_ASSESSMENT'))
  end

  previousGeometry=current
  return current

::class VisionNativeMotionDescriptor public
::method init
  expose dx dy lineAngleDeltaDeg expansion parallaxSpreadPx supportCount confidence motionKind
  use strict arg dx=0,dy=0,lineAngleDeltaDeg=0,expansion=0,parallaxSpreadPx=0,supportCount=0,confidence=0,motionKind='UNKNOWN'
::attribute dx get
::attribute dy get
::attribute lineAngleDeltaDeg get
::attribute expansion get
::attribute parallaxSpreadPx get
::attribute supportCount get
::attribute confidence get
::attribute motionKind get

/* Summarise frame-to-frame geometric evidence without turning pixels directly
 * into metres.  Metric translation stays bounded by physical policy until a
 * scale source is available. */
::class VisionNativeMotionInterpreter public
::method interpret
  use strict arg evidence
  sumDx=0; sumDy=0; sumAngle=0; sumExpansion=0; sumW=0; count=0
  magnitudes=.array~new

  do d over evidence~lineDeltas
    w=max(.000001,d~confidence)
    sumDx=sumDx+d~dx*w; sumDy=sumDy+d~dy*w
    sumAngle=sumAngle+d~angleDeltaDeg*w
    sumExpansion=sumExpansion+(d~lengthRatio-1)*w
    sumW=sumW+w; count=count+1
    magnitudes~append(rx_v3nm_sqrt(d~dx*d~dx+d~dy*d~dy))
  end
  do v over evidence~motionVectors
    w=max(.000001,v~confidence)
    sumDx=sumDx+v~dx*w; sumDy=sumDy+v~dy*w
    sumW=sumW+w; count=count+1
    magnitudes~append(v~magnitude)
  end

  if sumW>0 then do
    dx=sumDx/sumW; dy=sumDy/sumW
    angle=sumAngle/sumW; expansion=sumExpansion/sumW
  end
  else do; dx=0; dy=0; angle=0; expansion=0; end

  spread=0
  if magnitudes~items>1 then do
    mean=0
    do m over magnitudes; mean=mean+m; end
    mean=mean/magnitudes~items
    variance=0
    do m over magnitudes; variance=variance+(m-mean)*(m-mean); end
    spread=rx_v3nm_sqrt(variance/magnitudes~items)
  end

  drift=rx_v3nm_sqrt(dx*dx+dy*dy)
  if expansion>.025 & spread>.35 then kind='FORWARD_WITH_PARALLAX'
  else if expansion<-.025 & spread>.35 then kind='BACKWARD_WITH_PARALLAX'
  else if abs(angle)>1.5 then kind='IMAGE_ROTATION'
  else if drift>.75 & spread>.35 then kind='TRANSLATION_OR_YAW'
  else if drift>.35 then kind='SMALL_IMAGE_MOTION'
  else kind='STABLE'

  confidence=min(1,count/8)
  if evidence~confidence<confidence then confidence=evidence~confidence
  return .VisionNativeMotionDescriptor~new(dx,dy,angle,expansion,spread,count,confidence,kind)

::class VisionCameraProjectionHint public
::method init
  expose imageWidthPx horizontalFovDeg
  use strict arg imageWidthPx,horizontalFovDeg=.nil
  if imageWidthPx<=0 then raise syntax 40.900 array('imageWidthPx must be positive')
  if horizontalFovDeg\==.nil then do
    if horizontalFovDeg<=0 then raise syntax 40.900 array('horizontalFovDeg must be positive')
  end
::attribute imageWidthPx get
::attribute horizontalFovDeg get
::method yawFromHorizontalDrift
  expose imageWidthPx horizontalFovDeg
  use strict arg dx
  if horizontalFovDeg==.nil then return .nil
  /* First-order projection hint only.  It is defeasible evidence, not pose authority. */
  return -dx*horizontalFovDeg/imageWidthPx

::class VisionNativeMotionConstraintBuilder public
::method build
  use strict arg evidence,descriptor,previousTimestamp,projection=.nil,motionPolicy=.nil
  if motionPolicy==.nil then motionPolicy=.VisionCameraMotionPolicy~new
  dt=evidence~timestamp-previousTimestamp
  if dt<=0 then raise syntax 40.900 array('motion evidence timestamp must increase')
  physicalDistanceMax=motionPolicy~maxSpeedMps*dt
  physicalTurnMax=motionPolicy~maxAngularRateDps*dt
  minTurn=-physicalTurnMax; maxTurn=physicalTurnMax; preferredTurn=0

  if projection\==.nil then do
    yaw=projection~yawFromHorizontalDrift(descriptor~dx)
    if yaw\==.nil then do
      /* Image drift also contains translation/parallax, therefore retain a wide
       * envelope around the projection-derived suggestion. */
      tolerance=max(2,physicalTurnMax*(1-.55*descriptor~confidence))
      minTurn=max(-physicalTurnMax,yaw-tolerance)
      maxTurn=min(physicalTurnMax,yaw+tolerance)
      preferredTurn=max(min(yaw,physicalTurnMax),-physicalTurnMax)
    end
  end

  select
    when descriptor~motionKind='FORWARD_WITH_PARALLAX' then do
      minBearing=-40; maxBearing=40; preferredBearing=0
    end
    when descriptor~motionKind='BACKWARD_WITH_PARALLAX' then do
      minBearing=-180; maxBearing=180; preferredBearing=180
    end
    when descriptor~motionKind='STABLE' then do
      minBearing=-70; maxBearing=70; preferredBearing=0
    end
    otherwise do
      minBearing=-100; maxBearing=100; preferredBearing=0
    end
  end

  evidenceText='NATIVE_V5V:'||descriptor~motionKind||':DX='||descriptor~dx||':DY='||descriptor~dy||':EXP='||descriptor~expansion||':PAR='||descriptor~parallaxSpreadPx
  return .VisionCameraStepConstraint~new(evidence~sourceRef,evidence~frameIndex,evidence~timestamp,0,physicalDistanceMax,.nil,minTurn,maxTurn,preferredTurn,minBearing,maxBearing,preferredBearing,descriptor~confidence,evidenceText)

::class VisionNativeMotionFrameResult public
::method init
  expose sourceRef frameIndex timestamp assessment geometry motionEvidence descriptor stepConstraint cadenceCheck
  use strict arg sourceRef,frameIndex,timestamp,assessment,geometry,motionEvidence=.nil,descriptor=.nil,stepConstraint=.nil,cadenceCheck=.nil
::attribute sourceRef get
::attribute frameIndex get
::attribute timestamp get
::attribute assessment get
::attribute geometry get
::attribute motionEvidence get
::attribute descriptor get
::attribute stepConstraint get
::attribute cadenceCheck get

/* End-to-end native-frame inner loop for already-decoded VisionSurface frames.
 * VisionNativeFFmpegSource may be configured at the source cadence; this class
 * itself has no FFmpeg dependency. */
::class VisionNativeMotionLoop public
::method init
  expose sourceRef cadencePolicy lineTracker comparator interpreter constraintBuilder previousGeometry previousFrameIndex previousTimestamp projection motionPolicy
  use strict arg sourceRef,cadencePolicy=.nil,lineTracker=.nil,projection=.nil,motionPolicy=.nil
  if cadencePolicy==.nil then cadencePolicy=.VisionNativeCadencePolicy~new
  if lineTracker==.nil then lineTracker=.VisionNativeLineTracker~new
  if motionPolicy==.nil then motionPolicy=.VisionCameraMotionPolicy~new
  comparator=.VisionFrameGeometryComparator~new
  interpreter=.VisionNativeMotionInterpreter~new
  constraintBuilder=.VisionNativeMotionConstraintBuilder~new
  previousGeometry=.nil; previousFrameIndex=.nil; previousTimestamp=.nil

::method process
  expose sourceRef cadencePolicy lineTracker comparator interpreter constraintBuilder previousGeometry previousFrameIndex previousTimestamp projection motionPolicy
  use strict arg surface,frameIndex
  timestamp=surface~timestamp
  if timestamp==.nil then raise syntax 40.900 array('native motion surface requires timestamp')
  assessment=.LineAssessment~assess(surface,lineTracker~config~threshold,surface~valueModel,lineTracker~config~minimumRun)
  geometry=lineTracker~geometryFromAssessment(assessment,timestamp)

  if previousGeometry==.nil then do
    result=.VisionNativeMotionFrameResult~new(sourceRef,frameIndex,timestamp,assessment,geometry)
  end
  else do
    cadence=.VisionNativeCadenceFeasibility~new~check(previousFrameIndex,previousTimestamp,frameIndex,timestamp,cadencePolicy)
    if \cadence~valid then do
      text=''
      do f over cadence~findings; text=text||f||' '; end
      raise syntax 40.900 array('native cadence violation:' text)
    end
    evidence=comparator~compare(previousGeometry,geometry,sourceRef,frameIndex)
    descriptor=interpreter~interpret(evidence)
    constraint=constraintBuilder~build(evidence,descriptor,previousTimestamp,projection,motionPolicy)
    result=.VisionNativeMotionFrameResult~new(sourceRef,frameIndex,timestamp,assessment,geometry,evidence,descriptor,constraint,cadence)
  end
  previousGeometry=geometry; previousFrameIndex=frameIndex; previousTimestamp=timestamp
  return result

::class VisionLayoutHypothesisEvaluation public
::method init
  expose valid sourceRef timeline failedFrameIndex minimumSurvivors findings
  use strict arg valid,sourceRef,timeline,failedFrameIndex=.nil,minimumSurvivors=0,findings=.nil
  if findings==.nil then findings=.array~new
::attribute valid get
::attribute sourceRef get
::attribute timeline get
::attribute failedFrameIndex get
::attribute minimumSurvivors get
::attribute findings get

/* Evaluate one proposed accessible-floor geometry against a native-cadence
 * constraint trace.  A layout dies immediately when any frame has no feasible
 * camera pose. */
::class VisionLayoutHypothesisEvaluator public
::method evaluate
  use strict arg seedCloud,constraints,floor,policy=.nil,config=.nil
  if policy==.nil then policy=.VisionCameraMotionPolicy~new
  if config==.nil then config=.VisionPoseCloudConfig~new
  solver=.VisionPoseCloudSolver~new
  timeline=.VisionPoseCloudTimeline~new(seedCloud~sourceRef)
  timeline~append(seedCloud)
  cloud=seedCloud
  findings=.array~new
  failed=.nil
  do c over constraints
    cloud=solver~propagate(cloud,c,floor,policy,config)
    timeline~append(cloud)
    if cloud~items=0 then do
      failed=c~frameIndex; findings~append('POSE_CLOUD_EMPTY:'||failed); leave
    end
  end
  return .VisionLayoutHypothesisEvaluation~new(failed==.nil,seedCloud~sourceRef,timeline,failed,timeline~minimumSurvivors,findings)

::class VisionDualSourceLayoutEvaluation public
::method init
  expose valid commonFrames minimumPairCount failedAtA failedAtB findings
  use strict arg valid,commonFrames,minimumPairCount,failedAtA=.nil,failedAtB=.nil,findings=.nil
  if findings==.nil then findings=.array~new
::attribute valid get
::attribute commonFrames get
::attribute minimumPairCount get
::attribute failedAtA get
::attribute failedAtB get
::attribute findings get

/* Fuzzy cross-source feasibility. Positive lag means A[lag+i] aligns B[i]. */
::class VisionDualSourceLayoutEvaluator public
::method evaluate
  use strict arg evaluationA,evaluationB,lagFrames,maxSeparationM=2,maxHeadingDifferenceDeg=60
  findings=.array~new
  if \evaluationA~valid then do
    findings~append('SOURCE_A_INVALID')
    return .VisionDualSourceLayoutEvaluation~new(.false,0,0,evaluationA~failedFrameIndex,.nil,findings)
  end
  if \evaluationB~valid then do
    findings~append('SOURCE_B_INVALID')
    return .VisionDualSourceLayoutEvaluation~new(.false,0,0,.nil,evaluationB~failedFrameIndex,findings)
  end

  fa=evaluationA~timeline~frames; fb=evaluationB~timeline~frames
  startA=1; startB=1
  if lagFrames>=0 then startA=1+lagFrames
  else startB=1-lagFrames
  overlap=min(fa~items-startA+1,fb~items-startB+1)
  if overlap<=0 then do
    findings~append('NO_SYNCHRONIZED_OVERLAP')
    return .VisionDualSourceLayoutEvaluation~new(.false,0,0,.nil,.nil,findings)
  end
  common=0; minimumPairs=.nil
  checker=.VisionCommonLayoutFeasibility~new
  do i=0 to overlap-1
    ca=fa[startA+i]; cb=fb[startB+i]
    c=checker~checkSynchronizedClouds(ca,cb,maxSeparationM,maxHeadingDifferenceDeg)
    if \c~valid then do
      findings~append('NO_COMMON_POSE_PAIR:'||ca~frameIndex||':'||cb~frameIndex)
      return .VisionDualSourceLayoutEvaluation~new(.false,common,0,ca~frameIndex,cb~frameIndex,findings)
    end
    common=common+1
    if minimumPairs==.nil then minimumPairs=c~pairCount
    else if c~pairCount<minimumPairs then minimumPairs=c~pairCount
  end
  if minimumPairs==.nil then minimumPairs=0
  return .VisionDualSourceLayoutEvaluation~new(.true,common,minimumPairs,.nil,.nil,findings)


/* Qualification / replay adapter for a previously extracted native-frame
 * motion trace.  The production path is VisionNativeMotionLoop over
 * VisionSurface frames; this adapter lets recorded evidence drive exactly the
 * same pose-cloud contracts without introducing a media decoder dependency. */
::class VisionRecordedMotionTraceAdapter public
::method descriptorFromRow
  use strict arg row
  dx=row['dx']; dy=row['dy']; expansion=row['scale']-1
  spread=row['flow_spread']; confidence=row['confidence']
  drift=rx_v3nm_sqrt(dx*dx+dy*dy)
  if expansion>.025 & spread>.35 then kind='FORWARD_WITH_PARALLAX'
  else if expansion<-.025 & spread>.35 then kind='BACKWARD_WITH_PARALLAX'
  else if abs(row['rotation_deg'])>1.5 then kind='IMAGE_ROTATION'
  else if drift>.75 & spread>.35 then kind='TRANSLATION_OR_YAW'
  else if drift>.35 then kind='SMALL_IMAGE_MOTION'
  else kind='STABLE'
  return .VisionNativeMotionDescriptor~new(dx,dy,row['rotation_deg'],expansion,spread,0,confidence,kind)

::method constraintFromRow
  use strict arg sourceRef,row,projection=.nil,motionPolicy=.nil
  if motionPolicy==.nil then motionPolicy=.VisionCameraMotionPolicy~new
  previousTimestamp=row['timestamp']-row['dt']
  descriptor=self~descriptorFromRow(row)
  evidence=.VisionFrameMotionEvidence~new(sourceRef,row['frame_index'],row['timestamp'],row['dx'],row['dy'],row['rotation_deg'],row['scale']-1,row['confidence'],'RECORDED_NATIVE_5BIT')
  return .VisionNativeMotionConstraintBuilder~new~build(evidence,descriptor,previousTimestamp,projection,motionPolicy)

::method constraintsFromVideoNode
  use strict arg videoNode,limit=.nil,projection=.nil,motionPolicy=.nil
  out=.array~new
  steps=videoNode['steps']
  n=steps~items
  if limit\==.nil then n=min(n,limit)
  do i=1 to n
    out~append(self~constraintFromRow(videoNode['source'],steps[i],projection,motionPolicy))
  end
  return out

::requires 'Vision3DPoseCloud.cls'
::requires 'LineAssessment.cls'

::routine rx_v3nm_sqrt
  use strict arg value
  if value<0 then raise syntax 40.900 array('square root requires non-negative value')
  if value=0 then return 0
  guess=value
  if guess<1 then guess=1
  do i=1 to 40
    next=(guess+value/guess)/2
    if abs(next-guess)<0.000000000001 then return next
    guess=next
  end
  return guess
