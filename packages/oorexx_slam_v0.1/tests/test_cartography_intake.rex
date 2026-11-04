/* Native ooRexx contract qualification. Synthetic maps are NOT Sydney surveys. */
numeric digits 20
checks=0
source=.HarbourCartographyIntake
m1=makeMap('OVERVIEW',2,'a'~copies(64),'ROUGH_MAP_ESTIMATE')
m2=makeMap('DETAIL',1,'b'~copies(64),'ROUGH_MAP_ESTIMATE')
a=source~evaluate(m1);b=source~evaluate(m2)
call ok a['STATUS']='REGISTERED_MAP_ESTIMATE_ONLY','overview unsurveyed'
call ok b['STATUS']='REGISTERED_MAP_ESTIMATE_ONLY','detail unsurveyed'
call ok a['HOLDOUT_MAX_M']<0.001,'overview independent holdout'
call ok b['HOLDOUT_MAX_M']<0.001,'detail independent holdout'
call ok abs(a['EAST_AFFINE'][2]-2)<0.000001,'overview map scale'
call ok abs(b['EAST_AFFINE'][2]-1)<0.000001,'detail map scale'
call ok source~waterPixel(a,80,80)='UNKNOWN_NOT_QUALIFIED','unsurveyed water not admissible'
call ok source~waterPixel(b,80,80)='UNKNOWN_NOT_QUALIFIED','unverified water not admissible'
r=source~reconcile(a,b)
call ok r['STATUS']='TWO_MAPS_RECONCILED_ESTIMATE_ONLY','separate scales merge only as estimate'
call ok r['COMMON_CONTROL_COUNT']=4,'common control IDs'
call ok \r['METRIC_WATER_MASK_ALLOWED'],'never fake survey'
q=source~imageToGeo(a,60,80)
call ok abs(q[1]-(-33.85+410/111200))<0.00000001,'overview maps holdout latitude'
call ok abs(q[2]-(151.2+620/92300))<0.00000001,'overview maps holdout longitude'
q=source~imageToGeo(b,120,160)
call ok abs(q[1]-(-33.85+410/111200))<0.00000001,'zoom differential latitude'
call ok abs(q[2]-(151.2+620/92300))<0.00000001,'zoom differential longitude'
paout=source~geographicOutlines(a);pbout=source~geographicOutlines(b)
pa=paout['POLYGONS'];pb=pbout['POLYGONS']
call ok paout['REGISTRATION_STATUS']='REGISTERED_MAP_ESTIMATE_ONLY','converted outline retains provenance'
call ok \paout['METRIC_WATER_MASK_ALLOWED'],'converted outline never loses rejection'
call ok pa~items=1 & pb~items=1,'both maps project water polygon'
call ok pa[1]~items=5 & pb[1]~items=5,'closed geographic polygon'
call ok abs(pa[1][1][1]-pb[1][1][1])<0.00000001,'same shoreline latitude after independent scales'
call ok abs(pa[1][3][2]-pb[1][3][2])<0.00000001,'same shoreline longitude after independent scales'
map=makeMap('BADHASH',2,'not-a-real-source','ROUGH_MAP_ESTIMATE')
call ok source~evaluate(map)['STATUS']='BAD_SOURCE_HASH','reject invalid SHA'
map=makeMap('BADCRS',2,'c'~copies(64),'ROUGH_MAP_ESTIMATE');map['CRS']='EPSG:3857'
call ok source~evaluate(map)['STATUS']='UNSUPPORTED_CRS','reject undeclared projection conversion'
map=makeMap('NOGROUND',2,'c'~copies(64),'ROUGH_MAP_ESTIMATE');map['CONTROLS'][4]['ROLE']='FIT'
call ok source~evaluate(map)['STATUS']='NEED_EXACTLY_THREE_FIT_CONTROLS','reject no independent holdout'
map=makeMap('BADHOLD',2,'c'~copies(64),'ROUGH_MAP_ESTIMATE');map['CONTROLS'][4]['LAT']=map['CONTROLS'][4]['LAT']+0.0003
call ok source~evaluate(map)['STATUS']='HOLDOUT_REPROJECTION_FAILED','reject >3m holdout'
map=makeMap('OPEN',2,'d'~copies(64),'ROUGH_MAP_ESTIMATE');map['WATER_POLYGONS'][1][5]=.array~of(21,21)
call ok source~evaluate(map)['STATUS']='OPEN_WATER_POLYGON','reject unclosed geometry'
map=makeMap('BOWTIE',2,'d'~copies(64),'ROUGH_MAP_ESTIMATE')
map['WATER_POLYGONS'][1]=.array~of(.array~of(10,10),.array~of(140,140),.array~of(140,10),.array~of(10,140),.array~of(10,10))
call ok source~evaluate(map)['STATUS']='SELF_INTERSECTING_WATER_POLYGON','reject bow-tie polygon even if closed'
map=makeMap('REPEAT',2,'d'~copies(64),'ROUGH_MAP_ESTIMATE')
map['WATER_POLYGONS'][1][3]=map['WATER_POLYGONS'][1][2]
call ok source~evaluate(map)['STATUS']='SELF_INTERSECTING_WATER_POLYGON','reject zero-length polygon edge'
map=makeMap('COLLINEAR',2,'e'~copies(64),'ROUGH_MAP_ESTIMATE');map['CONTROLS'][3]['Y']=20
call ok source~evaluate(map)['STATUS']='COLLINEAR_FIT_CONTROLS','reject impossible affine fit'
map=makeMap('DUPLICATE',2,'f'~copies(64),'ROUGH_MAP_ESTIMATE');map['CONTROLS'][4]['ID']='A'
call ok source~evaluate(map)['STATUS']='DUPLICATE_OR_EMPTY_CONTROL_ID','reject duplicate feature ID'
map=makeMap('BADVERTEX',2,'c'~copies(64),'ROUGH_MAP_ESTIMATE');map['WATER_POLYGONS'][1][2]=.array~of(-2,60)
call ok source~evaluate(map)['STATUS']='VERTEX_OUTSIDE_IMAGE','reject out-of-bounds polygon'
map=makeMap('SURVEY',2,'d'~copies(64),'VERIFIED_SURVEYED_WATER_BOUNDARY')
do c over map['CONTROLS']; c['PROVENANCE']='SURVEYED_GEO_CONTROL';end
s=source~evaluate(map)
call ok s['STATUS']='SURVEY_CLAIM_UNVERIFIED','self-asserted survey claim untrusted'
call ok \s['METRIC_WATER_MASK_ALLOWED'],'no self-authorised survey proof'
call ok source~waterPixel(s,80,80)='UNKNOWN_NOT_QUALIFIED','survey claim cannot mark water'
call ok source~waterPixel(s,8,8)='UNKNOWN_NOT_QUALIFIED','outside water not proof of land'
map=makeMap('BOUNDS',2,'a'~copies(64),'ROUGH_MAP_ESTIMATE');map['CONTROLS'][1]['X']=-1
call ok source~evaluate(map)['STATUS']='CONTROL_OUTSIDE_IMAGE','reject control outside image'
map=makeMap('NOMAP',2,'a'~copies(64),'ROUGH_MAP_ESTIMATE');map['WATER_POLYGONS']=.array~new
call ok source~evaluate(map)['STATUS']='NO_WATER_POLYGON','reject missing hydrography'
map=makeMap('BADROLE',2,'a'~copies(64),'ROUGH_MAP_ESTIMATE');map['CONTROLS'][4]['ROLE']='TRAIN'
call ok source~evaluate(map)['STATUS']='BAD_CONTROL_ROLE','reject roles without holdout'
map=makeMap('MISMATCH',2,'a'~copies(64),'ROUGH_MAP_ESTIMATE');map['CONTROLS'][4]['LAT']=map['CONTROLS'][4]['LAT']+0.0002
call ok source~reconcile(a,source~evaluate(map))['STATUS']='PAIR_HOLDOUT_FAILED','reject bad pair'
map=makeMap('NO_SHARED',2,'e'~copies(64),'ROUGH_MAP_ESTIMATE')
do c over map['CONTROLS'];c['ID']='DIFF_'c['ID'];end
call ok source~reconcile(a,source~evaluate(map))['STATUS']='INSUFFICIENT_COMMON_LANDMARKS','reject unlinked screenshots'
map=makeMap('INCONSISTENT',2,'e'~copies(64),'ROUGH_MAP_ESTIMATE');map['CONTROLS'][1]['LON']=map['CONTROLS'][1]['LON']+0.0002
call ok source~reconcile(a,source~evaluate(map))['STATUS']='INCONSISTENT_COMMON_LANDMARKS','reject distorted controls'
call ok source~reconcile(a,a)['STATUS']='SAME_IMAGE_NOT_INDEPENDENT','no duplicate as independent image'
say 'POWER SLAM CARTOGRAPHY INTAKE PASS' checks 'checks'
exit 0
ok: procedure expose checks
  use arg condition,label
  if \condition then do
    say 'FAIL' label
    exit 2
  end
  checks+=1
  return
