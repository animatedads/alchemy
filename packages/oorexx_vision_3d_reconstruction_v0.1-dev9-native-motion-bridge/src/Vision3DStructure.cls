/* ooRexx Vision 3D Reconstruction v0.1-dev4
 *
 * Hall-first / building-structure reconstruction helpers.
 *
 * Principle:
 *   1. follow the bottom-connected support surface (usually floor),
 *   2. track the support frontier and floor/wall contact edges,
 *   3. use repeated movement / floor-plane registrations to promote stable
 *      openings and approximately-orthogonal structural corners,
 *   4. request more V5V geometry evidence before requesting source pixels.
 *
 * These classes do not declare that an inferred wall or corner is observed.
 * They preserve source/frame evidence and use explicit candidate states.
 */

::class VisionStructuralState public
::method candidate class; return 'CANDIDATE'
::method observed class; return 'OBSERVED'
::method inferred class; return 'INFERRED'
::method rejected class; return 'REJECTED'

::class VisionGeometryEvidenceKind public
::method supportSample class; return 'SUPPORT_SAMPLE'
::method floorWallBoundary class; return 'FLOOR_WALL_BOUNDARY'
::method lineSample class; return 'LINE_SAMPLE'
::method corner class; return 'CORNER'
::method junction class; return 'JUNCTION'
::method contourSample class; return 'CONTOUR_SAMPLE'
::method planeSample class; return 'PLANE_SAMPLE'
::method occlusionBoundary class; return 'OCCLUSION_BOUNDARY'
::method doorwayJamb class; return 'DOORWAY_JAMB'

/* 2D frontier in source/sample coordinates.  Points are ordered by X and are
 * deliberately lightweight; the caller may later project them into a shared
 * floor coordinate system through VisionFloorHomography. */
::class VisionSupportFrontier public
::method init
  expose sourceRef timestamp frameRef width height points confidence seedValue evidenceRef
  use strict arg sourceRef,timestamp,frameRef,width,height,points,confidence=1,seedValue=.nil,evidenceRef=.nil
  if width<1 | height<1 then raise syntax 40.900 array('frontier dimensions must be positive')
  if \points~isA(.array) then raise syntax 40.900 array('frontier points must be Array')
  if confidence<0 | confidence>1 then raise syntax 40.900 array('frontier confidence must be 0..1')
::attribute sourceRef get
::attribute timestamp get
::attribute frameRef get
::attribute width get
::attribute height get
::attribute points get
::attribute confidence get
::attribute seedValue get
::attribute evidenceRef get

::method normalizedPoints
  expose width height points
  out=.array~new
  do p over points
    out~append(.array~of(p[1]/width,p[2]/height))
  end
  return out

::method xSpan
  expose points
  if points~items=0 then return 0
  return points[points~items][1]-points[1][1]

/* Bottom-connected support extractor for compact Vision surfaces.
 *
 * It intentionally uses the Vision value model and a modal bottom-band seed,
 * not RGB assumptions.  For low-resolution V5V this is cheap enough to flood
 * directly.  An explicit seedValue can override the modal value when a caller
 * already knows the support class.
 */
