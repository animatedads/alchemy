/* ooRexx Vision 3D -> Wire3D projection adapter v0.1-dev2
 *
 * Authority boundary:
 *   Vision 3D Reconstruction owns reconstruction/evidence semantics.
 *   Wire3D owns renderer-neutral spatial projection and scene revision fences.
 *   ooRexx Maths v0.8 owns all model/view transform mathematics.
 *
 * This adapter never promotes inferred geometry to observed geometry and never
 * fills UNSEEN/OCCLUDED_UNKNOWN volume merely to make a prettier scene.
 */

::class Vision3DWireProjection public
::method init
  expose grid scene projectionRevision publishedCells publishedNodeIds lastCameraNode sceneId title
  use strict arg grid,sceneId='vision-reconstruction',title='VISION 3D RECONSTRUCTION'
  if \grid~isA(.VisionAdaptiveGrid3D) then raise syntax 40.900 array('VisionAdaptiveGrid3D required')
  scene=.Wire3DScene~new(sceneId,title)
  projectionRevision=scene~revision
  publishedCells=.directory~new
  publishedNodeIds=.directory~new
  lastCameraNode=.nil
::attribute grid get
::attribute scene get
::attribute projectionRevision get

::method projectGrid
  expose grid scene
  use strict arg includeObservedFree=.false,includeInferredFree=.false,suppressSupport=.false
  supplier=grid~cells~supplier
  added=0
  do while supplier~available
    cell=supplier~item
    if self~renderCell(cell,includeObservedFree,includeInferredFree,suppressSupport) then do
      node=self~nodeForCell(cell)
      if scene~findById(node~spatialId)==.nil then do
        scene~add(node); added=added+1
      end
    end
    supplier~next
  end
  return added


/* Surface skin is an explicit inferred layer, not a renderer trick.  Each
 * triangle is projected as a semantic Wire3D object whose metadata carries the
 * local triangle vertices and the supporting reconstruction-cell keys. */
::method projectFacets
  expose grid scene sceneId
  use strict arg maxEdgeCells=2.25,minQuality=.08
  builder=.Vision3DFacetBuilder~new(grid,maxEdgeCells,minQuality)
  facets=builder~build
  added=0
  do facet over facets
    node=self~nodeForFacet(facet)
    if scene~findById(node~spatialId)==.nil then do
      scene~add(node); added=added+1
    end
  end
  return added

::method nodeForFacet
  expose sceneId
  use strict arg facet
  centre=facet~centroid
  id='v3d-' || facet~facetId
  semanticRef='vision3d://' || sceneId || '/surface/' || facet~facetId
  node=.Wire3DSpatialObject~new(id,semanticRef,.Wire3DRepresentation~new('vision-facet','INFERRED SURFACE ' || facet~facetId,'evidence-inferred'))
  node~moveTo(centre~x,centre~y,centre~z)
  a=facet~pointA-centre; b=facet~pointB-centre; c=facet~pointC-centre
  geometry=.directory~new
  geometry['primitive']='TRIANGLE'
  geometry['vertices']=.array~of(a~x,a~y,a~z,b~x,b~y,b~z,c~x,c~y,c~z)
  geometry['normal']=.array~of(facet~normal~x,facet~normal~y,facet~normal~z)
  node~describe('geometry',geometry)
  node~describe('evidenceState',.Vision3DState~inferredSurface)
  node~describe('confidence',facet~confidence)
  node~describe('sourceCellKeys',facet~sourceCellKeys)
  node~describe('reconstructionAuthority','VISION_3D')
  node~describe('inferenceRule','LOCAL_THREE_CELL_SURFACE')
  return node

::method renderCell
  use strict arg cell,includeObservedFree=.false,includeInferredFree=.false,suppressSupport=.false
  if suppressSupport & cell~role=.Vision3DCellRole~supportOnly then return .false
  state=cell~state
  if state=.Vision3DState~observedOccupied then return .true
  if state=.Vision3DState~inferredSurface then return .true
  if state=.Vision3DState~conflictingObserved then return .true
  if state=.Vision3DState~observedFree then return includeObservedFree
  if state=.Vision3DState~inferredFree then return includeInferredFree
  return .false

