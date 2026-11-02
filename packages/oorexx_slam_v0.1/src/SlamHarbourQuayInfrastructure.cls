/* Power SLAM v0.6: measured station-end baselines and indicative Cahill height.
 * Architecture Tom Dyer. Implementation ChatGPT GPT-6 2026-11-01.
 * All horizontal station endpoints USER SUPPLIED (not independent survey).
 * Station/Cahill widths, horizontal offsets, roof levels are HYPOTHESES.
 * Cafe Sydney camera is 25m ASL USER ESTIMATE, not surveyed vertical datum.
 * Every height is in local metres assumed equivalent to ASL/AHD, pending datum audit.
 */
::requires 'SlamHarbourNorthShore.cls'

::class HarbourQuayInfrastructurePanorama public subclass HarbourNorthShorePanorama
::attribute structures
::method init
  expose structures
  self~init:super
  scene=self~scene
  structures=.directory~new
  /* Alias the actual rooftop viewpoint; legacy CIRCULAR remains recognized.
     Its XY location is existing coarse building centre, not a terrace survey. */
  self~sites['CAFE_SYDNEY']=.array~of('Cafe Sydney / Customs House rooftop', -33.862128338141,151.21083913743)
  /* Retain station eastings but register both ends under the map-aligned
   * Cahill line (-481,-1022) to (273,-1106); user-approved relocation.
   * These are approximate map coordinates, not surveyed geography.
   */
  originalW=scene~local(-33.86146,151.20980)
  originalE=scene~local(-33.86127,151.21160)
  westX=originalW[1];eastX=originalE[1]
  westY=-1022+(-1106+1022)*(westX+481)/754
  eastY=-1022+(-1106+1022)*(eastX+481)/754
  a=.array~of(westX,westY)
  b=.array~of(eastX,eastY)
  dx=b[1]-a[1];dy=b[2]-a[2]
  length=HSqrt(dx*dx+dy*dy)
  if length<150 | length>190 then raise syntax 88.900 array('station baseline outside 150-190m qualification envelope')
  ux=dx/length;uy=dy/length
  vx=0-uy;vy=ux
  cx=(a[1]+b[1])/2;cy=(a[2]+b[2])/2
  /* Coarse station roof/viaduct: from z=4.0 up to 12.5m. Track ref
     8.35 RL cited near east portal; *not* a surveyed entire-platform level. */
  scene~boxes~append(scene~cuboid('CQ_STATION',cx,cy,4.0,length,18,8.5,ux,uy,vx,vy))
  /* Segment of Cahill Expressway directly above station only; true bridge
     extends beyond these station endpoints and must not be implied to end here. */
  scene~boxes~append(scene~cuboid('CAHILL',cx,cy,13.5,length,17,3.0,ux,uy,vx,vy))
  /* Continue east to the last map-supported point only. */
  extX=273;extY=-1106
  extDx=extX-b[1];extDy=extY-b[2]
  extLength=HSqrt(extDx*extDx+extDy*extDy)
  extUx=extDx/extLength;extUy=extDy/extLength
  scene~boxes~append(scene~cuboid('CAHILL_EAST_EXTENSION',,
     (b[1]+extX)/2,(b[2]+extY)/2,13.5,extLength,17,3.0,,
     extUx,extUy,0-extUy,extUx))
  scene~features['CAHILL_MAP_EAST_END']=.array~of(extX,extY,16.5)
  scene~features['STATION_W']=.array~of(a[1],a[2],12.5)
  scene~features['STATION_E']=.array~of(b[1],b[2],12.5)
  scene~features['STATION_C']=.array~of(cx,cy,12.5)
  scene~features['CAHILL_C']=.array~of(cx,cy,16.5)
  scene~features['CAHILL_W']=.array~of(a[1],a[2],16.5)
  scene~features['CAHILL_E']=.array~of(b[1],b[2],16.5)
  m=.directory~new
  m['ID']='CQ_STATION';m['WEST_LAT']=-33.86146;m['WEST_LON']=151.20980
  m['EAST_LAT']=-33.86127;m['EAST_LON']=151.21160
  m['PREVIOUS_WEST_LOCAL']=originalW
  m['PREVIOUS_EAST_LOCAL']=originalE
  m['ALIGNMENT']='MOVED_UNDER_SNAPPED_CAHILL_ROUTE'
  m['ALIGNMENT_SOURCE']='expressway_route.words (Claude Opus 5.5); Tom Dyer approval'
  m['LENGTH_M']=length;m['WIDTH_M']=18
  m['BOTTOM_M_ASL']=4.0;m['TOP_M_ASL']=12.5;m['TRACK_REFERENCE_RL']=8.35
  m['HORIZONTAL']='USER_SUPPLIED_ENDPOINTS'
  m['WIDTH_HEIGHT']='HYPOTHESIS'
  m['TRACK_RL_SOURCE']='2025 planning document: eastern viaduct approach, not station-wide measurement'
  m['SURVEYED_FOOTPRINT']=.false;m['SURVEYED_ROOF']=.false
  structures['CQ_STATION']=m
  road=.directory~new
  road['ID']='CAHILL';road['LENGTH_M']=length;road['WIDTH_M']=17
  road['BOTTOM_M_ASL']=13.5;road['TOP_M_ASL']=16.5
  road['GEOMETRIC_RELATION']='DIRECTLY_ABOVE_CQ_STATION'
  road['SCOPE']='STATION_SEGMENT_PLUS_MAP_EAST_EXTENSION'
  road['EAST_EXTENSION_M']=extLength
  road['MAP_EAST_END']=scene~features['CAHILL_MAP_EAST_END']
  road['HORIZONTAL']='SNAPPED_MAP_ROUTE_APPROXIMATE'
  road['WIDTH_HEIGHT']='USER_ESTIMATE_PLUS_HYPOTHESIS'
  road['SURVEYED_FOOTPRINT']=.false;road['SURVEYED_ROOF']=.false
  structures['CAHILL']=road
  cam=.directory~new
  cam['ID']='CAFE_SYDNEY';cam['XY']='PREEXISTING_APPROXIMATE_BUILDING_CENTRE'
  cam['ALTITUDE_M_ASL']=25
  cam['ALTITUDE_STATUS']='USER_ESTIMATE_NOT_SURVEYED'
  cam['TERRACE_LOCATION_SURVEYED']=.false
  cam['LAND_MASK_QUALIFIED']=.false
  cam['SIGHTLINE_QUALIFIED']=.false
  structures['CAFE_SYDNEY']=cam
::method siteCamera
  use strict arg key
  c=self~siteCamera:super(key)
  if key~upper=='CIRCULAR' | key~upper=='CAFE_SYDNEY' then c[3]=25
  return c
::method getStructure
  expose structures
  use strict arg id
  if \structures~hasIndex(id) then raise syntax 88.900 array('unknown quay structure')
  return structures[id]
::method allStructureIds
  expose structures
  return structures~allIndexes~sort
