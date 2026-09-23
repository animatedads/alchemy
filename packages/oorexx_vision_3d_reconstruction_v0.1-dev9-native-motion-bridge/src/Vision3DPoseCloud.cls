/* ooRexx Vision 3D Reconstruction v0.1-dev8
 *
 * Feasible camera-location cloud propagation.
 *
 * A floor-plan/layout hypothesis is not accepted merely because its walls fit
 * a set of image measurements.  Every native-cadence frame must admit at
 * least one physically reachable camera pose on accessible floor space.  The
 * pose cloud is propagated frame-to-frame, pruned by the hard motion policy,
 * walls/openings, and the observed motion envelope.  Synchronized sources can
 * then be compared without assuming a rigid stereo baseline.
 */

::class VisionCameraStepConstraint public
::method init
  expose sourceRef frameIndex timestamp minDistanceM maxDistanceM preferredDistanceM minTurnDeg maxTurnDeg preferredTurnDeg minBearingOffsetDeg maxBearingOffsetDeg preferredBearingOffsetDeg confidence evidence
  use strict arg sourceRef,frameIndex,timestamp,minDistanceM=0,maxDistanceM=.nil,preferredDistanceM=.nil,minTurnDeg=(-12),maxTurnDeg=12,preferredTurnDeg=0,minBearingOffsetDeg=(-35),maxBearingOffsetDeg=35,preferredBearingOffsetDeg=0,confidence=1,evidence=.nil
  if minDistanceM<0 then raise syntax 40.900 array('minDistanceM must be non-negative')
  if maxDistanceM\==.nil then do
    if maxDistanceM<minDistanceM then raise syntax 40.900 array('maxDistanceM must be >= minDistanceM')
  end
  if minTurnDeg>maxTurnDeg then raise syntax 40.900 array('turn range invalid')
  if minBearingOffsetDeg>maxBearingOffsetDeg then raise syntax 40.900 array('bearing range invalid')
  if confidence<0 | confidence>1 then raise syntax 40.900 array('constraint confidence must be 0..1')
::attribute sourceRef get
::attribute frameIndex get
::attribute timestamp get
::attribute minDistanceM get
::attribute maxDistanceM get
::attribute preferredDistanceM get
::attribute minTurnDeg get
::attribute maxTurnDeg get
::attribute preferredTurnDeg get
::attribute minBearingOffsetDeg get
::attribute maxBearingOffsetDeg get
::attribute preferredBearingOffsetDeg get
::attribute confidence get
::attribute evidence get

::class VisionPoseCloudConfig public
::method init
  expose distanceSamples turnSamples bearingSamples beamWidth scoreDistanceWeight scoreTurnWeight scoreBearingWeight scoreConfidenceWeight
  use strict arg distanceSamples=3,turnSamples=3,bearingSamples=3,beamWidth=160,scoreDistanceWeight=1,scoreTurnWeight=.6,scoreBearingWeight=.35,scoreConfidenceWeight=.25
  if distanceSamples<1 | turnSamples<1 | bearingSamples<1 | beamWidth<1 then raise syntax 40.900 array('pose cloud sample counts and beamWidth must be positive')
::attribute distanceSamples get
::attribute turnSamples get
::attribute bearingSamples get
::attribute beamWidth get
::attribute scoreDistanceWeight get
::attribute scoreTurnWeight get
::attribute scoreBearingWeight get
::attribute scoreConfidenceWeight get

::class VisionPoseCloudCandidate public
::method init
  expose pose score parentIndex transitionCheck evidence cumulativeDistanceM cumulativeAbsTurnDeg
  use strict arg pose,score=0,parentIndex=.nil,transitionCheck=.nil,evidence=.nil,cumulativeDistanceM=0,cumulativeAbsTurnDeg=0
  if \pose~isA(.VisionCameraPoseCandidate) then raise syntax 40.900 array('VisionCameraPoseCandidate required')
