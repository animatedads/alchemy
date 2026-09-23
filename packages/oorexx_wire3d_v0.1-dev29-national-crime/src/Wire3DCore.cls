/* Wire3DCore.cls -- authoritative OO spatial model. Rendering is an adapter concern. */
::class Wire3DVector3 public
::attribute x get
::attribute y get
::attribute z get
::method init
  expose x y z
  use strict arg x, y, z
::method asDirectory
  expose x y z
  d=.directory~new; d['x']=x; d['y']=y; d['z']=z; return d

::class Wire3DQuaternion public
::attribute x get
::attribute y get
::attribute z get
::attribute w get
::method init
  expose x y z w
  use strict arg x=0, y=0, z=0, w=1
::method asDirectory
  expose x y z w
  d=.directory~new; d['x']=x; d['y']=y; d['z']=z; d['w']=w; return d

::class Wire3DTransform public
::attribute position get
::attribute rotation get
::attribute scale get
::method init
  expose position rotation scale
  use strict arg position=.nil, rotation=.nil, scale=.nil
  if position == .nil then position=.Wire3DVector3~new(0,0,0)
  if rotation == .nil then rotation=.Wire3DQuaternion~new(0,0,0,1)
  if scale == .nil then scale=.Wire3DVector3~new(1,1,1)
::method moveTo
  expose position
  use strict arg v; position=v; return self
::method rotateTo
  expose rotation
  use strict arg v; rotation=v; return self
::method resizeTo
  expose scale
  use strict arg v; scale=v; return self
::method asDirectory
  expose position rotation scale
  d=.directory~new; d['position']=position~asDirectory; d['rotation']=rotation~asDirectory; d['scale']=scale~asDirectory; return d

::class Wire3DRepresentation public
::attribute kind get
::attribute label get
::attribute classification get
::method init
  expose kind label classification
  use strict arg kind='block', label='', classification='ordinary'
::method asDirectory
  expose kind label classification
  d=.directory~new; d['kind']=kind; d['label']=label; d['classification']=classification; return d

::class Wire3DSpatialObject public
::attribute spatialId get
::attribute semanticRef get
::attribute parent get
::attribute transform get
::attribute representation get
::attribute metadata get
::method init
  expose spatialId semanticRef representation parent transform metadata
  use strict arg spatialId, semanticRef='', representation=.nil
  parent=.nil; transform=.Wire3DTransform~new; metadata=.directory~new
  if representation == .nil then representation=.Wire3DRepresentation~new('block', spatialId)
::method moveTo
  expose transform
  use strict arg x,y,z; transform~moveTo(.Wire3DVector3~new(x,y,z)); return self
::method rotateTo
  expose transform
  use strict arg x,y,z,w=1; transform~rotateTo(.Wire3DQuaternion~new(x,y,z,w)); return self
::method scaleTo
  expose transform
  use strict arg x,y,z; transform~resizeTo(.Wire3DVector3~new(x,y,z)); return self
::method attachTo
  expose parent
  use strict arg owner
  if owner == self then raise syntax 93.900 array ('A spatial object cannot parent itself')
  parent=owner; return self
::method describe
  expose metadata
  use strict arg name, value; metadata[name]=value; return self
::method evidenceEnvelope
  expose evidenceEnvelope semanticRef
  if \var('evidenceEnvelope') then evidenceEnvelope=.Wire3DEvidenceEnvelope~new(semanticRef,'UNKNOWN')
  return evidenceEnvelope
::method showEvidence
  return self~evidenceEnvelope~asDirectory
::method asDirectory
  expose spatialId semanticRef transform representation metadata parent
  d=.directory~new; d['id']=spatialId; d['semanticRef']=semanticRef; d['transform']=transform~asDirectory; d['representation']=representation~asDirectory; d['metadata']=metadata
  if parent == .nil then d['parentId']=''; else d['parentId']=parent~spatialId
  return d

::class Wire3DSpatialContainer subclass Wire3DSpatialObject public
::method init
  forward class (super)
::method childObjects
  expose children
  if \var('children') then children=.array~new
  return children
::method add
  use strict arg child
  if child~isA(.Wire3DSpatialObject) == .false then raise syntax 93.900 array ('Wire3D containers accept spatial objects')
  self~childObjects~append(child); child~attachTo(self); return child
::method remove
  use strict arg child
  a=self~childObjects; n=.array~new
  do item over a
    if item \== child then n~append(item)
  end
  children=n
  if child~parent == self then child~attachTo(.nil)
  return child

