/* PTZ north shore model + Blues Point Tower, REAL ooRexx geometric SVG.
 * No image generation. Source site is provisional same-building hypothesis.
 * Building reference point and 83m structural height documented; 0m base ASL
 * is a named, arbitrary visualization assumption, NOT surveyed land height.
 */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg outfile
if outfile=='' then outfile='ptz_blues_point_tower_360.svg'
p=.PTZBluesTowerScene~new
roof=.HarbourBridgeRoofPins~apply(p~scene)
bridge=.HarbourBridgeVertical~apply(p~scene)
tower=.HarbourBluesPointTower~apply(p~scene,0)
if tower['STATUS']\=='GEOGRAPHIC_LANDMARK_VISIBLE_HEIGHT_BASE_UNSURVEYED' then do
 say 'FAIL invalid Blues Point Tower admission state';exit 2
end
p~sites['PTZ_MODEL']=.array~of('PTZ north shore hypothesis + Blues Point Tower (base 0m assumed)',-33.8487411,151.214266)
cam=p~render('PTZ_MODEL',outfile,2880,720)
xy=p~pointAngles(p~scene~features['BPT_ROOF'],cam)
say 'RENDERED_NATIVE_OOREXX' outfile
say 'FEATURE BLUES_POINT_TOWER LAT -33.849000568058 LON 151.20353302224 HEIGHT 83m ABOVE_GROUND'
say 'BPT_AZIMUTH_DEG' xy[1] 'ELEVATION_DEG' xy[2] 'GROUND_DISTANCE_M' xy[3]
say 'BOX_COUNT' p~scene~boxes~items
say 'CAMERA PROVISIONAL_LAT -33.8487411 LON 151.214266 HEIGHT 79m'
say 'NOT_QUALIFIED_GROUND_ELEVATION assumed 0m ASL; NOT_QUALIFIED_FOOTPRINT 24 x 20m'
exit 0
::class PTZBluesTowerScene public subclass HarbourQuayInfrastructurePanorama
::method siteCamera
  use strict arg key
  cam=self~siteCamera:super(key)
  if key~upper=='PTZ_MODEL' then cam[3]=79
  return cam
::requires 'SlamHarbourQuayInfrastructure.cls'
::requires 'SlamHarbourBluesPointTower.cls'