::attribute pose get
::attribute score get
::attribute parentIndex get
::attribute transitionCheck get
::attribute evidence get
::attribute cumulativeDistanceM get
::attribute cumulativeAbsTurnDeg get

::class VisionPoseCloudFrame public
::method init
  expose sourceRef frameIndex timestamp candidates generatedCount rejectedCount
  use strict arg sourceRef,frameIndex,timestamp
  candidates=.array~new; generatedCount=0; rejectedCount=0
::attribute sourceRef get
::attribute frameIndex get
::attribute timestamp get
::attribute candidates get
::attribute generatedCount
::attribute rejectedCount
::method addCandidate
  expose candidates
  use strict arg candidate
  if \candidate~isA(.VisionPoseCloudCandidate) then raise syntax 40.900 array('VisionPoseCloudCandidate required')
  candidates~append(candidate); return self
::method items
  expose candidates
  return candidates~items
::method best
  expose candidates
  if candidates~items=0 then return .nil
  best=candidates[1]
  do i=2 to candidates~items
    if candidates[i]~score>best~score then best=candidates[i]
  end
  return best

::class VisionPoseCloudTimeline public
::method init
  expose sourceRef frames
  use strict arg sourceRef
  frames=.array~new
::attribute sourceRef get
::attribute frames get
::method append
  expose frames sourceRef
  use strict arg frame
  if \frame~isA(.VisionPoseCloudFrame) then raise syntax 40.900 array('VisionPoseCloudFrame required')
  if frame~sourceRef<>sourceRef then raise syntax 40.900 array('pose cloud source mismatch')
  if frames~items>0 then do
    if frame~timestamp<=frames[frames~items]~timestamp then raise syntax 40.900 array('pose cloud timestamps must increase')
  end
  frames~append(frame); return self
::method valid
  expose frames
  if frames~items=0 then return .false
  do f over frames
    if f~items=0 then return .false
  end
  return .true
::method minimumSurvivors
  expose frames
  if frames~items=0 then return 0
  n=frames[1]~items
  do f over frames; n=min(n,f~items); end
  return n

/* Sliding-window angular feasibility.  The current qualification rule is a
 * conservative 72 degrees per roughly 0.2 seconds (six frames at 30 fps).
 * Using timestamps keeps it correct for 29.97 / 30.04 fps sources. */
::class VisionCameraTurnWindowPolicy public
::method init
  expose windowSeconds maxAbsTurnDeg
  use strict arg windowSeconds=.2,maxAbsTurnDeg=72
  if windowSeconds<=0 | maxAbsTurnDeg<=0 then raise syntax 40.900 array('turn window policy values must be positive')
::attribute windowSeconds get
::attribute maxAbsTurnDeg get

::class VisionCameraTurnWindowCheck public
::method init
  expose valid maxObservedAbsTurnDeg findings
  use strict arg valid,maxObservedAbsTurnDeg,findings
::attribute valid get
::attribute maxObservedAbsTurnDeg get
::attribute findings get

::class VisionCameraTurnWindowFeasibility public
::method checkPoses
  use strict arg poses,windowPolicy=.nil
  if windowPolicy==.nil then windowPolicy=.VisionCameraTurnWindowPolicy~new
  findings=.array~new
  if poses~items<2 then return .VisionCameraTurnWindowCheck~new(.true,0,findings)
  helper=.VisionCameraPathFeasibility~new
  maxObserved=0
  do start=1 to poses~items-1
    totalTurn=0
    startTime=poses[start]~timestamp
    do i=start+1 to poses~items
      if poses[i]~timestamp-startTime>windowPolicy~windowSeconds+0.0000001 then leave
      d=abs(helper~shortestHeadingDelta(poses[i-1]~headingDeg,poses[i]~headingDeg))
      totalTurn=totalTurn+d
      if totalTurn>maxObserved then maxObserved=totalTurn
    end
    if totalTurn>windowPolicy~maxAbsTurnDeg then findings~append('TURN_WINDOW_LIMIT:'||start||':'||totalTurn)
  end
  return .VisionCameraTurnWindowCheck~new(findings~items=0,maxObserved,findings)