::class VisionSupportFrontierExtractor public
::method extract
  use strict arg surface,sourceRef='',timestamp=0,frameRef='',maxValueDistance=1,seedBandRows=4,seedValue=.nil,evidenceRef=.nil
  if \surface~isA(.VisionSurface) then raise syntax 40.900 array('VisionSurface required')
  model=surface~valueModel
  if model==.nil then raise syntax 40.900 array('support frontier extraction requires Vision value model')
  width=surface~width; height=surface~height
  if seedBandRows<1 then seedBandRows=1
  if seedBandRows>height then seedBandRows=height

  if seedValue==.nil then do
    counts=.directory~new
    startY=height-seedBandRows
    do y=startY to height-1
      do x=0 to width-1
        v=surface~at(x,y)
        k=v~string
        if counts~hasIndex(k) then counts[k]=counts[k]+1
        else counts[k]=1
      end
    end
    bestCount=-1; bestKey=''
    do k over counts
      if counts[k]>bestCount then do; bestCount=counts[k]; bestKey=k; end
    end
    /* Surface values in the current compact Vision contract are integer-like
     * packed values.  Preserve numeric seed identity rather than the key text. */
    seedValue=bestKey+0
  end

  queue=.array~new; cursor=1; visited=.directory~new
  /* Seed from matching bottom-band pixels.  Starting from the band rather than
   * the single bottom row tolerates camera housings / near-field occlusion. */
  startY=height-seedBandRows
  do y=startY to height-1
    do x=0 to width-1
      v=surface~at(x,y)
      if model~distance(v,seedValue)<=maxValueDistance then do
        k=x || ',' || y
        if \visited~hasIndex(k) then do
          visited[k]=1; queue~append(.array~of(x,y))
        end
      end
    end
  end

  do while cursor<=queue~items
    p=queue[cursor]; cursor=cursor+1
    x=p[1]; y=p[2]
    call rx_v3_support_try surface,model,seedValue,maxValueDistance,x-1,y,width,height,visited,queue
    call rx_v3_support_try surface,model,seedValue,maxValueDistance,x+1,y,width,height,visited,queue
    call rx_v3_support_try surface,model,seedValue,maxValueDistance,x,y-1,width,height,visited,queue
    call rx_v3_support_try surface,model,seedValue,maxValueDistance,x,y+1,width,height,visited,queue
  end

  points=.array~new; covered=0
  do x=0 to width-1
    top=height
    do y=0 to height-1
      if visited~hasIndex(x || ',' || y) then do; top=y; leave; end
    end
    if top<height then do
      points~append(.array~of(x,top)); covered=covered+1
    end
  end
  confidence=covered/width
  return .VisionSupportFrontier~new(sourceRef,timestamp,frameRef,width,height,points,confidence,seedValue,evidenceRef)

/* Exact four-pair floor-plane projective registration.  Robust match selection
 * (RANSAC, line association, etc.) remains a provider concern; this class owns
 * the deterministic homography calculation and provenance container. */
::class VisionFloorHomography public
::method init
  expose matrix sourceRef targetRef sourceFrameRef targetFrameRef candidateCount inlierCount confidence evidenceRef
  use strict arg matrix,sourceRef='',targetRef='',sourceFrameRef='',targetFrameRef='',candidateCount=4,inlierCount=4,evidenceRef=.nil
  if \matrix~isA(.MathMatrix3) then raise syntax 40.900 array('MathMatrix3 homography required')
  if candidateCount<0 | inlierCount<0 | inlierCount>candidateCount then raise syntax 40.900 array('invalid homography inlier counts')
  if candidateCount=0 then confidence=0
  else confidence=inlierCount/candidateCount
::attribute matrix get
::attribute sourceRef get
::attribute targetRef get
::attribute sourceFrameRef get
::attribute targetFrameRef get
::attribute candidateCount get
::attribute inlierCount get
::attribute confidence get
::attribute evidenceRef get

::method project
  expose matrix
  use strict arg point
  if \point~isA(.array) | point~items<2 then raise syntax 40.900 array('2D Array point required')
  v=matrix*.MathVector3~new(point[1],point[2],1)
  if abs(v~z)<1E-18 then raise syntax 40.900 array('homography projected point to infinity')
  return .array~of(v~x/v~z,v~y/v~z)

::method projectFrontier
  use strict arg frontier
  if \frontier~isA(.VisionSupportFrontier) then raise syntax 40.900 array('VisionSupportFrontier required')
  out=.array~new
  do p over frontier~points
    out~append(self~project(p))
  end
  return out