::class Wire3DSpatialEdge public
::attribute edgeId get
::attribute source get
::attribute target get
::attribute relation get
::attribute activity get
::method init
  expose edgeId source target relation activity
  use strict arg edgeId, source, target, relation='relation'
  activity='idle'
::method signal
  expose activity
  use strict arg state='active'; activity=state; return self
::method asDirectory
  expose edgeId source target relation activity
  d=.directory~new; d['id']=edgeId; d['sourceId']=source~spatialId; d['targetId']=target~spatialId; d['relation']=relation; d['activity']=activity; return d

::class Wire3DScene subclass Wire3DSpatialContainer public
::attribute revision get
::attribute title get
::method init
  expose title revision edges
  use strict arg sceneId, title='Wire3D Scene'
  self~init:super(sceneId, 'wire3d:scene/'sceneId, .Wire3DRepresentation~new('scene',title,'infrastructure'))
  revision=0; edges=.array~new
::method edges
  expose edges; return edges
::method add
  expose revision
  use strict arg child
  r=self~add:super(child); revision=revision+1; return r
::method connect
  expose edges revision
  use strict arg source, target, relation='relation'
  id='edge-'||(edges~items+1); e=.Wire3DSpatialEdge~new(id,source,target,relation); edges~append(e); revision=revision+1; return e
::method findById
  use strict arg wanted
  if self~spatialId == wanted then return self
  return self~findIn(self,wanted)
::method findIn private
  use strict arg node, wanted
  if node~isA(.Wire3DSpatialContainer) then do child over node~childObjects
    if child~spatialId == wanted then return child
    found=self~findIn(child,wanted); if found \== .nil then return found
  end
  return .nil
::method snapshot
  expose spatialId title revision edges
  d=.directory~new; d['protocol']='WIRE-3D/0.1'; d['sceneId']=self~spatialId; d['title']=title; d['revision']=revision
  nodes=.array~new; self~appendTree(self,nodes); d['nodes']=nodes
  es=.array~new; do e over edges; es~append(e~asDirectory); end; d['edges']=es
  return d
::method appendTree private
  use strict arg node, out
  if node \== self then out~append(node~asDirectory)
  if node~isA(.Wire3DSpatialContainer) then do child over node~childObjects; self~appendTree(child,out); end

::class Wire3DObjectProjection subclass Wire3DSpatialObject public
::attribute target get
::method init
  expose target
  use strict arg spatialId, target, semanticRef='', representation=.nil
  self~init:super(spatialId,semanticRef,representation)
::method inspect
  expose target
  return target

::class Wire3DAIProjection subclass Wire3DObjectProjection public
::attribute authority get
::attribute provider get
::method init
  expose provider authority
  use strict arg spatialId, target, semanticRef='', provider='unspecified', authority='observe'
  rep=.Wire3DRepresentation~new('institution',spatialId,'ai-service')
  self~init:super(spatialId,target,semanticRef,rep)
  self~describe('actorKind','AI')~describe('presentationRule','NO_MASCOT')

::class Wire3DInteraction public
::method activate abstract
::method select abstract
::method enter abstract
::method leave abstract


/* Passive projection of an existing component/object.  refresh never invokes UNKNOWN;
   it only consumes an explicitly published asDirectory contract. */
::class Wire3DComponentProjection subclass Wire3DObjectProjection public
::attribute projectionState get
::method init
  expose projectionState
  use strict arg spatialId, target, semanticRef='', label='Component'
  rep=.Wire3DRepresentation~new('component',label,'infrastructure')
  self~init:super(spatialId,target,semanticRef,rep)
  projectionState=.directory~new
::method refresh
  expose projectionState
  targetObject=self~target
  if targetObject == .nil then return self
  if targetObject~hasMethod('ASDIRECTORY') == .nil then return self
  state=targetObject~asDirectory
  if state~isA(.Directory) == .false then raise syntax 93.900 array ('Component projection asDirectory must return a Directory')
  projectionState=state
  self~metadata['projectionState']=state
  return self

::class Wire3DSelection public
::attribute object get
::attribute semanticRef get
::method init
  expose object semanticRef
  use strict arg object
  if object == .nil then semanticRef=''; else semanticRef=object~semanticRef

/* Semantic interaction is deliberately renderer-neutral.  A phone tap and a desktop
   click both become select/enter operations against this same session object. */
::class Wire3DInteractionSession subclass Wire3DInteraction public
::attribute scene get
::attribute selection get
::attribute entered get
::method init
  expose scene selection entered
  use strict arg scene
  selection=.nil; entered=.array~new