::class VisionPoseCloudSolver public
::method seedFromPoses
  use strict arg sourceRef,frameIndex,timestamp,poses,beamWidth=160
  cloud=.VisionPoseCloudFrame~new(sourceRef,frameIndex,timestamp)
  do p over poses
    if \p~isA(.VisionCameraPoseCandidate) then raise syntax 40.900 array('seed poses must be VisionCameraPoseCandidate')
    cloud~addCandidate(.VisionPoseCloudCandidate~new(p,p~confidence))
  end
  return self~prune(cloud,beamWidth)

/* Generate a coarse set of possible starting positions from a proposed
 * accessible-floor layout.  This is deliberately independent of room names:
 * only physically accessible geometry is used. */
::method seedFromAccessibleFloor
  use strict arg sourceRef,frameIndex,timestamp,floor,minX,maxX,minY,maxY,gridStepM=.5,headingStepDeg=45,beamWidth=320
  cloud=.VisionPoseCloudFrame~new(sourceRef,frameIndex,timestamp)
  y=minY
  do while y<=maxY+0.0000001
    x=minX
    do while x<=maxX+0.0000001
      if floor~contains(x,y) then do
        h=0
        do while h<360
          p=.VisionCameraPoseCandidate~new(sourceRef,frameIndex,timestamp,x,y,h,.5,'ACCESSIBLE_SEED')
          cloud~addCandidate(.VisionPoseCloudCandidate~new(p,.5))
          h=h+headingStepDeg
        end
      end
      x=x+gridStepM
    end
    y=y+gridStepM
  end
  cloud~generatedCount=cloud~items
  return self~prune(cloud,beamWidth)

::method propagate
  use strict arg previous,constraint,floor=.nil,policy=.nil,config=.nil
  if \previous~isA(.VisionPoseCloudFrame) then raise syntax 40.900 array('previous pose cloud required')
  if \constraint~isA(.VisionCameraStepConstraint) then raise syntax 40.900 array('VisionCameraStepConstraint required')
  if config==.nil then config=.VisionPoseCloudConfig~new
  if policy==.nil then policy=.VisionCameraMotionPolicy~new
  dt=constraint~timestamp-previous~timestamp
  if dt<=0 then raise syntax 40.900 array('pose-cloud timestamps must increase')
  physicalMax=policy~maxSpeedMps*dt
  minD=constraint~minDistanceM
  maxD=constraint~maxDistanceM
  if maxD==.nil then maxD=physicalMax
  else maxD=min(maxD,physicalMax)
  if minD>maxD then do
    empty=.VisionPoseCloudFrame~new(constraint~sourceRef,constraint~frameIndex,constraint~timestamp)
    empty~rejectedCount=previous~items
    return empty
  end
  distances=self~sampleRange(minD,maxD,config~distanceSamples,constraint~preferredDistanceM)
  turns=self~sampleRange(constraint~minTurnDeg,constraint~maxTurnDeg,config~turnSamples,constraint~preferredTurnDeg)
  bearings=self~sampleRange(constraint~minBearingOffsetDeg,constraint~maxBearingOffsetDeg,config~bearingSamples,constraint~preferredBearingOffsetDeg)
  out=.VisionPoseCloudFrame~new(constraint~sourceRef,constraint~frameIndex,constraint~timestamp)
  checker=.VisionCameraPathFeasibility~new
  do parentIndex=1 to previous~candidates~items
    parent=previous~candidates[parentIndex]
    pp=parent~pose
    do t over turns
      newHeading=self~normalizeHeading(pp~headingDeg+t)
      do b over bearings
        travelHeading=self~normalizeHeading(newHeading+b)
        radians=travelHeading*3.141592653589793/180
        do d over distances
          nx=pp~x+d*rx_v3_cos(radians)
          ny=pp~y+d*rx_v3_sin(radians)
          pose=.VisionCameraPoseCandidate~new(constraint~sourceRef,constraint~frameIndex,constraint~timestamp,nx,ny,newHeading,constraint~confidence,constraint~evidence)
          out~generatedCount=out~generatedCount+1
          check=checker~checkTransition(pp,pose,floor,policy)
          if \check~valid then do; out~rejectedCount=out~rejectedCount+1; iterate; end
          score=parent~score+self~transitionScore(d,t,b,constraint,config)
          cumulativeDistance=parent~cumulativeDistanceM+d
          cumulativeTurn=parent~cumulativeAbsTurnDeg+abs(t)
          out~addCandidate(.VisionPoseCloudCandidate~new(pose,score,parentIndex,check,constraint~evidence,cumulativeDistance,cumulativeTurn))
        end
      end
    end
  end
  return self~prune(out,config~beamWidth)

