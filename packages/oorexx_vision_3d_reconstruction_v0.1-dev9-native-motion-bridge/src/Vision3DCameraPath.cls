/* ooRexx Vision 3D Reconstruction v0.1-dev7
 *
 * Native-cadence camera-motion and path-feasibility contracts.
 *
 * Motion is solved before semantic floor-plan inference.  Every proposed
 * camera pose must be physically reachable in accessible floor space, must
 * respect translation / angular-rate limits, and must not cross a wall
 * segment.  Openings are represented by gaps in the wall segments.
 *
 * Positive motion-alignment lag means A[lag+i] aligns with B[i].
 */

::class VisionCameraMotionPolicy public
::method init
  expose maxSpeedMps maxAngularRateDps
  use strict arg maxSpeedMps=3,maxAngularRateDps=360
  if maxSpeedMps<=0 then raise syntax 40.900 array('maxSpeedMps must be positive')
  if maxAngularRateDps<=0 then raise syntax 40.900 array('maxAngularRateDps must be positive')
::attribute maxSpeedMps get
::attribute maxAngularRateDps get

::class VisionFrameMotionEvidence public
::method init
  expose sourceRef frameIndex timestamp dx dy turnDeg expansion confidence evidence motionVectors lineDeltas
  use strict arg sourceRef,frameIndex,timestamp,dx=0,dy=0,turnDeg=0,expansion=0,confidence=1,evidence=.nil
  if confidence<0 | confidence>1 then raise syntax 40.900 array('motion confidence must be 0..1')
  motionVectors=.array~new; lineDeltas=.array~new
::attribute sourceRef get
::attribute frameIndex get
::attribute timestamp get
::attribute dx
::attribute dy
::attribute turnDeg
::attribute expansion
::attribute confidence get
::attribute evidence get
::attribute motionVectors get
::attribute lineDeltas get
::method addVector
  expose motionVectors
  use strict arg vector
  motionVectors~append(vector); return self
::method addLineDelta
  expose lineDeltas
  use strict arg delta
  lineDeltas~append(delta); return self

::class VisionImageMotionVector public
::method init
  expose itemId x y dx dy confidence
  use strict arg itemId,x,y,dx,dy,confidence=1
::attribute itemId get
::attribute x get
::attribute y get
::attribute dx get
::attribute dy get
::attribute confidence get
::method magnitude
  expose dx dy
  return rx_v3_sqrt(dx*dx+dy*dy)

::class VisionTrackedImageItem public
::method init
  expose itemId x y confidence evidence
  use strict arg itemId,x,y,confidence=1,evidence=.nil
::attribute itemId get
::attribute x get
::attribute y get
::attribute confidence get
::attribute evidence get

::class VisionTrackedImageLine public
::method init
  expose lineId x1 y1 x2 y2 orientationDeg confidence evidence
  use strict arg lineId,x1,y1,x2,y2,orientationDeg,confidence=1,evidence=.nil
::attribute lineId get
::attribute x1 get
::attribute y1 get
::attribute x2 get
::attribute y2 get
::attribute orientationDeg get
::attribute confidence get
::attribute evidence get
::method midX; expose x1 x2; return (x1+x2)/2
::method midY; expose y1 y2; return (y1+y2)/2
::method length
  expose x1 y1 x2 y2
  return rx_v3_sqrt((x2-x1)*(x2-x1)+(y2-y1)*(y2-y1))

::class VisionTrackedLineDelta public
::method init
  expose lineId dx dy angleDeltaDeg lengthRatio confidence
  use strict arg lineId,dx,dy,angleDeltaDeg,lengthRatio,confidence=1
::attribute lineId get
::attribute dx get
::attribute dy get
::attribute angleDeltaDeg get
::attribute lengthRatio get
::attribute confidence get

::class VisionFrameGeometry public
::method init
  expose timestamp items lines
  use strict arg timestamp
  items=.directory~new; lines=.directory~new
