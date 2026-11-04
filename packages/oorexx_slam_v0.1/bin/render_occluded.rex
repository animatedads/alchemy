numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg site output
if site=='' then site='NORTH_PTZ'
if output=='' then output='occluded_'site'.svg'
p=.HarbourOcclusionPanorama~new
result=p~configure
cam=p~render(site,output,2880,720)
say 'Power SLAM v0.21 genuine SVG' output
say 'SITE' site 'CAMERA_HEIGHT_M' cam[3]
say 'SCENE_BOXES' p~scene~boxes~items
say 'APPROACH_SEGMENTS' result['SEGMENTS']
say 'OVERDRAW' 'OPAQUE_DEPTH_SORTED_FACES_WITH_NUMERIC_RAY_LABEL_VISIBILITY'
say 'APPROACH' result['STATUS']
exit 0
::requires 'SlamHarbourOcclusion.cls'