::method nodeForCell
  expose grid sceneId
  use strict arg cell
  centre=grid~cellCentre(cell)
  size=grid~cellSizeAt(cell~level)
  state=cell~state
  classification=self~classificationFor(cell)
  label=state || ' ' || cell~key
  semanticRef=cell~semanticRef
  if semanticRef==.nil then semanticRef='vision3d://' || sceneId || '/cell/' || cell~key
  id=self~nodeIdForCell(cell)
  node=.Wire3DSpatialObject~new(id,semanticRef,.Wire3DRepresentation~new('vision-cell',label,classification))
  node~moveTo(centre~x,centre~y,centre~z)
  half=size/2
  node~scaleTo(half,half,half)
  node~describe('evidenceState',state)
  node~describe('confidence',cell~confidence)
  node~describe('cellRole',cell~role)
  node~describe('gridLevel',cell~level)
  node~describe('gridCellSize',size)
  node~describe('visionCellKey',cell~key)
  node~describe('evidenceCount',cell~evidenceRefs~items)
  node~describe('reconstructionAuthority','VISION_3D')
  return node

::method classificationFor
  use strict arg cell
  if cell~role=.Vision3DCellRole~supportOnly then return 'evidence-support'
  select
    when cell~state=.Vision3DState~observedOccupied then return 'evidence-observed'
    when cell~state=.Vision3DState~inferredSurface then return 'evidence-inferred'
    when cell~state=.Vision3DState~conflictingObserved then return 'evidence-conflict'
    when cell~state=.Vision3DState~observedFree then return 'evidence-free'
    when cell~state=.Vision3DState~inferredFree then return 'evidence-free-inferred'
    otherwise return 'evidence-unknown'
  end

::method nodeIdForCell
  use strict arg cell
  return 'v3d-cell-' || cell~level || '-' || cell~ix || '-' || cell~iy || '-' || cell~iz

::method addCameraPose
  expose scene lastCameraNode
  use strict arg poseId,cameraToWorld,frameRef='',timestamp=''
  if \cameraToWorld~isA(.MathTransform3D) then raise syntax 40.900 array('MathTransform3D cameraToWorld required')
  ctx=.Wire3DMathsAdapter~context
  origin=cameraToWorld*.MathVector3~new(0,0,0,cameraToWorld~context)
  node=.Wire3DSpatialObject~new('v3d-camera-' || poseId,'vision3d:camera/' || poseId,.Wire3DRepresentation~new('camera','CAMERA ' || poseId,'evidence-camera'))
  node~moveTo(origin~x,origin~y,origin~z)~scaleTo(.06,.06,.06)
  node~describe('frameRef',frameRef)~describe('timestamp',timestamp)~describe('reconstructionAuthority','VISION_3D')
  scene~add(node)
  if lastCameraNode\==.nil then scene~connect(lastCameraNode,node,'camera-trajectory')~signal('observed')
  lastCameraNode=node
  return node

::method snapshot
  expose scene grid projectionRevision publishedCells publishedNodeIds
  use strict arg eye=.nil,target=.nil
  snapshot=scene~snapshot
  /* Projection revision is distinct from domain state; snapshots and deltas use
     this monotonic fence even when an existing node merely gains evidence. */
  projectionRevision=max(projectionRevision,scene~revision)
  snapshot['revision']=projectionRevision
  do nd over snapshot['nodes']
    object=scene~findById(nd['id'])
    nd['modelMatrix']=.Wire3DMathsAdapter~columnMajor(.Wire3DMathsAdapter~transform(object~transform))
  end
  fit=self~fitView(snapshot,eye,target)
  snapshot['camera']=fit
  contract=.directory~new
  contract['matrixStorage']='COLUMN_MAJOR'; contract['vectorConvention']='COLUMN_VECTOR'; contract['clipConvention']='OPENGL'
  contract['projectionAuthority']='VIEWPORT_ADAPTER'; contract['mathAuthority']='OOREXX_MATHS_V0.8'
  snapshot['rendererContract']=contract
  reconstruction=.directory~new
  reconstruction['authority']='VISION_3D_RECONSTRUCTION'
  reconstruction['gridSummary']=grid~summary
  reconstruction['unknownRule']='UNSEEN_AND_OCCLUDED_ARE_NOT_RENDERED_AS_OCCUPIED'
  reconstruction['supportRule']='SUPPORT_ONLY_IS_CALIBRATION_GEOMETRY'
  reconstruction['surfaceFacetRule']='LOCAL_TRIANGLES_ARE_INFERRED_SURFACE_NOT_OBSERVED'
  snapshot['reconstruction']=reconstruction
  self~seedPublished
  return snapshot