::method transitionScore private
  use strict arg distance,turn,bearing,constraint,config
  score=0
  if constraint~preferredDistanceM\==.nil then do
    span=max(.000001,constraint~maxDistanceM-constraint~minDistanceM)
    score=score-config~scoreDistanceWeight*abs(distance-constraint~preferredDistanceM)/span
  end
  turnSpan=max(.000001,constraint~maxTurnDeg-constraint~minTurnDeg)
  score=score-config~scoreTurnWeight*abs(turn-constraint~preferredTurnDeg)/turnSpan
  bearingSpan=max(.000001,constraint~maxBearingOffsetDeg-constraint~minBearingOffsetDeg)
  score=score-config~scoreBearingWeight*abs(bearing-constraint~preferredBearingOffsetDeg)/bearingSpan
  score=score+config~scoreConfidenceWeight*constraint~confidence
  return score

::method sampleRange private
  use strict arg low,high,count,preferred=.nil
  a=.array~new
  if count=1 | abs(high-low)<.000000001 then do; a~append((low+high)/2); return a; end
  do i=0 to count-1
    a~append(low+(high-low)*i/(count-1))
  end
  if preferred\==.nil then do
    if preferred>=low & preferred<=high then do
      seen=.false
    do v over a
      if abs(v-preferred)<.000000001 then do; seen=.true; leave; end
    end
      if \seen then a~append(preferred)
    end
  end
  return a

/* Beam pruning retains the best-scoring survivors.  It is intentionally
 * simple and deterministic; spatial binning can be added later without
 * changing the public cloud contract. */
::method prune
  use strict arg cloud,maxCandidates
  if cloud~items<=maxCandidates then return cloud
  selected=.array~new; used=.directory~new
  do pick=1 to maxCandidates
    bestIndex=0; bestScore=.nil
    do i=1 to cloud~candidates~items
      if used~hasIndex(i) then iterate
      s=cloud~candidates[i]~score
      if bestIndex=0 | s>bestScore then do; bestIndex=i; bestScore=s; end
    end
    if bestIndex=0 then leave
    selected~append(cloud~candidates[bestIndex]); used[bestIndex]=1
  end
  replacement=.VisionPoseCloudFrame~new(cloud~sourceRef,cloud~frameIndex,cloud~timestamp)
  replacement~generatedCount=cloud~generatedCount
  replacement~rejectedCount=cloud~rejectedCount+(cloud~items-selected~items)
  do c over selected; replacement~addCandidate(c); end
  return replacement

::method normalizeHeading private
  use strict arg h
  n=h//360
  if n<0 then n=n+360
  return n

::class VisionSynchronizedPosePair public
::method init
  expose candidateA candidateB separationM headingDifferenceDeg score
  use strict arg candidateA,candidateB,separationM,headingDifferenceDeg,score
::attribute candidateA get
::attribute candidateB get
::attribute separationM get
::attribute headingDifferenceDeg get
::attribute score get

/* Fuzzy common-world test for independently propagated camera clouds.  The
 * caller chooses separation and heading tolerances; no rigid stereo baseline
 * is assumed. */
