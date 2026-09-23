/* ooRexx Vision 3D Reconstruction v0.1-dev3
 *
 * Evidence-aware progressive 3D reconstruction over ooRexx Vision.
 *
 * Authority boundary:
 *   - Vision owns compact observation surfaces and selective high-resolution
 *     source requests.
 *   - ooRexx Maths v0.8 owns vector/ray/plane/transform mathematics.
 *   - this package owns reconstruction evidence, sparse adaptive grid state,
 *     triangulation acceptance and the enhancement-work queue.
 *
 * It deliberately does NOT claim unseen space is observed.  Inferred geometry
 * and observed geometry remain different states.
 */

::class Vision3DState public
::method observedOccupied class; return 'OBSERVED_OCCUPIED'
::method observedFree class; return 'OBSERVED_FREE'
::method inferredSurface class; return 'INFERRED_SURFACE'
::method inferredFree class; return 'INFERRED_FREE'
::method occludedUnknown class; return 'OCCLUDED_UNKNOWN'
::method unseen class; return 'UNSEEN'
::method conflictingObserved class; return 'CONFLICTING_OBSERVED'

::class Vision3DCellRole public
::method normal class; return 'NORMAL'
::method supportOnly class; return 'SUPPORT_ONLY'

/* One camera observation promoted into a 3D ray. */
::class Vision3DRayObservation public
::method init
  expose sourceRef timestamp frameRef pixelX pixelY ray confidence evidenceRef semanticRef
  use strict arg sourceRef,timestamp,frameRef,pixelX,pixelY,ray,confidence=1,evidenceRef=.nil,semanticRef=.nil
  if \ray~isA(.MathRay3D) then raise syntax 40.900 array('MathRay3D required')
  if confidence<0 | confidence>1 then raise syntax 40.900 array('confidence must be 0..1')
::attribute sourceRef get
::attribute timestamp get
::attribute frameRef get
::attribute pixelX get
::attribute pixelY get
::attribute ray get
::attribute confidence get
::attribute evidenceRef get
::attribute semanticRef get

/* Explicit pinhole camera model.  Intrinsics are evidence, never guessed here. */
::class Vision3DCameraModel public
::method init
  expose width height focalX focalY centreX centreY context convention modelRef
  use strict arg width,height,focalX,focalY,centreX=.nil,centreY=.nil,context=.nil,convention=.nil,modelRef=.nil
  if width<1 | height<1 then raise syntax 40.900 array('camera dimensions must be positive')
  if focalX<=0 | focalY<=0 then raise syntax 40.900 array('camera focal lengths must be positive')
  if centreX==.nil then centreX=(width-1)/2
  if centreY==.nil then centreY=(height-1)/2
  if context==.nil then context=.Maths~defaultContext
  if convention==.nil then convention=.Math3DConvention~openGL
::attribute width get
::attribute height get
::attribute focalX get
::attribute focalY get
::attribute centreX get
::attribute centreY get
::attribute context get
::attribute convention get
::attribute modelRef get

::method rayForPixel
  expose focalX focalY centreX centreY context convention
  use strict arg x,y,cameraToWorld
  if \cameraToWorld~isA(.MathTransform3D) then raise syntax 40.900 array('MathTransform3D cameraToWorld required')
  numeric digits context~workingDigits
  nx=(x-centreX)/focalX
  ny=-(y-centreY)/focalY          /* image Y is down; Maths Y is up */
  if convention~handedness='RIGHT_HANDED' then nz=-1
  else nz=1
  cameraDirection=.MathVector3~new(nx,ny,nz,context)~normalized
  worldOrigin=cameraToWorld*.MathVector3~new(0,0,0,context)
  worldDirection=cameraToWorld~transformDirection(cameraDirection)~normalized
  return .MathRay3D~new(worldOrigin,worldDirection,context)

::method observationForPixel
  use strict arg sourceRef,timestamp,frameRef,x,y,cameraToWorld,confidence=1,evidenceRef=.nil,semanticRef=.nil
  return .Vision3DRayObservation~new(sourceRef,timestamp,frameRef,x,y,self~rayForPixel(x,y,cameraToWorld),confidence,evidenceRef,semanticRef)