::method activate
  use strict arg spatialId
  return self~select(spatialId)
::method select
  expose scene selection
  use strict arg spatialId
  obj=scene~findById(spatialId)
  if obj == .nil then return .nil
  selection=.Wire3DSelection~new(obj); return selection
::method enter
  expose scene selection entered
  use strict arg spatialId
  sel=self~select(spatialId); if sel == .nil then return .nil
  obj=sel~object
  if obj~isA(.Wire3DSpatialContainer) then entered~append(obj)
  return obj
::method leave
  expose entered
  if entered~items=0 then return .nil
  old=entered[entered~items]; entered~remove(entered~items); return old

/* GIS is an authoritative source domain, not a Wire3D subsystem.  These classes
   adapt typed GIS geometry into renderer coordinates without reinterpreting the
   source geometry, CRS/SRID, or spatial predicates. */
::class Wire3DGeoPlacement public
::attribute sourceGeometry get
::attribute srid get
::attribute worldPosition get
::attribute placementKind get
::method init
  expose sourceGeometry srid worldPosition placementKind
  use strict arg sourceGeometry, srid, worldPosition, placementKind='geospatial'
  if worldPosition~isA(.Wire3DVector3) == .false then raise syntax 93.900 array ('GIS placement requires a Wire3DVector3 world position')
::method asDirectory
  expose srid worldPosition placementKind
  d=.directory~new; d['kind']=placementKind; d['srid']=srid; d['worldPosition']=worldPosition~asDirectory; return d

/* Adapter protocol.  Implementations own CRS-to-world mapping policy.  Wire3D
   intentionally has no ST_ predicates, coordinate transform engine, or CRS DB. */
::class Wire3DGeoPlacementAdapter public
::method place abstract

/* A bounded adapter useful when the authoritative GIS layer has already supplied
   projected/world coordinates.  It preserves source geometry and SRID verbatim. */
::class Wire3DProjectedCoordinateAdapter subclass Wire3DGeoPlacementAdapter public
::method place
  use strict arg geometry, srid, x, y, z=0
  return .Wire3DGeoPlacement~new(geometry,srid,.Wire3DVector3~new(x,y,z),'projected-coordinate')

::class Wire3DGeoObjectProjection subclass Wire3DObjectProjection public
::attribute geoPlacement get
::method init
  expose geoPlacement
  use strict arg spatialId, target, semanticRef='', label='GIS feature'
  rep=.Wire3DRepresentation~new('geospatial',label,'data')
  self~init:super(spatialId,target,semanticRef,rep)
  geoPlacement=.nil
::method placeFromGIS
  expose geoPlacement
  use strict arg adapter, geometry, srid, x, y, z=0
  if adapter~isA(.Wire3DGeoPlacementAdapter) == .false then raise syntax 93.900 array ('GIS placement requires a Wire3DGeoPlacementAdapter')
  geoPlacement=adapter~place(geometry,srid,x,y,z)
  self~transform~moveTo(geoPlacement~worldPosition)
  self~metadata['gisPlacement']=geoPlacement~asDirectory
  self~metadata['gisAuthority']='SOURCE'
  self~metadata['srid']=srid
  return self

/* Frontier/evidence semantics.  Sampling density is not epistemic confidence. */
::class Wire3DEvidenceState public
::attribute state get
::attribute confidence get
::attribute sourceRef get
::attribute observedAt get
::attribute method get
::method init
  expose state confidence sourceRef observedAt method
  use strict arg state='unknown', confidence=.nil, sourceRef='', observedAt='', method=''
  allowed='SURVEYED OBSERVED RECONSTRUCTED INFERRED UNKNOWN'
  if allowed~wordpos(state~upper)=0 then raise syntax 93.900 array ('Unknown Wire3D evidence state: 'state)
  state=state~upper
  if confidence \== .nil then do
    if \datatype(confidence,'N') then raise syntax 93.900 array ('Evidence confidence must be numeric or .nil')
    if confidence < 0 | confidence > 1 then raise syntax 93.900 array ('Evidence confidence must be in [0,1]')
  end
::method asDirectory
  expose state confidence sourceRef observedAt method
  d=.directory~new; d['state']=state; d['sourceRef']=sourceRef; d['observedAt']=observedAt; d['method']=method
  if confidence == .nil then d['confidence']=''; else d['confidence']=confidence
  return d

