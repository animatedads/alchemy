/* Power SLAM v0.18: source-qualified map imagery intake from image-reading SLAM.
 * Architecture Tom Dyer. Implementation ChatGPT GPT-6.
 * Accepts independent Google-map screenshot geometries at DIFFERENT zooms.
 * A georeferenced screenshot is not necessarily a surveyed coastline.
 * Input: .directory with required keys defined in README_CARTOGRAPHY_INTAKE_v0.18.md.
 * The first 3 FIT controls determine an affine map, >=1 HOLDOUT is independent.
 * Geometry is always quarantined until provenance and holdout tests agree.
 */
::class HarbourCartographyIntake public
::constant E_M_PER_DEG 92300
::constant N_M_PER_DEG 111200
::constant REF_LAT -33.85
::constant REF_LON 151.2
::method point class
  use strict arg id,x,y,lat,lon,role,provenance
  d=.directory~new
  d['ID']=id; d['X']=x; d['Y']=y; d['LAT']=lat; d['LON']=lon
  d['ROLE']=role;d['PROVENANCE']=provenance
  return d
::method evaluate class
  use strict arg map
  numeric digits 20
  outcome=self~rejected('MALFORMED_MAP')
  if \(map~isA(.directory)) then return outcome
  do key over .array~of('MAP_ID','SOURCE_SHA256','WIDTH','HEIGHT','CRS','CONTROLS','WATER_POLYGONS','BOUNDARY_SOURCE')
    if \map~hasIndex(key) then return self~rejected('MISSING_'key)
  end
  if map['MAP_ID']=='' then return self~rejected('BAD_MAP_ID')
  if \self~hashOK(map['SOURCE_SHA256']) then return self~rejected('BAD_SOURCE_HASH')
  if map['CRS']\=='EPSG:4326' then return self~rejected('UNSUPPORTED_CRS')
  if \self~num(map['WIDTH']) | \self~num(map['HEIGHT']) then return self~rejected('BAD_IMAGE_SIZE')
  w=map['WIDTH'];h=map['HEIGHT']
  if w<16 | w>20000 | h<16 | h>20000 then return self~rejected('BAD_IMAGE_SIZE')
  if \map['CONTROLS']~isA(.array) then return self~rejected('BAD_CONTROLS')
  fit=.array~new; held=.array~new; known=.directory~new
  do c over map['CONTROLS']
    if \c~isA(.directory) then return self~rejected('BAD_CONTROL')
    do key over .array~of('ID','X','Y','LAT','LON','ROLE','PROVENANCE')
      if \c~hasIndex(key) then return self~rejected('BAD_CONTROL_FIELD')
    end
    id=c['ID']
    if id=='' | known~hasIndex(id) then return self~rejected('DUPLICATE_OR_EMPTY_CONTROL_ID')
    known[id]=1
    do key over .array~of('X','Y','LAT','LON')
      if \self~num(c[key]) then return self~rejected('NONNUMERIC_CONTROL')
    end
    if c['X']<0 | c['X']>=w | c['Y']<0 | c['Y']>=h then return self~rejected('CONTROL_OUTSIDE_IMAGE')
    if c['LAT']< -90 | c['LAT']>90 | c['LON']< -180 | c['LON']>180 then return self~rejected('CONTROL_OUTSIDE_EARTH')
    select
      when c['ROLE']=='FIT' then fit~append(c)
      when c['ROLE']=='HOLDOUT' then held~append(c)
      otherwise return self~rejected('BAD_CONTROL_ROLE')
    end
  end
  if fit~items\=3 then return self~rejected('NEED_EXACTLY_THREE_FIT_CONTROLS')
  if held~items<1 then return self~rejected('NEED_INDEPENDENT_HOLDOUT')
  polygons=map['WATER_POLYGONS']
  if \polygons~isA(.array) | polygons~items=0 then return self~rejected('NO_WATER_POLYGON')
  do polygon over polygons
    if \polygon~isA(.array) | polygon~items<4 then return self~rejected('BAD_POLYGON')
    do vertex over polygon
      if \vertex~isA(.array) | vertex~items\=2 then return self~rejected('BAD_VERTEX')
      if \self~num(vertex[1]) | \self~num(vertex[2]) then return self~rejected('NONNUMERIC_VERTEX')
      if vertex[1]<0 | vertex[1]>=w | vertex[2]<0 | vertex[2]>=h then return self~rejected('VERTEX_OUTSIDE_IMAGE')
    end
    first=polygon[1];last=polygon[polygon~items]
    if first[1]\=last[1] | first[2]\=last[2] then return self~rejected('OPEN_WATER_POLYGON')
    area=0
    do i=1 to polygon~items-1
      a=polygon[i]; b=polygon[i+1]
      area=area + a[1]*b[2]-b[1]*a[2]
    end
    if self~selfIntersects(polygon) then return self~rejected('SELF_INTERSECTING_WATER_POLYGON')
    if abs(area)<1 then return self~rejected('DEGENERATE_WATER_POLYGON')
  end
  x1=fit[1]['X'];y1=fit[1]['Y']
  x2=fit[2]['X'];y2=fit[2]['Y']
  x3=fit[3]['X'];y3=fit[3]['Y']
  det=(x2-x1)*(y3-y1)-(x3-x1)*(y2-y1)
  if abs(det)<1 then return self~rejected('COLLINEAR_FIT_CONTROLS')
  world=.array~new
  do c over fit
    world~append(.array~of((c['LON']-self~REF_LON)*self~E_M_PER_DEG,(c['LAT']-self~REF_LAT)*self~N_M_PER_DEG))
  end
  east=self~affineCoefficients(x1,y1,x2,y2,x3,y3,world[1][1],world[2][1],world[3][1],det)
  north=self~affineCoefficients(x1,y1,x2,y2,x3,y3,world[1][2],world[2][2],world[3][2],det)
  maxerr=0;errsum=0
  do c over held
    pred=self~projectXY(east,north,c['X'],c['Y'])
    dE=pred[1] - (c['LON']-self~REF_LON)*self~E_M_PER_DEG
    dN=pred[2] - (c['LAT']-self~REF_LAT)*self~N_M_PER_DEG
    error=self~squareRoot(dE*dE+dN*dN)
    errsum=errsum+error*error
    if error>maxerr then maxerr=error
  end
  outcome=.directory~new
  outcome['MAP_ID']=map['MAP_ID'];outcome['STATUS']='UNQUALIFIED'
  outcome['EAST_AFFINE']=east;outcome['NORTH_AFFINE']=north
  outcome['HOLDOUT_COUNT']=held~items;outcome['HOLDOUT_MAX_M']=maxerr
  outcome['HOLDOUT_RMS_M']=self~squareRoot(errsum/held~items)
  outcome['WATER_POLYGONS']=polygons;outcome['SOURCE_SHA256']=map['SOURCE_SHA256']
  outcome['CONTROL_IDS']=known;outcome['CONTROLS']=map['CONTROLS']
  outcome['BOUNDARY_SOURCE']=map['BOUNDARY_SOURCE']
  outcome['METRIC_WATER_MASK_ALLOWED']=.false
  if maxerr>3 then do
    outcome['STATUS']='HOLDOUT_REPROJECTION_FAILED'
    return outcome
  end
  do c over map['CONTROLS']
    if c['PROVENANCE']\=='SURVEYED_GEO_CONTROL' then do
      outcome['STATUS']='REGISTERED_MAP_ESTIMATE_ONLY'
      return outcome
    end
  end
  if map['BOUNDARY_SOURCE']\=='VERIFIED_SURVEYED_WATER_BOUNDARY' then do
    outcome['STATUS']='BOUNDARY_UNSURVEYED'
    return outcome
  end
  /* A caller can ASSERT surveyed provenance but cannot authenticate it.
   * No proof-of-source verifier has been integrated. Never auto-admit.
   */
  outcome['STATUS']='SURVEY_CLAIM_UNVERIFIED'
  return outcome