/* Result of two-view closest-ray triangulation. */
::class Vision3DTriangulation public
::method init
  expose point pointA pointB separation distanceA distanceB status confidence observationA observationB
  use strict arg point,pointA,pointB,separation,distanceA,distanceB,status='OK',confidence=1,observationA=.nil,observationB=.nil
::attribute point get
::attribute pointA get
::attribute pointB get
::attribute separation get
::attribute distanceA get
::attribute distanceB get
::attribute status get
::attribute confidence get
::attribute observationA get
::attribute observationB get
::method valid
  expose status
  return status='OK'

::class Vision3DPlaneIntersection public
::method init
  expose point distance status
  use strict arg point=.nil,distance=.nil,status='OK'
::attribute point get
::attribute distance get
::attribute status get
::method valid; expose status; return status='OK'

/* Deterministic geometry helpers over Maths v0.8. */
::class Vision3DGeometry public
::method closestPointBetweenRays class
  use strict arg rayA,rayB,epsilon='1E-12',observationA=.nil,observationB=.nil
  if \rayA~isA(.MathRay3D) | \rayB~isA(.MathRay3D) then raise syntax 40.900 array('two MathRay3D objects required')
  ctx=rayA~context
  numeric digits ctx~workingDigits+20
  o1=rayA~origin; o2=rayB~origin; d1=rayA~direction; d2=rayB~direction
  w0=o1-o2
  a=d1~dot(d1); b=d1~dot(d2); c=d2~dot(d2)
  d=d1~dot(w0); e=d2~dot(w0)
  denominator=a*c-b*b
  if abs(denominator)<=epsilon then return .Vision3DTriangulation~new(.nil,.nil,.nil,.nil,.nil,.nil,'PARALLEL',0,observationA,observationB)
  s=(b*e-c*d)/denominator
  t=(a*e-b*d)/denominator
  p1=rayA~pointAt(s); p2=rayB~pointAt(t)
  midpoint=(p1+p2)*0.5
  separation=(p1-p2)~norm
  status='OK'
  if s<0 | t<0 then status='BEHIND_CAMERA'
  confidence=1/(1+separation)
  if observationA\==.nil then confidence=confidence*observationA~confidence
  if observationB\==.nil then confidence=confidence*observationB~confidence
  return .Vision3DTriangulation~new(midpoint,p1,p2,separation,s,t,status,confidence,observationA,observationB)

::method intersectRayPlane class
  use strict arg ray,plane,epsilon='1E-12'
  if \ray~isA(.MathRay3D) | \plane~isA(.MathPlane3D) then raise syntax 40.900 array('MathRay3D and MathPlane3D required')
  ctx=ray~context
  numeric digits ctx~workingDigits+20
  denominator=plane~normal~dot(ray~direction)
  if abs(denominator)<=epsilon then return .Vision3DPlaneIntersection~new(.nil,.nil,'PARALLEL')
  t=-(plane~normal~dot(ray~origin)+plane~offset)/denominator
  if t<0 then return .Vision3DPlaneIntersection~new(ray~pointAt(t),t,'BEHIND_CAMERA')
  return .Vision3DPlaneIntersection~new(ray~pointAt(t),t,'OK')

::method planeFromPoints class
  use strict arg pointA,pointB,pointC
  normal=(pointB-pointA)~cross(pointC-pointA)
  return .MathPlane3D~fromPointNormal(pointA,normal,pointA~context)

/* One sparse adaptive grid cell.  Multiple evidence classes are retained so
 * contradictory observations cannot silently overwrite each other. */
::class Vision3DCell public
::method init
  expose level ix iy iz role semanticRef observedOccupiedWeight observedFreeWeight inferredSurfaceWeight inferredFreeWeight evidenceRefs
  use strict arg level,ix,iy,iz,role='NORMAL',semanticRef=.nil
  observedOccupiedWeight=0; observedFreeWeight=0; inferredSurfaceWeight=0; inferredFreeWeight=0
  evidenceRefs=.array~new
::attribute level get
::attribute ix get
::attribute iy get
::attribute iz get
::attribute role
::attribute semanticRef
::attribute observedOccupiedWeight get
::attribute observedFreeWeight get
::attribute inferredSurfaceWeight get
::attribute inferredFreeWeight get
::attribute evidenceRefs get

::method key
  expose level ix iy iz
  return level || ':' || ix || ':' || iy || ':' || iz