::attribute timestamp get
::attribute items get
::attribute lines get
::method addItem
  expose items
  use strict arg item
  items[item~itemId]=item; return self
::method addLine
  expose lines
  use strict arg line
  lines[line~lineId]=line; return self

/* Implements the user's native-cadence inner loop once Vision/Line Assessment
 * has identified stable item and line identities.  It compares like-for-like
 * observations only; identity policy remains upstream. */
::class VisionFrameGeometryComparator public
::method compare
  use strict arg previous,current,sourceRef,frameIndex
  dt=current~timestamp-previous~timestamp
  if dt<=0 then raise syntax 40.900 array('frame geometry timestamps must increase')
  ev=.VisionFrameMotionEvidence~new(sourceRef,frameIndex,current~timestamp)
  sumDx=0; sumDy=0; weight=0
  do id over current~items
    if \previous~items~hasIndex(id) then iterate
    a=previous~items[id]; b=current~items[id]
    conf=min(a~confidence,b~confidence)
    dx=b~x-a~x; dy=b~y-a~y
    ev~addVector(.VisionImageMotionVector~new(id,a~x,a~y,dx,dy,conf))
    sumDx=sumDx+dx*conf; sumDy=sumDy+dy*conf; weight=weight+conf
  end
  do id over current~lines
    if \previous~lines~hasIndex(id) then iterate
    a=previous~lines[id]; b=current~lines[id]
    conf=min(a~confidence,b~confidence)
    dx=b~midX-a~midX; dy=b~midY-a~midY
    da=.VisionCameraPathFeasibility~new~shortestHeadingDelta(a~orientationDeg,b~orientationDeg)
    la=a~length; lb=b~length
    if la=0 then ratio=1
    else ratio=lb/la
    ev~addLineDelta(.VisionTrackedLineDelta~new(id,dx,dy,da,ratio,conf))
    sumDx=sumDx+dx*conf; sumDy=sumDy+dy*conf; weight=weight+conf
  end
  /* Aggregate image drift is advisory camera-motion evidence. */
  if weight>0 then do
    ev~dx=sumDx/weight
    ev~dy=sumDy/weight
  end
  return ev

::class VisionMotionSample public
::method init
  expose timestamp value confidence frameIndex
  use strict arg timestamp,value,confidence=1,frameIndex=.nil
  if confidence<0 | confidence>1 then raise syntax 40.900 array('motion sample confidence must be 0..1')
::attribute timestamp get
::attribute value get
::attribute confidence get
::attribute frameIndex get

::class VisionMotionSeries public
::method init
  expose sourceRef nominalFps samples
  use strict arg sourceRef,nominalFps
  if nominalFps<=0 then raise syntax 40.900 array('nominalFps must be positive')
  samples=.array~new
::attribute sourceRef get
::attribute nominalFps get
::attribute samples get
::method add
  expose samples
  use strict arg sample
  if \sample~isA(.VisionMotionSample) then raise syntax 40.900 array('VisionMotionSample required')
  samples~append(sample); return self
::method items
  expose samples
  return samples~items

::class VisionMotionAlignment public
::method init
  expose lagFrames correlation overlap sourceA sourceB
  use strict arg sourceA,sourceB,lagFrames,correlation,overlap
::attribute sourceA get
::attribute sourceB get
::attribute lagFrames get
::attribute correlation get
::attribute overlap get

/* Fuzzy frame-lag synchroniser for simultaneously carried cameras.  This is
 * deliberately scalar: callers may feed horizontal flow, vertical flow,
 * roll, expansion, or a fused motion signature and compare the resulting
 * lags. */
