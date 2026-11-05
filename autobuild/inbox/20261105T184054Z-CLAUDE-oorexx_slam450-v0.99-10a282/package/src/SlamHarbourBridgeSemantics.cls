/* Power SLAM v0.11: structural feature semantics and camera-fit admission.
 * Architecture: Tom Dyer. Increment: ChatGPT GPT-6, 2026-11-01.
 * Source: Transport for NSW, Sydney Harbour Bridge Conservation Management
 * Plan (2007), 3.1.3 (arch, abutment and decorative pylon distinction).
 * Source: TfNSW Cycleway Access Heritage Framework (2021), arch truss 30m
 * centre-to-centre; deck 49m from TfNSW bridge geometry documentation.
 * No inferred lateral offsets are asserted as surveyed pylon positions.
 */
::requires 'SlamHarbourBridgeAudit.cls'
::class HarbourBridgeSemantics public
::method facts class
  d=.directory~new
  d['TRUSS_CENTRE_SPACING_M']=30
  d['DECK_WIDTH_M']=49
  d['ABUTMENT_BASE_WIDTH_M']=58
  d['ABUTMENT_BASE_LENGTH_M']=49
  d['PYLON_TOP_ASL_M']=89
  d['PYLON_LOOKOUT_ASL_M']=87
  d['MAIN_ARCH_SPAN_M']=503
  d['TRUSS_COUNT']=2
  d['PYLON_COUNT']=4
  return d
::method referenceKind class
  use strict arg id
  select
    when id=='USER_SE' | id=='USER_SW' | id=='USER_NE' | id=='USER_NW' then return 'UNVERIFIED_UNTYPED_POINT'
    when id=='OSM_SOUTH_BUILDING' | id=='OSM_NORTH_BUILDING' then return 'MAPPED_ABUTMENT_BUILDING_CENTRE'
    when id=='PHOTO_LOOKOUT' then return 'CAMERA_GPS_NOT_SURVEYED_PYLON_CENTRE'
    when id=='OSM_LOOKOUT' then return 'MAPPED_TOURISM_POI_NOT_PYLON_CENTRE'
    when id=='TFNSW_SOUTH_ACCESS' then return 'ACCESS_POINT_NOT_PYLON_CENTRE'
    when id=='BATTERY' then return 'HISTORIC_BATTERY_LOCATION'
    otherwise return 'UNKNOWN'
  end
::method requiresSurveyForPose class
  use strict arg id
  k=self~referenceKind(id)
  /* Even official access coordinates do not certify a pylon centroid. */
  return k\=='SURVEYED_PYLON_CENTRE'
::method structureKind class
  use strict arg name
  select
    when name=='PYLON' then return 'DECORATIVE_MASONRY_TOWER_ABOVE_DECK'
    when name=='ABUTMENT' then return 'STRUCTURAL_SUPPORT_AND_ARCH_BEARING_REACTION'
    when name=='ARCH' then return 'STRUCTURAL_STEEL_TRUSSES'
    when name=='DECK' then return 'ROAD_RAIL_FOOTPATH_DECK'
    when name=='LOOKOUT' then return 'TOURIST_FACILITY_INSIDE_SE_PYLON'
    otherwise return 'UNKNOWN'
  end
/* The only longitudinal axis available is through two OSM *building* centre proxies.
   It is a visual baseline, not a precise bearing or alignment survey. */
::method proxyAxis class
  use strict arg scene
  e=.HarbourBridgeAudit~externalCoordinates
  a=scene~local(e['OSM_SOUTH_BUILDING'][1],e['OSM_SOUTH_BUILDING'][2])
  b=scene~local(e['OSM_NORTH_BUILDING'][1],e['OSM_NORTH_BUILDING'][2])
  dx=b[1]-a[1];dy=b[2]-a[2]
  n=HSqrt(dx*dx+dy*dy)
  ux=dx/n;uy=dy/n
  return .array~of(a,b,ux,uy,-uy,ux,n)
::method frame class
  use strict arg scene
  f=self~facts
  a=self~proxyAxis(scene)
  d=.directory~new
  d['AXIS_KIND']='OSM_BUILDING_CENTRE_PROXY_NOT_SURVEY'
  d['AXIS_LENGTH_M']=a[7]
  d['AXIS_UNIT_E']=a[3]
  d['AXIS_UNIT_N']=a[4]
  d['CROSS_UNIT_E']=a[5]
  d['CROSS_UNIT_N']=a[6]
  d['DECK_HALF_WIDTH_M']=f['DECK_WIDTH_M']/2
  d['TRUSS_HALF_SPACING_M']=f['TRUSS_CENTRE_SPACING_M']/2
  d['PYLON_XY_STATUS']='UNRESOLVED_FOUR_INDIVIDUAL_CENTRES'
  d['FIT_ADMISSION']='BLOCKED_UNTYPED_PYLON_CENTRES'
  return d