::method addEvidence
  expose observedOccupiedWeight observedFreeWeight inferredSurfaceWeight inferredFreeWeight evidenceRefs semanticRef
  use strict arg state,confidence=1,evidenceRef=.nil,newSemanticRef=.nil
  if confidence<0 then raise syntax 40.900 array('confidence weight must be non-negative')
  select
    when state=.Vision3DState~observedOccupied then observedOccupiedWeight=observedOccupiedWeight+confidence
    when state=.Vision3DState~observedFree then observedFreeWeight=observedFreeWeight+confidence
    when state=.Vision3DState~inferredSurface then inferredSurfaceWeight=inferredSurfaceWeight+confidence
    when state=.Vision3DState~inferredFree then inferredFreeWeight=inferredFreeWeight+confidence
    otherwise raise syntax 40.900 array('unsupported stored grid state:' state)
  end
  if evidenceRef\==.nil then evidenceRefs~append(evidenceRef)
  if newSemanticRef\==.nil then semanticRef=newSemanticRef
  return self

::method state
  expose observedOccupiedWeight observedFreeWeight inferredSurfaceWeight inferredFreeWeight
  if observedOccupiedWeight>0 & observedFreeWeight>0 then return .Vision3DState~conflictingObserved
  if observedOccupiedWeight>0 then return .Vision3DState~observedOccupied
  if observedFreeWeight>0 then return .Vision3DState~observedFree
  if inferredSurfaceWeight>0 then return .Vision3DState~inferredSurface
  if inferredFreeWeight>0 then return .Vision3DState~inferredFree
  return .Vision3DState~unseen

::method confidence
  expose observedOccupiedWeight observedFreeWeight inferredSurfaceWeight inferredFreeWeight
  total=observedOccupiedWeight+observedFreeWeight+inferredSurfaceWeight+inferredFreeWeight
  if total=0 then return 0
  best=max(observedOccupiedWeight,observedFreeWeight,inferredSurfaceWeight,inferredFreeWeight)
  return best/total

/* Sparse octree-addressable occupancy evidence.  Cells are created only when
 * evidence exists; UNSEEN and OCCLUDED_UNKNOWN therefore cost no dense volume. */
::class VisionAdaptiveGrid3D public
::method init
  expose origin baseCellSize maxLevel cells
  use strict arg origin,baseCellSize=1,maxLevel=3
  if \origin~isA(.MathVector3) then raise syntax 40.900 array('MathVector3 origin required')
  if baseCellSize<=0 then raise syntax 40.900 array('baseCellSize must be positive')
  if maxLevel<0 then raise syntax 40.900 array('maxLevel must be non-negative')
  cells=.directory~new
::attribute origin get
::attribute baseCellSize get
::attribute maxLevel get
::attribute cells get

::method cellSizeAt
  expose baseCellSize maxLevel
  use strict arg level=0
  if level<0 | level>maxLevel then raise syntax 40.900 array('grid level out of range')
  return baseCellSize/(2**level)

::method coordinatesForPoint
  expose origin
  use strict arg point,level=0
  size=self~cellSizeAt(level)
  ix=rx_v3_floor((point~x-origin~x)/size)
  iy=rx_v3_floor((point~y-origin~y)/size)
  iz=rx_v3_floor((point~z-origin~z)/size)
  return .array~of(ix,iy,iz)

::method cellKey
  use strict arg level,ix,iy,iz
  return level || ':' || ix || ':' || iy || ':' || iz

::method ensureCell
  expose cells
  use strict arg level,ix,iy,iz,role='NORMAL',semanticRef=.nil
  key=self~cellKey(level,ix,iy,iz)
  if cells~hasIndex(key) then do
    cell=cells[key]
    if role<>.Vision3DCellRole~normal then cell~role=role
    if semanticRef\==.nil then cell~semanticRef=semanticRef
    return cell
  end
  cell=.Vision3DCell~new(level,ix,iy,iz,role,semanticRef)
  cells[key]=cell
  return cell

::method observePoint
  use strict arg point,state=.nil,confidence=1,evidenceRef=.nil,level=0,semanticRef=.nil,role='NORMAL'
  if state==.nil then state=.Vision3DState~observedOccupied
  c=self~coordinatesForPoint(point,level)
  cell=self~ensureCell(level,c[1],c[2],c[3],role,semanticRef)
  cell~addEvidence(state,confidence,evidenceRef,semanticRef)
  return cell