::method fromFourPairs class
  use strict arg sourcePoints,targetPoints,sourceRef='',targetRef='',sourceFrameRef='',targetFrameRef='',evidenceRef=.nil
  if \sourcePoints~isA(.array) | \targetPoints~isA(.array) then raise syntax 40.900 array('source/target point arrays required')
  if sourcePoints~items<>4 | targetPoints~items<>4 then raise syntax 40.900 array('exactly four point pairs required')
  rows=.array~new; rhs=.array~new
  do i=1 to 4
    s=sourcePoints[i]; t=targetPoints[i]
    x=s[1]; y=s[2]; u=t[1]; v=t[2]
    rows~append(.array~of(x,y,1,0,0,0,-u*x,-u*y)); rhs~append(u)
    rows~append(.array~of(0,0,0,x,y,1,-v*x,-v*y)); rhs~append(v)
  end
  a=.MathMatrix~new(rows)
  b=.MathVector~new(rhs)
  h=a~solve(b)
  m=.array~of(.array~of(h[1],h[2],h[3]),.array~of(h[4],h[5],h[6]),.array~of(h[7],h[8],1))
  return self~new(.MathMatrix3~new(m),sourceRef,targetRef,sourceFrameRef,targetFrameRef,4,4,evidenceRef)

/* Candidate gap in a support frontier.  The state remains CANDIDATE until
 * temporal/cross-source evidence supports promotion. */
::class VisionStructuralOpeningCandidate public
::method init
  expose startX endX depthGain confidence state sourceRef frameRef evidenceRef
  use strict arg startX,endX,depthGain,confidence,sourceRef='',frameRef='',evidenceRef=.nil
  if endX<startX then raise syntax 40.900 array('opening endX must be >= startX')
  state=.VisionStructuralState~candidate
::attribute startX get
::attribute endX get
::attribute depthGain get
::attribute confidence get
::attribute state
::attribute sourceRef get
::attribute frameRef get
::attribute evidenceRef get
::method width; expose startX endX; return endX-startX

/* Cheap opening detector.  It compares the observed frontier with the chord
 * joining its endpoints.  A contiguous upward penetration means the support
 * surface remains visible farther away than the surrounding frontier.
 */
::class VisionSupportOpeningDetector public
::method detect
  use strict arg frontier,minWidth=3,minDepth=2
  pts=frontier~points; out=.array~new
  if pts~items<3 then return out
  first=pts[1]; last=pts[pts~items]
  dx=last[1]-first[1]
  if dx=0 then return out
  runStart=.nil; bestDepth=0; sumDepth=0; runCount=0
  do i=1 to pts~items
    p=pts[i]
    ratio=(p[1]-first[1])/dx
    baseline=first[2]+ratio*(last[2]-first[2])
    depth=baseline-p[2]
    if depth>=minDepth then do
      if runStart==.nil then do; runStart=p[1]; bestDepth=0; sumDepth=0; runCount=0; end
      bestDepth=max(bestDepth,depth); sumDepth=sumDepth+depth; runCount=runCount+1
    end
    else if runStart\==.nil then do
      runEnd=pts[i-1][1]
      if runEnd-runStart>=minWidth then do
        avgDepth=sumDepth/runCount
        confidence=min(1,(avgDepth/minDepth)*.5 + ((runEnd-runStart)/frontier~width)*.5)
        out~append(.VisionStructuralOpeningCandidate~new(runStart,runEnd,bestDepth,confidence,frontier~sourceRef,frontier~frameRef,frontier~evidenceRef))
      end
      runStart=.nil
    end
  end
  if runStart\==.nil then do
    runEnd=pts[pts~items][1]
    if runEnd-runStart>=minWidth then do
      avgDepth=sumDepth/runCount
      confidence=min(1,(avgDepth/minDepth)*.5 + ((runEnd-runStart)/frontier~width)*.5)
      out~append(.VisionStructuralOpeningCandidate~new(runStart,runEnd,bestDepth,confidence,frontier~sourceRef,frontier~frameRef,frontier~evidenceRef))
    end
  end
  return out