::method fitView private
  use strict arg snapshot,eye=.nil,target=.nil
  nodes=snapshot['nodes']
  if nodes~items=0 then do
    centre=.Wire3DVector3~new(0,0,0); span=2
  end
  else do
    first=.true
    do nd over nodes
      p=nd['transform']['position']
      x=p['x']; y=p['y']; z=p['z']
      if first then do; minx=x;maxx=x;miny=y;maxy=y;minz=z;maxz=z;first=.false; end
      else do
        minx=min(minx,x); maxx=max(maxx,x); miny=min(miny,y); maxy=max(maxy,y); minz=min(minz,z); maxz=max(maxz,z)
      end
    end
    cx=(minx+maxx)/2; cy=(miny+maxy)/2; cz=(minz+maxz)/2
    centre=.Wire3DVector3~new(cx,cy,cz)
    span=max(maxx-minx,maxy-miny,maxz-minz)
    if span<1 then span=1
  end
  if target==.nil then target=centre
  if eye==.nil then eye=.Wire3DVector3~new(target~x+span*.35,target~y+span*.65,target~z+span*2.4)
  far=max(50,span*20)
  camera=.Wire3DSpatialCamera~new(eye,target,.Wire3DVector3~new(0,1,0),55,.01,far)
  d=camera~asDirectory
  d['viewMatrix']=.Wire3DMathsAdapter~columnMajor(camera~viewTransform)
  return d

::method seedPublished private
  expose grid publishedCells publishedNodeIds scene projectionRevision
  publishedCells=.directory~new; publishedNodeIds=.directory~new
  supplier=grid~cells~supplier
  do while supplier~available
    cell=supplier~item
    if self~renderCell(cell) then do
      key=cell~key
      publishedCells[key]=self~fingerprint(cell)
      publishedNodeIds[key]=self~nodeIdForCell(cell)
    end
    supplier~next
  end
  projectionRevision=max(projectionRevision,scene~revision)
  return publishedCells~items

/* Compare current reconstruction evidence to the last published snapshot/delta.
 * Payloads are complete node projections, so a consumer never has to guess how
 * to merge evidence-state changes. */
::method deltaForChanges
  expose grid scene projectionRevision publishedCells publishedNodeIds
  use strict arg includeObservedFree=.false,includeInferredFree=.false,suppressSupport=.false
  base=projectionRevision
  operations=.array~new
  currentKeys=.set~new
  supplier=grid~cells~supplier
  do while supplier~available
    cell=supplier~item
    if self~renderCell(cell,includeObservedFree,includeInferredFree,suppressSupport) then do
      key=cell~key; currentKeys[key]=key
      fp=self~fingerprint(cell)
      node=self~nodeForCell(cell)
      payload=self~nodeDirectory(node)
      if \publishedCells~hasIndex(key) then do
        scene~add(node)
        operations~append(.Wire3DDeltaOperation~new('ADD_NODE',node~spatialId,payload))
      end
      else if publishedCells[key]<>fp then do
        old=scene~findById(publishedNodeIds[key])
        if old\==.nil then scene~remove(old)
        scene~add(node)
        operations~append(.Wire3DDeltaOperation~new('UPDATE_NODE',node~spatialId,payload))
      end
      publishedCells[key]=fp; publishedNodeIds[key]=node~spatialId
    end
    supplier~next
  end
  /* Sparse evidence normally only grows, but explicit suppression/state changes
     may remove a previously projected cell. */
  oldKeys=.array~new
  do key over publishedCells
    if \currentKeys~hasIndex(key) then oldKeys~append(key)
  end
  do key over oldKeys
    nodeId=publishedNodeIds[key]
    old=scene~findById(nodeId)
    if old\==.nil then scene~remove(old)
    operations~append(.Wire3DDeltaOperation~new('REMOVE_NODE',nodeId))
    publishedCells~remove(key); publishedNodeIds~remove(key)
  end
  if operations~items=0 then return .nil
  projectionRevision=base+1
  delta=.Wire3DSceneDelta~new(scene~spatialId,base,projectionRevision)
  do op over operations; delta~append(op); end
  return delta

::method nodeDirectory private
  use strict arg node
  d=node~asDirectory
  d['modelMatrix']=.Wire3DMathsAdapter~columnMajor(.Wire3DMathsAdapter~transform(node~transform))
  return d

::method fingerprint private
  use strict arg cell
  semantic=cell~semanticRef; if semantic==.nil then semantic=''
  return cell~state || '|' || cell~confidence || '|' || cell~role || '|' || cell~level || '|' || semantic || '|' || cell~evidenceRefs~items

::requires 'Vision3DReconstruction.cls'
::requires 'Wire3DAll.cls'