/* Mark known clear volume along a camera ray.  Endpoint is deliberately not
 * included; the caller may add an occupied observation separately. */
::method traceFree
  use strict arg ray,maxDistance,confidence=1,evidenceRef=.nil,level=0,step=.nil
  if maxDistance<=0 then return 0
  if step==.nil then step=self~cellSizeAt(level)*0.5
  if step<=0 then raise syntax 40.900 array('trace step must be positive')
  seen=.set~new; count=0; t=0
  do while t<maxDistance
    point=ray~pointAt(t)
    c=self~coordinatesForPoint(point,level)
    key=self~cellKey(level,c[1],c[2],c[3])
    if \seen~hasIndex(key) then do
      seen[key]=key
      cell=self~ensureCell(level,c[1],c[2],c[3])
      cell~addEvidence(.Vision3DState~observedFree,confidence,evidenceRef)
      count=count+1
    end
    t=t+step
  end
  return count

::method cellCentre
  expose origin
  use strict arg cell
  size=self~cellSizeAt(cell~level)
  return .MathVector3~new(origin~x+(cell~ix+0.5)*size,origin~y+(cell~iy+0.5)*size,origin~z+(cell~iz+0.5)*size,origin~context)

::method cellCount
  expose cells
  return cells~items

::method countState
  expose cells
  use strict arg wanted
  n=0
  supplier=cells~supplier
  do while supplier~available
    cell=supplier~item
    if cell~state=wanted then n=n+1
    supplier~next
  end
  return n

::method summary
  out=.directory~new
  out['CELLS']=self~cellCount
  out['OBSERVED_OCCUPIED']=self~countState(.Vision3DState~observedOccupied)
  out['OBSERVED_FREE']=self~countState(.Vision3DState~observedFree)
  out['INFERRED_SURFACE']=self~countState(.Vision3DState~inferredSurface)
  out['INFERRED_FREE']=self~countState(.Vision3DState~inferredFree)
  out['CONFLICTING_OBSERVED']=self~countState(.Vision3DState~conflictingObserved)
  return out

/* A surface facet is an explicitly inferred triangle supported by three nearby
 * reconstruction cells.  It is NEVER promoted to observed merely because its
 * vertices came from observed cells.  The facet records its supporting cells so
 * a renderer or evidence viewer can walk the inference back to source evidence. */
::class Vision3DSurfaceFacet public
::method init
  expose facetId pointA pointB pointC centroid normal confidence sourceCellKeys state
  use strict arg facetId,pointA,pointB,pointC,confidence=1,sourceCellKeys=.nil
  if \pointA~isA(.MathVector3) | \pointB~isA(.MathVector3) | \pointC~isA(.MathVector3) then raise syntax 40.900 array('MathVector3 facet vertices required')
  edgeAB=pointB-pointA; edgeAC=pointC-pointA
  cross=edgeAB~cross(edgeAC)
  if cross~norm<=0 then raise syntax 40.900 array('degenerate facet')
  normal=cross~normalized
  centroid=(pointA+pointB+pointC)*(1/3)
  if sourceCellKeys==.nil then sourceCellKeys=.array~new
  state=.Vision3DState~inferredSurface
::attribute facetId get
::attribute pointA get
::attribute pointB get
::attribute pointC get
::attribute centroid get
::attribute normal get
::attribute confidence get
::attribute sourceCellKeys get
::attribute state get

/* Conservative local surface inference.  The algorithm deliberately requires
 * all three supporting cells to be at the same grid level and every triangle
 * edge to remain within maxEdgeCells cell widths.  This creates a local skin
 * over sufficiently dense observations without bridging room-scale gaps. */
::class Vision3DFacetBuilder public
::method init
  expose grid maxEdgeCells minQuality
  use strict arg grid,maxEdgeCells=2.25,minQuality=.08
  if \grid~isA(.VisionAdaptiveGrid3D) then raise syntax 40.900 array('VisionAdaptiveGrid3D required')
  if maxEdgeCells<=0 then raise syntax 40.900 array('maxEdgeCells must be positive')
  if minQuality<0 then raise syntax 40.900 array('minQuality must be non-negative')