::method selfIntersects class private
  use strict arg polygon
  numeric digits 20
  count=polygon~items-1
  do i=1 to count
    a=polygon[i]; b=polygon[i+1]
    if a[1]=b[1] & a[2]=b[2] then return .true
    do j=i+1 to count
      if j=i+1 then iterate
      if i=1 & j=count then iterate
      c=polygon[j]; d=polygon[j+1]
      ab_c=(b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1])
      ab_d=(b[1]-a[1])*(d[2]-a[2])-(b[2]-a[2])*(d[1]-a[1])
      cd_a=(d[1]-c[1])*(a[2]-c[2])-(d[2]-c[2])*(a[1]-c[1])
      cd_b=(d[1]-c[1])*(b[2]-c[2])-(d[2]-c[2])*(b[1]-c[1])
      if ab_c*ab_d<0 & cd_a*cd_b<0 then return .true
    end
  end
  return .false
::method geographicOutlines class
  use strict arg fit
  if \fit~isA(.directory) then return .nil
  if \fit~hasIndex('EAST_AFFINE') | \fit~hasIndex('WATER_POLYGONS') then return .nil
  outlines=.array~new
  do polygon over fit['WATER_POLYGONS']
    points=.array~new
    do vertex over polygon
      points~append(self~imageToGeo(fit,vertex[1],vertex[2]))
    end
    outlines~append(points)
  end
  out=.directory~new
  out['POLYGONS']=outlines
  out['SOURCE_SHA256']=fit['SOURCE_SHA256']
  out['REGISTRATION_STATUS']=fit['STATUS']
  out['METRIC_WATER_MASK_ALLOWED']=fit['METRIC_WATER_MASK_ALLOWED']
  return out