::class VisionFloorBoundarySegment public
::method init
  expose segmentId pointA pointB confidence state evidenceRefs
  use strict arg segmentId,pointA,pointB,confidence=1,state='CANDIDATE',evidenceRefs=.nil
  if \pointA~isA(.array) | \pointB~isA(.array) then raise syntax 40.900 array('2D segment points required')
  if evidenceRefs==.nil then evidenceRefs=.array~new
::attribute segmentId get
::attribute pointA get
::attribute pointB get
::attribute confidence get
::attribute state
::attribute evidenceRefs get
::method dx; expose pointA pointB; return pointB[1]-pointA[1]
::method dy; expose pointA pointB; return pointB[2]-pointA[2]
::method length
  dX=self~dx; dY=self~dy
  return rx_math3d_sqrt(dX*dX+dY*dY,.Maths~defaultContext)

::class VisionStructuralCornerCandidate public
::method init
  expose point segmentA segmentB angleErrorDegrees confidence state evidenceRefs
  use strict arg point,segmentA,segmentB,angleErrorDegrees,confidence=1,evidenceRefs=.nil
  state=.VisionStructuralState~candidate
  if evidenceRefs==.nil then evidenceRefs=.array~new
::attribute point get
::attribute segmentA get
::attribute segmentB get
::attribute angleErrorDegrees get
::attribute confidence get
::attribute state
::attribute evidenceRefs get

/* Manhattan-world is a PRIOR, not a declaration that every building is square.
 * Corners outside tolerance remain available to other geometry models. */
::class VisionManhattanCornerDetector public
::method init
  expose toleranceDegrees
  use strict arg toleranceDegrees=15
  if toleranceDegrees<0 | toleranceDegrees>=45 then raise syntax 40.900 array('Manhattan tolerance must be in [0,45) degrees')
::attribute toleranceDegrees

::method candidate
  expose toleranceDegrees
  use strict arg segmentA,segmentB
  if segmentA~length=0 | segmentB~length=0 then return .nil
  dot=(segmentA~dx*segmentB~dx + segmentA~dy*segmentB~dy)/(segmentA~length*segmentB~length)
  dot=abs(dot)
  /* Near 90 degrees means |cos(angle)| <= sin(tolerance). */
  threshold=.MathAngle~degrees(toleranceDegrees)~sin
  if dot>threshold then return .nil
  p=rx_v3_line_intersection(segmentA~pointA,segmentA~pointB,segmentB~pointA,segmentB~pointB)
  if p==.nil then return .nil
  /* Small-angle approximation is not used: derive actual angle error using
   * atan2 of |cross| and dot in ordinary numeric domain.  ooRexx BIF ATAN2 is
   * not assumed, so confidence is based on normalized dot while the human
   * diagnostic reports tolerance-scaled error. */
  errorDegrees=(dot/threshold)*toleranceDegrees
  confidence=1-(dot/threshold)*.5
  evidence=.array~new
  do e over segmentA~evidenceRefs; evidence~append(e); end
  do e over segmentB~evidenceRefs; evidence~append(e); end
  return .VisionStructuralCornerCandidate~new(p,segmentA,segmentB,errorDegrees,confidence,evidence)

/* A semantic request for more geometry, not merely more pixels. */
::class Vision3DGeometryRefinementRequest public
::method init
  expose targetRef reason region startTime endTime targetObservationCount minSampleSeparation sourceRefs wantedEvidence preferCrossSource targetConfidence priority candidateFrames
  use strict arg targetRef,reason,region,startTime,endTime,targetObservationCount=100,minSampleSeparation=1,targetConfidence=.85
  if targetObservationCount<1 then raise syntax 40.900 array('target observation count must be positive')
  if minSampleSeparation<0 then raise syntax 40.900 array('minimum sample separation must be non-negative')
  sourceRefs=.array~new; wantedEvidence=.array~new; candidateFrames=.array~new
  preferCrossSource=.true; priority='NORMAL'