::attribute grid get
::attribute maxEdgeCells
::attribute minQuality

::method build
  expose grid maxEdgeCells minQuality
  cells=.array~new; points=.array~new
  supplier=grid~cells~supplier
  do while supplier~available
    cell=supplier~item
    state=cell~state
    if state=.Vision3DState~observedOccupied then do
      cells~append(cell); points~append(grid~cellCentre(cell))
    end
    supplier~next
  end
  facets=.array~new
  n=cells~items
  if n<3 then return facets
  facetNo=0
  do i=1 to n-2
    ca=cells[i]; pa=points[i]
    do j=i+1 to n-1
      cb=cells[j]
      if cb~level<>ca~level then iterate
      pb=points[j]
      do k=j+1 to n
        cc=cells[k]
        if cc~level<>ca~level then iterate
        pc=points[k]
        cellSize=grid~cellSizeAt(ca~level)
        limit=cellSize*maxEdgeCells
        ab=(pa-pb)~norm; ac=(pa-pc)~norm; bc=(pb-pc)~norm
        maxEdge=max(ab,ac,bc)
        if maxEdge>limit then iterate
        cross=(pb-pa)~cross(pc-pa)
        twiceArea=cross~norm
        if twiceArea<=(cellSize*cellSize*.02) then iterate
        area=twiceArea/2
        quality=area/(maxEdge*maxEdge)
        if quality<minQuality then iterate
        confidence=min(ca~confidence,cb~confidence,cc~confidence)
        locality=1-(maxEdge/limit)*.35
        if locality<.35 then locality=.35
        confidence=confidence*locality
        keys=.array~of(ca~key,cb~key,cc~key)
        facetNo=facetNo+1
        id='facet-' || facetNo || '-' || ca~key || '-' || cb~key || '-' || cc~key
        facets~append(.Vision3DSurfaceFacet~new(id,pa,pb,pc,confidence,keys))
      end
    end
  end
  return facets

/* Semantic reason for returning to the authoritative source.  Region/time are
 * the transport coordinates, but purpose/reason remain the governing question. */
::class Vision3DEnhancementItem public
::method init
  expose purpose reason region startTime endTime priority requiredWidth requiredHeight colourRequirement currentConfidence targetConfidence semanticRef candidateFrames
  use strict arg purpose,reason,region,startTime,endTime,currentConfidence=0,targetConfidence=1,semanticRef=.nil
  priority='NORMAL'; requiredWidth=.nil; requiredHeight=.nil; colourRequirement='SOURCE'; candidateFrames=.array~new
::attribute purpose get
::attribute reason get
::attribute region get
::attribute startTime get
::attribute endTime get
::attribute priority
::attribute requiredWidth
::attribute requiredHeight
::attribute colourRequirement
::attribute currentConfidence
::attribute targetConfidence
::attribute semanticRef
::attribute candidateFrames get

::method requireDimensions
  expose requiredWidth requiredHeight
  use strict arg width,height
  if width<1 | height<1 then raise syntax 40.900 array('enhancement dimensions must be positive')
  requiredWidth=width; requiredHeight=height
  return self

::method addCandidateFrame
  expose candidateFrames
  use strict arg frameRef
  candidateFrames~append(frameRef)
  return self

::method asHighResolutionRequest
  expose purpose reason region startTime endTime priority requiredWidth requiredHeight colourRequirement
  use strict arg sourceRef
  request=.VisionHighResolutionRequest~new(sourceRef,region,startTime,endTime,purpose || ':' || reason)
  request~priority=priority
  request~colourRequirement=colourRequirement
  if requiredWidth\==.nil & requiredHeight\==.nil then request~requireDimensions(requiredWidth,requiredHeight)
  return request

::class Vision3DEnhancementQueue public
::method init
  expose items cursor
  items=.array~new; cursor=1
::attribute items get
::method add
  expose items
  use strict arg item
  if \item~isA(.Vision3DEnhancementItem) then raise syntax 40.900 array('Vision3DEnhancementItem required')
  items~append(item); return items~items
::method pendingCount
  expose items cursor
  n=items~items-cursor+1
  if n<0 then n=0
  return n
::method next
  expose items cursor
  if cursor>items~items then return .nil
  item=items[cursor]; cursor=cursor+1
  return item