makeMap: procedure
  use arg id,scale,sha,boundary
  c=.HarbourCartographyIntake
  d=.directory~new
  d['MAP_ID']=id;d['SOURCE_SHA256']=sha;d['WIDTH']=300;d['HEIGHT']=300
  d['CRS']='EPSG:4326';d['BOUNDARY_SOURCE']=boundary
  pts=.array~new
  /* First screenshot's fixed landmark pixel positions are half the second's,
     but both project onto the same independent longitude and latitude. */
  do each over .array~of(.array~of('A',20,20,'FIT'),.array~of('B',120,20,'FIT'),.array~of('C',20,120,'FIT'),.array~of('H',60,80,'HOLDOUT'))
    x=each[2]*2/scale;y=each[3]*2/scale
    east=500+each[2]*2;north=250+each[3]*2
    pts~append(c~point(each[1],x,y,-33.85+north/111200,151.2+east/92300,each[4],'ROUGH_USER_PLACED_MAP_POINT'))
  end
  d['CONTROLS']=pts
  step=2/scale
  poly=.array~of(.array~of(10*step,10*step),.array~of(140*step,10*step),.array~of(140*step,140*step),.array~of(10*step,140*step),.array~of(10*step,10*step))
  d['WATER_POLYGONS']=.array~of(poly)
  return d
::requires 'SlamHarbourCartographyIntake.cls'