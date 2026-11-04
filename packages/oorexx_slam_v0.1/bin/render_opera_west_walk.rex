/* Power SLAM v0.20: native ooRexx panorama from west Opera House walkway. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg outfile
if outfile=='' then outfile='opera_west_walk_360.svg'
p=.HarbourOperaWestWalk~new
r=.HarbourBridgeRoofPins~apply(p~scene)
if r['STATUS']\=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED' then raise syntax 88.900 array('roof pin frame fails')
b=.HarbourBridgeVertical~apply(p~scene)
t=.HarbourBluesPointTower~apply(p~scene,0)
o=p~orientOperaBox
q=p~qualifyWalk
cam=p~siteCamera('OPERA_WEST_WALK')
p~render('OPERA_WEST_WALK',outfile,2880,720)
say 'POWER_SLAM_OPERA_WEST_VIEW GENERATED_FROM_OOREXX'
say 'CAMERA' q['CAMERA_LAT'] q['CAMERA_LON'] q['CAMERA_ASL'] 'm_ASL_PROVISIONAL'
say 'OPERA' o 'DISTANCE_FROM_WEST_FACE_M' q['DISTANCE_WEST_OF_FACE_M']
say 'STATUS' q['STATUS'] 'FOOTPRINT_NOT_SURVEYED'
say 'BOXES' p~scene~boxes~items 'SVG' outfile
say 'BEARING Bridge_N' p~pointAngles(p~scene~features['N'],cam)[1]
say 'BEARING Bridge_S' p~pointAngles(p~scene~features['S'],cam)[1]
say 'BEARING Blues_Point_Tower' p~pointAngles(p~scene~features['BPT_ROOF'],cam)[1]
exit 0
::requires 'SlamHarbourOperaWestWalk.cls'