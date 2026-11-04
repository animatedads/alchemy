/* Power SLAM Harbour v0.19. Architecture: Tom Dyer.
 * Geometry added by ChatGPT GPT-6, 2026-11-02.
 * Known building: Blues Point Tower, 14-28 Blues Point Road, McMahons Point.
 * Reference coordinate: Dictionary of Sydney, mapped building reference
 * (-33.849000568058,151.20353302224). 83m BUILDING HEIGHT above ground,
 * NOT an independently surveyed roof elevation above sea level.
 * Rectangle 24 x 20m and yaw=0 are UNSURVEYED DISPLAY PARAMETERS.
 * An explicit chosen ground ASL is REQUIRED for any 3D box render.
 */
::requires 'SlamHarbourBridgeVertical.cls'
::class HarbourBluesPointTower public

::method catalogue class
  d=.directory~new
  d['ID']='BLUES_POINT_TOWER'
  d['NAME']='Blues Point Tower'
  d['LAT']=-33.849000568058
  d['LON']=151.20353302224
  d['STRUCTURAL_HEIGHT_M']=83
  d['HEIGHT_BASIS']='ABOVE_GROUND_NOT_ASL'
  d['GEO_SOURCE']='https://dictionaryofsydney.org/building/blues_point_tower'
  d['FOOTPRINT_STATUS']='UNSURVEYED_ILLUSTRATIVE_RECTANGLE'
  d['FOOTPRINT_ALONG_M']=24
  d['FOOTPRINT_ACROSS_M']=20
  d['BASE_ASL_STATUS']='UNKNOWN_MUST_BE_EXPLICITLY_ASSUMED'
  d['PTZ_PIXEL_ASSOCIATION']='USER_VISUAL_ID_NOT_PIXEL_MEASURED'
  return d

::method apply class
  use strict arg scene,baseASL
  if \datatype(baseASL,'N') then raise syntax 88.900 array('Blues Point Tower needs explicit provisional base ASL')
  if baseASL<0 | baseASL>60 then raise syntax 88.900 array('invalid illustrative base ASL')
  if scene~features~hasIndex('BPT_ROOF') then raise syntax 88.900 array('duplicate Blues Point Tower feature')
  do b over scene~boxes
    if b[1]=='BLUES_POINT_TOWER' then raise syntax 88.900 array('duplicate Blues Point Tower solid')
  end
  m=self~catalogue
  local=scene~local(m['LAT'],m['LON'])
  scene~boxes~append(scene~cuboid('BLUES_POINT_TOWER',local[1],local[2],baseASL,m['FOOTPRINT_ALONG_M'],m['FOOTPRINT_ACROSS_M'],m['STRUCTURAL_HEIGHT_M'],1,0,0,1))
  scene~features['BPT_ROOF']=.array~of(local[1],local[2],baseASL+m['STRUCTURAL_HEIGHT_M'])
  scene~features['BPT_BASE']=.array~of(local[1],local[2],baseASL)
  r=.directory~new
  r['ID']=m['ID']
  r['STATUS']='GEOGRAPHIC_LANDMARK_VISIBLE_HEIGHT_BASE_UNSURVEYED'
  r['STRUCTURAL_HEIGHT_M']=m['STRUCTURAL_HEIGHT_M']
  r['BASE_ASL_ASSUMED_M']=baseASL
  r['ROOF_ASL_ASSUMED_M']=baseASL+m['STRUCTURAL_HEIGHT_M']
  r['FOOTPRINT_STATUS']=m['FOOTPRINT_STATUS']
  r['CAMERA_POSE_ADMISSION']='NOT_ADMITTED'
  return r