::class VisionCrossSourcePoseMatcher public
::method match
  use strict arg cloudA,cloudB,maxSeparationM=2,maxHeadingDifferenceDeg=60,maxPairs=120
  pairs=.array~new
  helper=.VisionCameraPathFeasibility~new
  do a over cloudA~candidates
    pa=a~pose
    do b over cloudB~candidates
      pb=b~pose
      dx=pb~x-pa~x; dy=pb~y-pa~y
      separation=rx_v3pc_sqrt(dx*dx+dy*dy)
      if separation>maxSeparationM then iterate
      headingDiff=abs(helper~shortestHeadingDelta(pa~headingDeg,pb~headingDeg))
      if headingDiff>maxHeadingDifferenceDeg then iterate
      score=a~score+b~score-(separation/max(.000001,maxSeparationM))-(headingDiff/max(.000001,maxHeadingDifferenceDeg))
      pairs~append(.VisionSynchronizedPosePair~new(a,b,separation,headingDiff,score))
    end
  end
  if pairs~items<=maxPairs then return pairs
  /* deterministic top-N */
  selected=.array~new; used=.directory~new
  do pick=1 to maxPairs
    bestIndex=0; bestScore=.nil
    do i=1 to pairs~items
      if used~hasIndex(i) then iterate
      s=pairs[i]~score
      if bestIndex=0 | s>bestScore then do; bestIndex=i; bestScore=s; end
    end
    if bestIndex=0 then leave
    selected~append(pairs[bestIndex]); used[bestIndex]=1
  end
  return selected

::class VisionCommonLayoutFrameCheck public
::method init
  expose valid sourceA sourceB frameIndexA frameIndexB pairCount bestPair findings
  use strict arg valid,sourceA,sourceB,frameIndexA,frameIndexB,pairCount,bestPair=.nil,findings=.nil
  if findings==.nil then findings=.array~new
::attribute valid get
::attribute sourceA get
::attribute sourceB get
::attribute frameIndexA get
::attribute frameIndexB get
::attribute pairCount get
::attribute bestPair get
::attribute findings get

::class VisionCommonLayoutFeasibility public
::method checkSynchronizedClouds
  use strict arg cloudA,cloudB,maxSeparationM=2,maxHeadingDifferenceDeg=60
  matcher=.VisionCrossSourcePoseMatcher~new
  pairs=matcher~match(cloudA,cloudB,maxSeparationM,maxHeadingDifferenceDeg,120)
  findings=.array~new
  if pairs~items=0 then do
    findings~append('NO_COMMON_POSE_PAIR')
    return .VisionCommonLayoutFrameCheck~new(.false,cloudA~sourceRef,cloudB~sourceRef,cloudA~frameIndex,cloudB~frameIndex,0,.nil,findings)
  end
  best=pairs[1]
  do i=2 to pairs~items
    if pairs[i]~score>best~score then best=pairs[i]
  end
  return .VisionCommonLayoutFrameCheck~new(.true,cloudA~sourceRef,cloudB~sourceRef,cloudA~frameIndex,cloudB~frameIndex,pairs~items,best,findings)

/* Numeric helpers kept local so dev8 remains usable without imposing a new
 * maths dependency on the camera-path hot loop. */
::routine rx_v3_sin
  use strict arg x
  /* range reduction to [-pi,pi] */
  pi=3.141592653589793; twopi=2*pi
  do while x>pi; x=x-twopi; end
  do while x< -pi; x=x+twopi; end
  term=x; sum=x
  do n=1 to 9
    term=-term*x*x/((2*n)*(2*n+1)); sum=sum+term
  end
  return sum

::routine rx_v3_cos
  use strict arg x
  pi=3.141592653589793; twopi=2*pi
  do while x>pi; x=x-twopi; end
  do while x< -pi; x=x+twopi; end
  term=1; sum=1
  do n=1 to 9
    term=-term*x*x/((2*n-1)*(2*n)); sum=sum+term
  end
  return sum


::routine rx_v3pc_sqrt
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

::requires 'Vision3DCameraPath.cls'
