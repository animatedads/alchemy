/* Power SLAM v0.18 corrected bridge continuity renderer: PTZ site candidate.
 * Geometry: current HarbourQuayInfrastructurePanorama + RoofPins~apply.
 * No image generation. Camera origin copied from published v0.14 fit;
 * PTZ camera is only CLAIMED to share the same building, not optical centre.
 */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg outfile
if outfile=='' then outfile='ptz_north_shore_model_360.svg'
p=.PTZNorthShoreScene~new
state=.HarbourBridgeRoofPins~apply(p~scene)
vertical=.HarbourBridgeVertical~apply(p~scene)
if state['STATUS'] \=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED' then do
  say 'FAIL roof pin layout' state['STATUS']
  exit 2
end
p~sites['PTZ_MODEL']=.array~of('North shore PTZ: north shore fixed-camera position hypothesis', -33.8487411, 151.214266)
cam=p~render('PTZ_MODEL',outfile,2880,720)
say 'OK ooRexx 5.3.0 r13196'
say 'GEOMETRY' state['STATUS'] vertical['STATUS']
say 'ROAD_DECK_TOP' vertical['DECK_SURFACE_M'] 'PYLON_TOP' vertical['PYLON_TOP_M']
say 'CAMERA -33.8487411 151.214266 79m ASL'
say 'BOXES' p~scene~boxes~items
say 'SVG' outfile
say 'RANGE true azimuth 0..360 deg; vertical elevation +55..-35 deg'
say 'PTZ actual optical centre/height UNKNOWN; this is v0.14 provisional fixed-camera pose transferred to same-building hypothesis'
exit 0
::class PTZNorthShoreScene public subclass HarbourQuayInfrastructurePanorama
::method siteCamera
  use strict arg key
  cam=self~siteCamera:super(key)
  if key~upper=='PTZ_MODEL' then cam[3]=79.0
  return cam
::requires 'SlamHarbourQuayInfrastructure.cls'
::requires 'SlamHarbourBridgeVertical.cls'