/* First reconstruction coordinator.  It accepts matched ray observations,
 * validates triangulation error, and records only accepted evidence in the grid. */
::class Vision3DReconstruction public
::method init
  expose grid enhancementQueue maximumRaySeparation accepted rejected
  use strict arg grid,maximumRaySeparation=0.05
  if \grid~isA(.VisionAdaptiveGrid3D) then raise syntax 40.900 array('VisionAdaptiveGrid3D required')
  enhancementQueue=.Vision3DEnhancementQueue~new
  accepted=0; rejected=0
::attribute grid get
::attribute enhancementQueue get
::attribute maximumRaySeparation
::attribute accepted get
::attribute rejected get

::method triangulate
  expose grid maximumRaySeparation accepted rejected
  use strict arg observationA,observationB,semanticRef=.nil,level=0
  tri=.Vision3DGeometry~closestPointBetweenRays(observationA~ray,observationB~ray,'1E-12',observationA,observationB)
  if \tri~valid then do; rejected=rejected+1; return tri; end
  if tri~separation>maximumRaySeparation then do; rejected=rejected+1; return .Vision3DTriangulation~new(tri~point,tri~pointA,tri~pointB,tri~separation,tri~distanceA,tri~distanceB,'SEPARATION_TOO_LARGE',tri~confidence,observationA,observationB); end
  evidence=.array~of(observationA~evidenceRef,observationB~evidenceRef)
  ignored=grid~observePoint(tri~point,.Vision3DState~observedOccupied,tri~confidence,evidence,level,semanticRef)
  accepted=accepted+1
  return tri

/* Run one matched feature through the cheap geometry gate.  Failed or weak
 * geometry becomes a semantic enhancement item instead of forcing a global
 * increase in source resolution. */
::method triangulateOrEnqueue
  expose enhancementQueue
  use strict arg observationA,observationB,region,purpose='GEOMETRY',semanticRef=.nil,level=0,targetConfidence=.85,requiredWidth=.nil,requiredHeight=.nil
  tri=self~triangulate(observationA,observationB,semanticRef,level)
  needs=(tri~status<>'OK')
  if needs=.false then if tri~confidence<targetConfidence then needs=.true
  if needs then do
    reason=tri~status
    if reason='OK' then reason='LOW_CONFIDENCE'
    startTime=min(observationA~timestamp,observationB~timestamp)
    endTime=max(observationA~timestamp,observationB~timestamp)
    item=.Vision3DEnhancementItem~new(purpose,reason,region,startTime,endTime,tri~confidence,targetConfidence,semanticRef)
    ignored=item~addCandidateFrame(observationA~frameRef)
    ignored=item~addCandidateFrame(observationB~frameRef)
    if requiredWidth<>.nil & requiredHeight<>.nil then ignored=item~requireDimensions(requiredWidth,requiredHeight)
    ignored=enhancementQueue~add(item)
  end
  return tri

::method enqueueEnhancement
  expose enhancementQueue
  use strict arg item
  enhancementQueue~add(item)
  return item

/* PLY export is intentionally a diagnostic projection of occupied/inferred
 * sparse cells, not the authoritative reconstruction representation. */
::class Vision3DPlyExporter public
::method export
  use strict arg grid,path,suppressSupport=.true
  points=.array~new
  supplier=grid~cells~supplier
  do while supplier~available
    cell=supplier~item
    state=cell~state
    if (state=.Vision3DState~observedOccupied | state=.Vision3DState~inferredSurface) then do
      if \(suppressSupport & cell~role=.Vision3DCellRole~supportOnly) then points~append(grid~cellCentre(cell))
    end
    supplier~next
  end
  call lineout path,'ply'
  call lineout path,'format ascii 1.0'
  call lineout path,'comment ooRexx Vision 3D sparse-cell diagnostic projection'
  call lineout path,'element vertex' points~items
  call lineout path,'property float x'
  call lineout path,'property float y'
  call lineout path,'property float z'
  call lineout path,'end_header'
  do p over points
    call lineout path,p~x p~y p~z
  end
  call lineout path
  return points~items

::routine rx_v3_floor public
  use strict arg value
  i=trunc(value)
  if value<0 & value<>i then i=i-1
  return i

::requires 'MathsBootstrap.cls'
::requires 'VisionHighResolutionRequest.cls'
