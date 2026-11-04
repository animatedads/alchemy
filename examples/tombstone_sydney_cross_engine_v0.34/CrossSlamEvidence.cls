/* Sydney Harbour: additive multi-engine evidence/registration gate v0.34
 * Architecture: user. Implementation: ChatGPT GPT-6, 2026-11-02.
 * Screenshots, raster masks, map mosaics and 360-degree projections retain
 * their own native image coordinates. Nothing here certifies a camera pose.
 * No Power SLAM renderer or canonical SLAM Store modification.
 */
::class CrossSlamEvidence public
::attribute sources get

::method init
  expose sources
  sources=.directory~new

::method register
  expose sources
  use strict arg id,kind,sha,width,height,coord,state
  if id=='' | sources~hasIndex(id) then raise syntax 88.900 array('duplicate or empty source identity')
  if kind\=='RASTER_SEGMENTATION' & kind\=='SATELLITE_TILE_MOSAIC' & kind\=='MODEL_360_PANORAMA' & kind\=='V5V_VIDEO' then raise syntax 88.900 array('unknown source type')
  if length(sha)<>64 | verify(sha,'0123456789abcdef')<>0 then raise syntax 88.900 array('bad source SHA256')
  if \datatype(width,'W') | \datatype(height,'W') then raise syntax 88.900 array('noninteger dimensions')
  if width<1 | height<1 then raise syntax 88.900 array('invalid dimensions')
  select
    when kind=='RASTER_SEGMENTATION' then do
      if coord\=='SCREEN_RASTER_UNREGISTERED' | state\=='CLASS_SEMANTICS_UNVERIFIED' then raise syntax 88.900 array('bad segmentation provenance')
    end
    when kind=='SATELLITE_TILE_MOSAIC' then do
      if coord\=='COMPOSITE_SCREEN_UNREGISTERED' | state\=='TILE_GEOTRANSFORMS_MISSING' then raise syntax 88.900 array('unregistered mosaic misrepresented')
    end
    when kind=='MODEL_360_PANORAMA' then do
      if coord\=='MODEL_BEARING_CANVAS' | state\=='CAMERA_POSE_HYPOTHESIS' then raise syntax 88.900 array('model panorama is not surveyed')
    end
    when kind=='V5V_VIDEO' then do
      if coord\=='V5V_IMAGE_LATTICE_80x45' | state\=='OBSERVED_UNTESTED' then raise syntax 88.900 array('invalid V5V authority')
      if width<>80 | height<>45 then raise syntax 88.900 array('V5V lattice mismatch')
    end
  end
  d=.directory~new
  d['KIND']=kind;d['SHA256']=sha;d['WIDTH']=width;d['HEIGHT']=height
  d['COORD']=coord;d['STATE']=state
  sources[id]=d
  return .true

::method source
  expose sources
  use strict arg id
  if \sources~hasIndex(id) then raise syntax 88.900 array('unknown source')
  return sources[id]

::method imagePoint
  use strict arg id,x,y
  s=self~source(id)
  if \datatype(x,'N') | \datatype(y,'N') then raise syntax 88.900 array('invalid point')
  if x<0 | y<0 | x>=s['WIDTH'] | y>=s['HEIGHT'] then raise syntax 88.900 array('point outside source raster')
  p=.directory~new
  p['SOURCE']=id;p['X']=x;p['Y']=y
  p['COORD']=s['COORD'];p['WORLD']='BLOCKED_NO_REGISTRATION'
  return p

::method imageBox
  use strict arg id,x0,y0,x1,y1
  s=self~source(id)
  a=self~imagePoint(id,x0,y0)
  if \datatype(x1,'N') | \datatype(y1,'N') then raise syntax 88.900 array('nonnumeric box endpoint')
  if x1<=x0 | y1<=y0 | x1>s['WIDTH'] | y1>s['HEIGHT'] then raise syntax 88.900 array('invalid image box')
  a['W']=x1-x0;a['H']=y1-y0
  return a

::method screenOverlap
  use strict arg sourceId,a,b
  s=self~source(sourceId)
  if a['SOURCE']\==sourceId | b['SOURCE']\==sourceId then raise syntax 88.900 array('cross-source screen overlap prohibited')
  x=max(0,min(a['X']+a['W'],b['X']+b['W'])-max(a['X'],b['X']))
  y=max(0,min(a['Y']+a['H'],b['Y']+b['H'])-max(a['Y'],b['Y']))
  return x*y

::method circularSeparation class
  use strict arg a,b
  if \datatype(a,'N') | \datatype(b,'N') then raise syntax 88.900 array('nonnumeric bearings')
  if a<0 | a>360 | b<0 | b>360 then raise syntax 88.900 array('bearing out of range')
  d=abs(a-b)
  return min(d,360-d)

::method bearingSectorContains class
  use strict arg startAngle,endAngle,angle
  if \datatype(startAngle,'N') | \datatype(endAngle,'N') | \datatype(angle,'N') then raise syntax 88.900 array('nonnumeric sector')
  if startAngle<0 | startAngle>360 | endAngle<0 | endAngle>360 | angle<0 | angle>360 then raise syntax 88.900 array('invalid sector degrees')
  if startAngle<=endAngle then return angle>=startAngle & angle<=endAngle
  return angle>=startAngle | angle<=endAngle

::method panoramaObservation
  use strict arg id,angle
  s=self~source(id)
  if s['KIND']\=='MODEL_360_PANORAMA' then raise syntax 88.900 array('not a model panorama')
  if \datatype(angle,'N') then raise syntax 88.900 array('invalid model bearing')
  if angle<0 | angle>360 then raise syntax 88.900 array('bearing outside panorama')
  p=.directory~new
  p['SOURCE']=id;p['BEARING']=angle;p['STATE']='ILLUSTRATIVE_MODEL_HYPOTHESIS'
  p['CAMERA_RAY']='BLOCKED_UNSURVEYED_POSE'
  return p

::method sourceToWorld
  use strict arg id,otherId
  a=self~source(id);b=self~source(otherId)
  /* Even model screenshots do not contain an authoritative image-to-world
   * calibration or signed pose certificate. Fail closed without one. */
  return 'BLOCKED_NO_QUALIFIED_TRANSFORM'

::method linkCandidate
  use strict arg fromId,toId,reviewStatus
  a=self~source(fromId);b=self~source(toId)
  if a['KIND']\=='V5V_VIDEO' then raise syntax 88.900 array('source must be actual V5V observation')
  if reviewStatus\=='OBSERVED_UNTESTED' then raise syntax 88.900 array('identity or evidential authority promoted')
  o=.directory~new
  o['SOURCE']=fromId;o['TARGET']=toId
  o['STATE']='CROSS_ENGINE_LINK_UNREGISTERED'
  o['WORLD']='BLOCKED_NO_QUALIFIED_TRANSFORM'
  o['IDENTITY']='UNVERIFIED'
  return o