::class VisionMotionSynchronizer public
::method bestLagFrames
  use strict arg a,b,maxLagFrames=180,minOverlap=12
  if \a~isA(.VisionMotionSeries) | \b~isA(.VisionMotionSeries) then raise syntax 40.900 array('VisionMotionSeries required')
  best=.nil
  do lag=-maxLagFrames to maxLagFrames
    stats=self~correlationAtLag(a,b,lag,minOverlap)
    if stats==.nil then iterate
    corr=stats[1]; overlap=stats[2]
    if best==.nil then best=.VisionMotionAlignment~new(a~sourceRef,b~sourceRef,lag,corr,overlap)
    else if corr>best~correlation then best=.VisionMotionAlignment~new(a~sourceRef,b~sourceRef,lag,corr,overlap)
  end
  return best

::method correlationAtLag private
  use strict arg a,b,lag,minOverlap
  sa=a~samples; sb=b~samples
  startA=1; startB=1
  if lag>=0 then startA=1+lag
  else startB=1-lag
  overlap=min(sa~items-startA+1,sb~items-startB+1)
  if overlap<minOverlap then return .nil
  sumW=0; sumA=0; sumB=0
  do i=0 to overlap-1
    aa=sa[startA+i]; bb=sb[startB+i]
    w=aa~confidence*bb~confidence
    sumW=sumW+w; sumA=sumA+w*aa~value; sumB=sumB+w*bb~value
  end
  if sumW=0 then return .nil
  meanA=sumA/sumW; meanB=sumB/sumW
  num=0; denA=0; denB=0
  do i=0 to overlap-1
    aa=sa[startA+i]; bb=sb[startB+i]
    w=aa~confidence*bb~confidence
    da=aa~value-meanA; db=bb~value-meanB
    num=num+w*da*db; denA=denA+w*da*da; denB=denB+w*db*db
  end
  if denA<=0 | denB<=0 then corr=0
  else corr=num/rx_v3_sqrt(denA*denB)
  return .array~of(corr,overlap)

::class VisionCameraPoseCandidate public
::method init
  expose sourceRef frameIndex timestamp x y headingDeg confidence evidence
  use strict arg sourceRef,frameIndex,timestamp,x,y,headingDeg,confidence=1,evidence=.nil
  if confidence<0 | confidence>1 then raise syntax 40.900 array('pose confidence must be 0..1')
::attribute sourceRef get
::attribute frameIndex get
::attribute timestamp get
::attribute x get
::attribute y get
::attribute headingDeg get
::attribute confidence get
::attribute evidence get

::class VisionWallSegment public
::method init
  expose wallId x1 y1 x2 y2
  use strict arg wallId,x1,y1,x2,y2
::attribute wallId get
::attribute x1 get
::attribute y1 get
::attribute x2 get
::attribute y2 get

::class VisionFloorPolygon public
::method init
  expose regionId points
  use strict arg regionId,points
  if \points~isA(.Array) | points~items<3 then raise syntax 40.900 array('floor polygon requires at least three [x,y] points')
::attribute regionId get
::attribute points get
::method contains
  expose points
  use strict arg x,y
  inside=.false
  j=points~items
  do i=1 to points~items
    pi=points[i]; pj=points[j]
    xi=pi[1]; yi=pi[2]; xj=pj[1]; yj=pj[2]
    crosses=((yi>y) \= (yj>y))
    if crosses then do
      xcross=(xj-xi)*(y-yi)/(yj-yi)+xi
      if x<xcross then inside=\inside
    end
    j=i
  end
  return inside

::class VisionAccessibleFloor public
::method init
  expose regions walls
  regions=.array~new; walls=.array~new
::attribute regions get
::attribute walls get
::method addRegion
  expose regions
  use strict arg region
  if \region~isA(.VisionFloorPolygon) then raise syntax 40.900 array('VisionFloorPolygon required')
  regions~append(region); return self
::method addWall
  expose walls
  use strict arg wall
  if \wall~isA(.VisionWallSegment) then raise syntax 40.900 array('VisionWallSegment required')
  walls~append(wall); return self
::method contains
  expose regions
  use strict arg x,y
  do r over regions
    if r~contains(x,y) then return .true
  end
  return .false

::class VisionCameraPathCheck public
::method init
  expose valid findings speedMps angularRateDps
  use strict arg valid,findings,speedMps=0,angularRateDps=0
