call addPath
s=.Wire3DScene~new('t','test')
a=.Wire3DSpatialObject~new('a','object://a')~moveTo(1,2,3)
b=.Wire3DSpatialObject~new('b','object://b')
s~add(a); s~add(b); e=s~connect(a,b,'calls')~signal('active')
call assert s~childObjects~items=2,'two nodes'
call assert s~edges~items=1,'one edge'
call assert a~transform~position~x=1,'position'
call assert e~activity='active','activity'
jsonCodec=.JSON~new
j=jsonCodec~toJSON(s~snapshot)
call assert j~length>0,'snapshot encoded by system JSON.cls'
call assert j~pos('object:\/\/a')>0 | j~pos('object://a')>0,'semantic ref encoded by system JSON.cls'
roundTrip=jsonCodec~fromJSON(j)
call assert roundTrip['protocol']='WIRE-3D/0.1','system JSON.cls round-trip protocol'
call assert roundTrip['sceneId']='t','system JSON.cls round-trip scene id'
ai=.Wire3DAIProjection~new('agent','x','ai://x','provider','OBSERVE')
call assert ai~metadata['presentationRule']='NO_MASCOT','no mascot invariant'
call assert s~findById('a') == a,'find by id'
session=.Wire3DInteractionSession~new(s)
sel=session~select('a')
call assert sel~object == a,'semantic selection'
call assert sel~semanticRef='object://a','selection semantic ref'
probe=.Wire3DTestProjectionTarget~new
cp=.Wire3DComponentProjection~new('cp',probe,'component://probe','Probe')
cp~refresh
call assert cp~projectionState['status']='ACTIVE','passive component projection'
call assert cp~metadata['projectionState']['count']=3,'projection facts retained'
g=.directory~new; g['geometryType']='POINT'; g['payload']='opaque-gpkg-geometry'
ga=.Wire3DProjectedCoordinateAdapter~new
gp=.Wire3DGeoObjectProjection~new('geo-1',g,'nosql://gis/features/1','Authoritative GIS feature')
gp~placeFromGIS(ga,g,27700,10,20,3)
call assert gp~geoPlacement~sourceGeometry == g,'GIS geometry identity preserved'
call assert gp~geoPlacement~srid=27700,'GIS SRID preserved'
call assert gp~transform~position~x=10,'GIS world placement applied'
call assert gp~metadata['gisAuthority']='SOURCE','GIS authority marker'
source=.directory~new; source['kind']='synthetic-dem'; source['widthCells']=1000; source['heightCells']=1000
ev=.Wire3DEvidenceState~new('INFERRED',0.72,'observation://frontier/model-42','','frontier-model')
ext=.Wire3DSpatialExtent~new(0,0,1000,1000)
surf=.Wire3DGeoSurfaceProjection~new('terrain',source,'nosql://gis/dem/frontier','Frontier DEM','LOCAL',ext,1,ev)
call assert surf~target == source,'surface source identity preserved'
call assert surf~metadata['sampleResolution']=1,'one metre sample resolution retained'
call assert surf~metadata['resolutionIsCertainty']='FALSE','resolution is not certainty invariant'
call assert surf~metadata['evidence']['state']='INFERRED','evidence state retained'
call assert surf~lodPolicy='renderer-owned','LOD renderer-owned'
claim=.Wire3DClaim~new('claim-resolution','resolution','1.000m','generator://fixture','VERIFIED')
ev2=.Wire3DEvidence~new('evidence-dem','INFERRED','frontier-model://42','synthetic-terrain-fbm')
metrics=.directory~new; metrics['nominalDistanceM']=100; metrics['p95DzM']=11.204; metrics['maxDzM']=14.1
ids=.array~new; ids~append('evidence-dem')
qual=.Wire3DQualification~new('qual-dz','claim-relief',ids,'fixture://terrain-auditor','exact-bilinear-directional-delta-audit','QUALIFIED_WITH_VARIANCE',metrics)
env=surf~evidenceEnvelope
env~addClaim(claim); env~addEvidence(ev2); env~addQualification(qual)
receipt=surf~showEvidence
call assert receipt['dataClassification']='UNKNOWN','projection does not promote source evidence class'
call assert receipt['claims'][1]['property']='resolution','claim retained'
call assert receipt['evidence'][1]['classification']='INFERRED','inferred data remains inferred'
call assert receipt['qualifications'][1]['status']='QUALIFIED_WITH_VARIANCE','qualification retained separately'
call assert receipt['qualifications'][1]['metrics']['nominalDistanceM']=100,'qualification metrics retained'
call assert a~transform~rotation~w=1,'quaternion identity rotation'
delta=.Wire3DSceneDelta~new('t',3,4,'delta-test-4')
p=.directory~new; p['activity']='blocked'
delta~append(.Wire3DDeltaOperation~new('UPDATE_EDGE','edge-1',p))
dd=delta~asDirectory
call assert dd['protocol']='WIRE-3D-DELTA/0.1','delta protocol'
call assert dd['baseRevision']=3 & dd['revision']=4,'delta revision fence'
call assert dd['operations'][1]['payload']['activity']='blocked','delta payload retained'
viewA=.Wire3DClientView~new('auditorium')~setCamera(.4,.3,14)~select('terrain')
viewB=.Wire3DClientView~new('phone')~setCamera(1.2,.8,6)~select('terrain')
call assert viewA~camera['distance']=14,'auditorium camera independent'
call assert viewB~camera['distance']=6,'phone camera independent'
call assert viewA~selectedId=viewB~selectedId,'semantic selection can agree without camera coupling'
fakeServer=.Wire3DTestWireUIServer~new
publisher=.Wire3DWireUIPublisher~new(fakeServer,'PHONE-1')
r=publisher~publishSnapshot(s,'corr-snap')
call assert r='OK','Wire UI snapshot publisher returns server result'
call assert fakeServer~lastAccessPoint='PHONE-1','publisher retains access point binding'
call assert fakeServer~lastMessage['type']='WIRE3D_SNAPSHOT','snapshot semantic type'
call assert fakeServer~lastMessage['snapshot']['protocol']='WIRE-3D/0.1','snapshot payload preserved'
r=publisher~publishDelta(delta,'corr-delta')
call assert fakeServer~lastMessage['type']='WIRE3D_DELTA','delta semantic type'
call assert fakeServer~lastMessage['delta']['baseRevision']=3,'delta revision fence preserved through Wire UI adapter'
say 'PASS test_core'
exit 0

assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
addPath: procedure
  here=filespec('location',parse source . . src)
  call value 'REXX_PATH', here'../src:'value('REXX_PATH',,'ENVIRONMENT'),'ENVIRONMENT'; return

::requires 'Wire3DAll.cls'
::class Wire3DTestProjectionTarget
::method asDirectory
  d=.directory~new; d['status']='ACTIVE'; d['count']=3; return d

::class Wire3DTestWireUIServer
::attribute lastAccessPoint get
::attribute lastMessage get
::attribute lastCorrelation get
::method enqueueToAccessPoint
  expose lastAccessPoint lastMessage lastCorrelation
  use strict arg lastAccessPoint,lastMessage,lastCorrelation=''
  return 'OK'