::class Wire3DSpatialExtent public
::attribute minX get
::attribute minY get
::attribute maxX get
::attribute maxY get
::method init
  expose minX minY maxX maxY
  use strict arg minX,minY,maxX,maxY
  if maxX < minX | maxY < minY then raise syntax 93.900 array ('Invalid spatial extent')
::method asDirectory
  expose minX minY maxX maxY
  d=.directory~new; d['minX']=minX; d['minY']=minY; d['maxX']=maxX; d['maxY']=maxY; return d

/* One raster/coverage dataset is one semantic projection.  Renderers may derive
   meshes/LODs, but cells and triangles do not become authoritative objects. */
::class Wire3DGeoSurfaceProjection subclass Wire3DObjectProjection public
::attribute sourceDataset get
::attribute srid get
::attribute extent get
::attribute sampleResolution get
::attribute evidence get
::attribute lodPolicy get
::method init
  expose sourceDataset srid extent sampleResolution evidence lodPolicy
  use strict arg spatialId, sourceDataset, semanticRef='', label='GIS surface', srid='', extent=.nil, sampleResolution=.nil, evidence=.nil
  rep=.Wire3DRepresentation~new('terrain-surface',label,'data')
  self~init:super(spatialId,sourceDataset,semanticRef,rep)
  if extent \== .nil then if extent~isA(.Wire3DSpatialExtent) == .false then raise syntax 93.900 array ('Geo surface extent must be Wire3DSpatialExtent')
  if evidence == .nil then evidence=.Wire3DEvidenceState~new('UNKNOWN')
  if evidence~isA(.Wire3DEvidenceState) == .false then raise syntax 93.900 array ('Geo surface evidence must be Wire3DEvidenceState')
  lodPolicy='renderer-owned'
  self~describe('gisAuthority','SOURCE')~describe('resolutionIsCertainty','FALSE')~describe('lodAuthority','RENDERER')
  if srid \== '' then self~describe('srid',srid)
  if sampleResolution \== .nil then self~describe('sampleResolution',sampleResolution)
  self~describe('evidence',evidence~asDirectory)
  if extent \== .nil then self~describe('extent',extent~asDirectory)
::method setEvidence
  expose evidence
  use strict arg newEvidence
  if newEvidence~isA(.Wire3DEvidenceState) == .false then raise syntax 93.900 array ('Geo surface evidence must be Wire3DEvidenceState')
  evidence=newEvidence; self~metadata['evidence']=evidence~asDirectory; return self

/* Generic claim/evidence/qualification semantics.  Wire3D records and projects
   these relationships; it does not promote evidence classes or decide truth. */
::class Wire3DClaim public
::attribute claimId get
::attribute property get
::attribute declaredValue get
::attribute sourceRef get
::attribute status get
::method init
  expose claimId property declaredValue sourceRef status
  use strict arg claimId, property, declaredValue, sourceRef='', status='DECLARED'
::method asDirectory
  expose claimId property declaredValue sourceRef status
  d=.directory~new; d['id']=claimId; d['property']=property; d['declaredValue']=declaredValue; d['sourceRef']=sourceRef; d['status']=status; return d

::class Wire3DEvidence public
::attribute evidenceId get
::attribute classification get
::attribute sourceRef get
::attribute method get
::attribute observedAt get
::attribute payload get
::method init
  expose evidenceId classification sourceRef method observedAt payload
  use strict arg evidenceId, classification, sourceRef='', method='', observedAt='', payload=.nil
  if payload == .nil then payload=.directory~new
::method asDirectory
  expose evidenceId classification sourceRef method observedAt payload
  d=.directory~new; d['id']=evidenceId; d['classification']=classification; d['sourceRef']=sourceRef; d['method']=method; d['observedAt']=observedAt; d['payload']=payload; return d

::class Wire3DQualification public
::attribute qualificationId get
::attribute claimId get
::attribute evidenceIds get
::attribute evaluatorRef get
::attribute method get
::attribute status get
::attribute metrics get
::attribute measuredAt get
::method init
  expose qualificationId claimId evidenceIds evaluatorRef method status metrics measuredAt
  use strict arg qualificationId, claimId, evidenceIds=.nil, evaluatorRef='', method='', status='UNASSESSED', metrics=.nil, measuredAt=''
  if evidenceIds == .nil then evidenceIds=.array~new
  if metrics == .nil then metrics=.directory~new
::method asDirectory
  expose qualificationId claimId evidenceIds evaluatorRef method status metrics measuredAt
  d=.directory~new; d['id']=qualificationId; d['claimId']=claimId; d['evidenceIds']=evidenceIds; d['evaluatorRef']=evaluatorRef; d['method']=method; d['status']=status; d['metrics']=metrics; d['measuredAt']=measuredAt; return d