::attribute valid get
::attribute findings get
::attribute speedMps get
::attribute angularRateDps get

::class VisionCameraPathFeasibility public
::method checkTransition
  use strict arg previous,current,floor=.nil,policy=.nil
  if policy==.nil then policy=.VisionCameraMotionPolicy~new
  findings=.array~new
  dt=current~timestamp-previous~timestamp
  if dt<=0 then do
    findings~append('NON_POSITIVE_DT')
    return .VisionCameraPathCheck~new(.false,findings,0,0)
  end
  dx=current~x-previous~x; dy=current~y-previous~y
  distance=rx_v3_sqrt(dx*dx+dy*dy)
  speed=distance/dt
  dHeading=self~shortestHeadingDelta(previous~headingDeg,current~headingDeg)
  angularRate=abs(dHeading)/dt
  if speed>policy~maxSpeedMps then findings~append('SPEED_LIMIT:'||speed)
  if angularRate>policy~maxAngularRateDps then findings~append('ANGULAR_RATE_LIMIT:'||angularRate)
  if floor\==.nil then do
    if \floor~contains(previous~x,previous~y) then findings~append('PREVIOUS_POSE_INACCESSIBLE')
    if \floor~contains(current~x,current~y) then findings~append('CURRENT_POSE_INACCESSIBLE')
    do wall over floor~walls
      if self~segmentsIntersect(previous~x,previous~y,current~x,current~y,wall~x1,wall~y1,wall~x2,wall~y2) then -
        findings~append('WALL_CROSSING:'||wall~wallId)
    end
  end
  return .VisionCameraPathCheck~new(findings~items=0,findings,speed,angularRate)

::method shortestHeadingDelta
  use strict arg fromDeg,toDeg
  d=(toDeg-fromDeg)//360
  if d>180 then d=d-360
  if d<=-180 then d=d+360
  return d

::method segmentsIntersect private
  use strict arg ax,ay,bx,by,cx,cy,dx,dy
  o1=self~orientation(ax,ay,bx,by,cx,cy)
  o2=self~orientation(ax,ay,bx,by,dx,dy)
  o3=self~orientation(cx,cy,dx,dy,ax,ay)
  o4=self~orientation(cx,cy,dx,dy,bx,by)
  if o1=0 & self~onSegment(ax,ay,bx,by,cx,cy) then return .true
  if o2=0 & self~onSegment(ax,ay,bx,by,dx,dy) then return .true
  if o3=0 & self~onSegment(cx,cy,dx,dy,ax,ay) then return .true
  if o4=0 & self~onSegment(cx,cy,dx,dy,bx,by) then return .true
  return (o1<>o2 & o3<>o4)

::method orientation private
  use strict arg ax,ay,bx,by,cx,cy
  v=(by-ay)*(cx-bx)-(bx-ax)*(cy-by)
  if abs(v)<0.000000001 then return 0
  if v>0 then return 1
  return 2

::method onSegment private
  use strict arg ax,ay,bx,by,cx,cy
  return cx>=min(ax,bx) & cx<=max(ax,bx) & cy>=min(ay,by) & cy<=max(ay,by)

::class VisionCameraPathHypothesis public
::method init
  expose sourceRef poses findings valid
  use strict arg sourceRef
  poses=.array~new; findings=.array~new; valid=.true
::attribute sourceRef get
::attribute poses get
::attribute findings get
::attribute valid get
::method append
  expose poses findings valid
  use strict arg pose,floor=.nil,policy=.nil
  if \pose~isA(.VisionCameraPoseCandidate) then raise syntax 40.900 array('VisionCameraPoseCandidate required')
  if poses~items>0 then do
    checker=.VisionCameraPathFeasibility~new~checkTransition(poses[poses~items],pose,floor,policy)
    if \checker~valid then do
      valid=.false
      do f over checker~findings; findings~append(f); end
    end
  end
  poses~append(pose); return self

::routine rx_v3_sqrt
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