::method affineCoefficients class private
  use strict arg x1,y1,x2,y2,x3,y3,v1,v2,v3,det
  numeric digits 20
  dv2=v2-v1; dv3=v3-v1
  b=(dv2*(y3-y1)-dv3*(y2-y1))/det
  c=((x2-x1)*dv3-(x3-x1)*dv2)/det
  a=v1-b*x1-c*y1
  return .array~of(a,b,c)
::method projectXY class
  use strict arg east,north,x,y
  numeric digits 20
  return .array~of(east[1]+east[2]*x+east[3]*y, north[1]+north[2]*x+north[3]*y)
::method imageToGeo class
  use strict arg r,x,y
  numeric digits 20
  if \r~isA(.directory) then return .nil
  if \r~hasIndex('EAST_AFFINE') then return .nil
  if \self~num(x) | \self~num(y) then return .nil
  m=self~projectXY(r['EAST_AFFINE'],r['NORTH_AFFINE'],x,y)
  return .array~of(self~REF_LAT+m[2]/self~N_M_PER_DEG,self~REF_LON+m[1]/self~E_M_PER_DEG)
::method reconcile class
  use strict arg a,b
  numeric digits 20
  if \a~isA(.directory) | \b~isA(.directory) then return self~rejected('BAD_PAIR')
  if \a~hasIndex('STATUS') | \b~hasIndex('STATUS') then return self~rejected('BAD_PAIR')
  if a['STATUS']=='HOLDOUT_REPROJECTION_FAILED' | b['STATUS']=='HOLDOUT_REPROJECTION_FAILED' then return self~rejected('PAIR_HOLDOUT_FAILED')
  if \a~hasIndex('EAST_AFFINE') | \b~hasIndex('EAST_AFFINE') then return self~rejected('PAIR_UNREGISTERED')
  if a['SOURCE_SHA256']==b['SOURCE_SHA256'] then return self~rejected('SAME_IMAGE_NOT_INDEPENDENT')
  shared=0;maxdiff=0
  do ca over a['CONTROLS']
    do cb over b['CONTROLS']
      if ca['ID']==cb['ID'] then do
        shared=shared+1
        x=(ca['LON']-cb['LON'])*self~E_M_PER_DEG
        y=(ca['LAT']-cb['LAT'])*self~N_M_PER_DEG
        d=self~squareRoot(x*x+y*y)
        if d>maxdiff then maxdiff=d
      end
    end
  end
  if shared<3 then return self~rejected('INSUFFICIENT_COMMON_LANDMARKS')
  if maxdiff>3 then return self~rejected('INCONSISTENT_COMMON_LANDMARKS')
  outcome=.directory~new
  outcome['COMMON_CONTROL_COUNT']=shared
  outcome['COMMON_CONTROL_MAX_M']=maxdiff
  outcome['STATUS']='TWO_MAPS_RECONCILED_ESTIMATE_ONLY'
  outcome['METRIC_WATER_MASK_ALLOWED']=.false
  if a['METRIC_WATER_MASK_ALLOWED'] & b['METRIC_WATER_MASK_ALLOWED'] then do
    outcome['STATUS']='TWO_SURVEYED_BOUNDARIES_REGISTERED'
    outcome['METRIC_WATER_MASK_ALLOWED']=.true
  end
  return outcome
::method waterPixel class
  use strict arg outcome,x,y
  if \outcome~isA(.directory) then return 'UNKNOWN_NOT_QUALIFIED'
  if \outcome~hasIndex('METRIC_WATER_MASK_ALLOWED') then return 'UNKNOWN_NOT_QUALIFIED'
  if \outcome['METRIC_WATER_MASK_ALLOWED'] then return 'UNKNOWN_NOT_QUALIFIED'
  if \self~num(x) | \self~num(y) then return 'UNKNOWN_NOT_QUALIFIED'
  do polygon over outcome['WATER_POLYGONS']
    inside=.false
    do i=1 to polygon~items-1
      a=polygon[i]; b=polygon[i+1]
      if (a[2]>y) \= (b[2]>y) then do
        cross=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
        if x<cross then inside=\inside
      end
    end
    if inside then return 'WATER_PROVEN_INSIDE_SURVEYED_BOUNDARY'
  end
  return 'UNKNOWN_NOT_WATER_PROOF'
::method rejected class private
  use strict arg status
  d=.directory~new;d['STATUS']=status;d['METRIC_WATER_MASK_ALLOWED']=.false
  return d
::method hashOK class private
  use strict arg s
  if \self~string(s) then return .false
  if s~length\=64 then return .false
  allowed='0123456789abcdef'
  do i=1 to 64
    if allowed~pos(s~substr(i,1))=0 then return .false
  end
  return .true
::method num class private
  use strict arg value
  if \self~string(value) then return .false
  return value~datatype('N')
::method string class private
  use strict arg value
  return value~isA(.string)
::method squareRoot class private
  use strict arg value
  if value<=0 then return 0
  guess=value/2
  if guess<1 then guess=1
  do i=1 to 30
    guess=(guess+value/guess)/2
  end
  return guess