/* Evidence view is deliberately passive.  It is a projection receipt suitable
   for SHOW EVIDENCE; no domain action or authority is acquired by opening it. */
::class Wire3DEvidenceEnvelope public
::attribute semanticRef get
::attribute dataClassification get
::attribute claims get
::attribute evidence get
::attribute qualifications get
::method init
  expose semanticRef dataClassification claims evidence qualifications
  use strict arg semanticRef='', dataClassification='UNKNOWN'
  claims=.array~new; evidence=.array~new; qualifications=.array~new
::method addClaim
  expose claims
  use strict arg item
  if item~isA(.Wire3DClaim) == .false then raise syntax 93.900 array ('Evidence envelope requires Wire3DClaim')
  claims~append(item); return item
::method addEvidence
  expose evidence
  use strict arg item
  if item~isA(.Wire3DEvidence) == .false then raise syntax 93.900 array ('Evidence envelope requires Wire3DEvidence')
  evidence~append(item); return item
::method addQualification
  expose qualifications
  use strict arg item
  if item~isA(.Wire3DQualification) == .false then raise syntax 93.900 array ('Evidence envelope requires Wire3DQualification')
  qualifications~append(item); return item
::method asDirectory
  expose semanticRef dataClassification claims evidence qualifications
  d=.directory~new; d['semanticRef']=semanticRef; d['dataClassification']=dataClassification
  ca=.array~new; do c over claims; ca~append(c~asDirectory); end; d['claims']=ca
  ea=.array~new; do e over evidence; ea~append(e~asDirectory); end; d['evidence']=ea
  qa=.array~new; do q over qualifications; qa~append(q~asDirectory); end; d['qualifications']=qa
  return d

/* Revision/delta protocol.  A delta describes a projection change; it does not
   acquire authority over the semantic object that caused that change. */
::class Wire3DDeltaOperation public
::attribute operation get
::attribute objectId get
::attribute payload get
::method init
  expose operation objectId payload
  use strict arg operation, objectId='', payload=.nil
  operation=operation~upper
  allowed='ADD_NODE UPDATE_NODE REMOVE_NODE ADD_EDGE UPDATE_EDGE REMOVE_EDGE EVIDENCE'
  if allowed~wordpos(operation)=0 then raise syntax 93.900 array ('Unknown Wire3D delta operation: 'operation)
  if payload == .nil then payload=.directory~new
::method asDirectory
  expose operation objectId payload
  d=.directory~new; d['op']=operation; d['objectId']=objectId; d['payload']=payload; return d

::class Wire3DSceneDelta public
::attribute sceneId get
::attribute baseRevision get
::attribute revision get
::attribute operations get
::attribute deltaId get
::method init
  expose sceneId baseRevision revision operations deltaId
  use strict arg sceneId, baseRevision, revision, deltaId=''
  if revision <= baseRevision then raise syntax 93.900 array ('Wire3D delta revision must advance')
  if deltaId='' then deltaId=sceneId':'baseRevision'->'revision
  operations=.array~new
::method append
  expose operations
  use strict arg op
  if op~isA(.Wire3DDeltaOperation) == .false then raise syntax 93.900 array ('Scene delta requires Wire3DDeltaOperation')
  operations~append(op); return op
::method asDirectory
  expose sceneId baseRevision revision operations deltaId
  d=.directory~new; d['protocol']='WIRE-3D-DELTA/0.1'; d['deltaId']=deltaId; d['sceneId']=sceneId; d['baseRevision']=baseRevision; d['revision']=revision
  a=.array~new; do op over operations; a~append(op~asDirectory); end; d['operations']=a; return d

/* Renderer/session view state.  Camera state is intentionally client-local: a
   phone may inspect the same semantic scene without stealing the auditorium camera. */
::class Wire3DClientView public
::attribute clientId get
::attribute selectedId get
::attribute camera get
::method init
  expose clientId selectedId camera
  use strict arg clientId
  selectedId=''; camera=.directory~new
::method select
  expose selectedId
  use strict arg spatialId; selectedId=spatialId; return self
::method setCamera
  expose camera
  use strict arg yaw, pitch, distance
  camera['yaw']=yaw; camera['pitch']=pitch; camera['distance']=distance; return self
::method asDirectory
  expose clientId selectedId camera
  d=.directory~new; d['clientId']=clientId; d['selectedId']=selectedId; d['camera']=camera; return d