::attribute targetRef get
::attribute reason get
::attribute region get
::attribute startTime get
::attribute endTime get
::attribute targetObservationCount
::attribute minSampleSeparation
::attribute sourceRefs get
::attribute wantedEvidence get
::attribute preferCrossSource
::attribute targetConfidence
::attribute priority
::attribute candidateFrames get

::method addSource
  expose sourceRefs
  use strict arg sourceRef
  sourceRefs~append(sourceRef); return self
::method addEvidenceKind
  expose wantedEvidence
  use strict arg kind
  wantedEvidence~append(kind); return self
::method addCandidateFrame
  expose candidateFrames
  use strict arg frameRef
  candidateFrames~append(frameRef); return self

::method asHighResolutionRequest
  expose targetRef reason region startTime endTime priority
  use strict arg sourceRef,width,height
  request=.VisionHighResolutionRequest~new(sourceRef,region,startTime,endTime,'GEOMETRY:' || targetRef || ':' || reason)
  request~priority=priority
  request~requireDimensions(width,height)
  return request

/* Shared building skeleton.  It is intentionally topological and sparse:
 * support registrations, floor-boundary segments, openings and corners exist
 * before any renderer mesh is generated. */
::class VisionBuildingSkeleton public
::method init
  expose skeletonId floorRegistrations boundarySegments openings corners evidenceRefs
  use strict arg skeletonId
  floorRegistrations=.array~new; boundarySegments=.array~new; openings=.array~new; corners=.array~new; evidenceRefs=.array~new
::attribute skeletonId get
::attribute floorRegistrations get
::attribute boundarySegments get
::attribute openings get
::attribute corners get
::attribute evidenceRefs get
::method addFloorRegistration; expose floorRegistrations; use strict arg item; floorRegistrations~append(item); return self
::method addBoundarySegment; expose boundarySegments; use strict arg item; boundarySegments~append(item); return self
::method addOpening; expose openings; use strict arg item; openings~append(item); return self
::method addCorner; expose corners; use strict arg item; corners~append(item); return self
::method addEvidence; expose evidenceRefs; use strict arg item; evidenceRefs~append(item); return self
::method summary
  expose floorRegistrations boundarySegments openings corners evidenceRefs
  out=.directory~new
  out['FLOOR_REGISTRATIONS']=floorRegistrations~items
  out['BOUNDARY_SEGMENTS']=boundarySegments~items
  out['OPENINGS']=openings~items
  out['CORNERS']=corners~items
  out['EVIDENCE_REFS']=evidenceRefs~items
  return out

::routine rx_v3_support_try
  use strict arg surface,model,seedValue,maxDistance,x,y,width,height,visited,queue
  if x<0 | y<0 | x>=width | y>=height then return
  k=x || ',' || y
  if visited~hasIndex(k) then return
  if model~distance(surface~at(x,y),seedValue)>maxDistance then return
  visited[k]=1; queue~append(.array~of(x,y))
  return

::routine rx_v3_line_intersection
  use strict arg a1,a2,b1,b2
  x1=a1[1]; y1=a1[2]; x2=a2[1]; y2=a2[2]
  x3=b1[1]; y3=b1[2]; x4=b2[1]; y4=b2[2]
  denominator=(x1-x2)*(y3-y4)-(y1-y2)*(x3-x4)
  if abs(denominator)<1E-18 then return .nil
  px=((x1*y2-y1*x2)*(x3-x4)-(x1-x2)*(x3*y4-y3*x4))/denominator
  py=((x1*y2-y1*x2)*(y3-y4)-(y1-y2)*(x3*y4-y3*x4))/denominator
  return .array~of(px,py)

::requires 'Vision3DReconstruction.cls'
::requires 'Vision.cls'
