/* Power SLAM: independent bridge-coordinate qualification boundary.
 * Architecture Tom Dyer. Implemented by ChatGPT GPT-6, 2026-11-01.
 * Never convert arbitrary points of interest into masonry pylon centroids.
 * Evidence is versioned and typed. A landmark label is not geodetic proof.
 * Planar working distances use HarbourScene's LOCAL tangent plane; NOT survey grade.
 */
::requires 'SlamHarbourPose.cls'
::class HarbourBridgeAudit public
::method userCoordinates class
  d=.directory~new
  d['SE']=.array~of(-33.85387,151.21102)
  d['SW']=.array~of(-33.85408,151.21051)
  d['NE']=.array~of(-33.84992,151.21272)
  d['NW']=.array~of(-33.85012,151.21221)
  return d
::method externalCoordinates class
  d=.directory~new
  /* Independent first-party/OSM control points, NOT four surveyed pylon centroids.
     Photo: https://commons.wikimedia.org/wiki/File:Sydney_Harbour_Bridge_from_Pylon_Lookout,_2013-12-03.jpg
     TfNSW: https://www.australiantenders.com.au/tenders/611065/supply-and-install-of-air-compressor-at-sydney-harbour-bridge
     OSM building locations: south way 382401361, north way 156584774.
  */
  d['PHOTO_LOOKOUT']=.array~of(-33.854600,151.209500)
  d['OSM_LOOKOUT']=.array~of(-33.854650,151.209490)
  d['TFNSW_SOUTH_ACCESS']=.array~of(-33.854505,151.208843)
  d['OSM_SOUTH_BUILDING']=.array~of(-33.854540,151.209260)
  d['OSM_NORTH_BUILDING']=.array~of(-33.850030,151.212090)
  d['BATTERY']=.array~of(-33.854945,151.209404)
  return d
::method delta class
  use strict arg scene,a,b
  u=scene~local(a[1],a[2]);v=scene~local(b[1],b[2])
  return .array~of(v[1]-u[1],v[2]-u[2])
::method distance class
  use strict arg scene,a,b
  q=self~delta(scene,a,b)
  return HSqrt(q[1]*q[1]+q[2]*q[2])
::method qualify class
  use strict arg scene
  user=self~userCoordinates; geo=self~externalCoordinates
  out=.directory~new
  out['SE_PHOTO_M']=self~distance(scene,user['SE'],geo['PHOTO_LOOKOUT'])
  out['SE_OSM_LOOKOUT_M']=self~distance(scene,user['SE'],geo['OSM_LOOKOUT'])
  out['SE_TFNSW_M']=self~distance(scene,user['SE'],geo['TFNSW_SOUTH_ACCESS'])
  out['SE_OSM_BUILDING_M']=self~distance(scene,user['SE'],geo['OSM_SOUTH_BUILDING'])
  out['LOOKOUT_PHOTO_AGREEMENT_M']=self~distance(scene,geo['PHOTO_LOOKOUT'],geo['OSM_LOOKOUT'])
  out['OSM_BUILDING_AXIS_M']=self~distance(scene,geo['OSM_SOUTH_BUILDING'],geo['OSM_NORTH_BUILDING'])
  south=self~delta(scene,user['SW'],user['SE'])
  north=self~delta(scene,user['NW'],user['NE'])
  parallel1=self~delta(scene,user['SE'],user['NE'])
  parallel2=self~delta(scene,user['SW'],user['NW'])
  out['SOUTH_PAIR_M']=HSqrt(south[1]*south[1]+south[2]*south[2])
  out['NORTH_PAIR_M']=HSqrt(north[1]*north[1]+north[2]*north[2])
  out['LONG_EDGE_E_M']=HSqrt(parallel1[1]*parallel1[1]+parallel1[2]*parallel1[2])
  out['LONG_EDGE_W_M']=HSqrt(parallel2[1]*parallel2[1]+parallel2[2]*parallel2[2])
  out['PAIR_AXIS_DOT']=abs((south[1]*parallel1[1]+south[2]*parallel1[2])/(out['SOUTH_PAIR_M']*out['LONG_EDGE_E_M']))
  out['TRANSVERSE_COMPONENT_M']=abs((south[1]*parallel1[2]-south[2]*parallel1[1])/out['LONG_EDGE_E_M'])
  out['ALONG_AXIS_COMPONENT_M']=abs((south[1]*parallel1[1]+south[2]*parallel1[2])/out['LONG_EDGE_E_M'])
  out['STATUS']='UNQUALIFIED'
  out['REASONS']=.array~new
  /* 60m is only a generous detection threshold, NOT a claimed source precision. */
  if out['SE_PHOTO_M']>60 then out['REASONS']~append('SE_POINT_NOT_AT_PHOTOGRAPHED_PYLON')
  if out['SE_OSM_BUILDING_M']>60 then out['REASONS']~append('SE_POINT_OUTSIDE_SOUTH_BUILDING_CONTROL_REGION')
  if out['PAIR_AXIS_DOT']>0.2 then out['REASONS']~append('USER_PAIR_NOT_TRANSVERSE_TO_BRIDGE_AXIS')
  if out['REASONS']~items>0 then out['STATUS']='REJECTED_BRIDGE_GEOMETRY'
  return out
::method provenance class
  return 'USER_SE_SW_NE_NW_UNVERIFIED; CAMERA_GPS_PHOTO_INDEPENDENT; TFNSW_SOUTH_GPS_ACCESS_NOT_CENTROID; OSM_WAY_CENTRES_NOT_PYLON_CORNERS; PHOTO_2013_LOOKOUT'