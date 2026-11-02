numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
parse arg tileFile
if tileFile=='' then tileFile='examples/SYNTHETIC_harbour_dem.tile'
tile=.HarbourTerrainTile~new(tileFile)
scene=.HarbourScene~new
scene~boxes=.array~new
call check tile~source=='SYNTHETIC_RIDGE_TEST_DO_NOT_USE_FOR_HARBOUR','source provenance'
call check tile~frame=='SCENE_33.852S_151.210E','horizontal local frame'
call check tile~crs=='SLAM_LOCAL_ENU_V1','horizontal CRS'
call check tile~datum=='AHD','vertical AHD datum'
call check tile~columns==7 & tile~rows==3,'tile shape'
call check tile~resolution==10,'grid resolution'
call check tile~uncertainty=0.3,'vertical uncertainty'
call check tile~sample(30,-10)['HEIGHT_M']==8,'ridge height from file'
call check tile~sample(20,-20)['STATUS']=='WATER_NOT_LAND','water cell distinct from below-sea terrain'
call check tile~sample(40,-20)['STATUS']=='UNKNOWN_NODATA','nodata preserved'
call check tile~sample(300,-20)['STATUS']=='UNKNOWN_OUTSIDE_TILE','outside raster unknown'
start=.array~of(0,-10,5);target=.array~of(60,-10,5)
r=.HarbourTerrainVisibility~trace(tile,scene,start,target,'AHD','AHD')
call check r['STATUS']=='BLOCKED_TERRAIN','land ridge blocks low ray'
call check r['OCCLUDER']=='TERRAIN','ridge named first hit'
call check r['FIRST_LOCAL_POINT'][1]>20 & r['FIRST_LOCAL_POINT'][1]<40,'first terrain intercept local x'
call check r['FIRST_LOCAL_POINT'][3]==5,'first terrain intercept ray elevation'
call check r['FIRST_RANGE_M']>20 & r['FIRST_RANGE_M']<40,'ridge first intercept distance'
r=.HarbourTerrainVisibility~trace(tile,scene,.array~of(0,-10,12),.array~of(60,-10,12),'AHD','AHD')
call check r['STATUS']=='CLEAR','higher ray clears ridge'
r=.HarbourTerrainVisibility~trace(tile,scene,start,target,'ASL','AHD')
call check r['STATUS']=='UNKNOWN_VERTICAL_DATUM','ASL not silently equated to AHD'
r=.HarbourTerrainVisibility~trace(tile,scene,.array~of(20,-20,7),.array~of(60,-20,7),'AHD','AHD')
call check r['STATUS']=='UNKNOWN_FIXED_CAMERA_OVER_WATER','fixed camera not admitted on blue water'
r=.HarbourTerrainVisibility~trace(tile,scene,.array~of(0,-20,12),.array~of(60,-20,12),'AHD','AHD')
call check r['STATUS']=='UNKNOWN_NODATA','nodata in water/land ray cannot be clear'
r=.HarbourTerrainVisibility~trace(tile,scene,.array~of(0,-10,12),.array~of(100,-10,12),'AHD','AHD')
call check r['STATUS']=='UNKNOWN_OUTSIDE_TILE','ray cannot exit dataset and claim clear'
scene~boxes~append(scene~cuboid('TEST_BUILDING',10,-10,0,4,6,15,1,0,0,1))
r=.HarbourTerrainVisibility~trace(tile,scene,start,target,'AHD','AHD')
call check r['STATUS']=='BLOCKED_STRUCTURE','near building blocks before distant ridge'
call check r['OCCLUDER']=='TEST_BUILDING','building ID preserved'
call check r['FIRST_LOCAL_POINT'][1]>5 & r['FIRST_LOCAL_POINT'][1]<10,'first building local x' 
r=.HarbourTerrainVisibility~trace(tile,scene,.array~of(0,-10,20),.array~of(60,-10,20),'AHD','AHD')
call check r['STATUS']=='CLEAR','ray clears building and ridge'
scene~boxes=.array~new
scene~boxes~append(scene~cuboid('REAR_BUILDING',50,-10,0,4,6,15,1,0,0,1))
r=.HarbourTerrainVisibility~trace(tile,scene,start,target,'AHD','AHD')
call check r['STATUS']=='BLOCKED_TERRAIN','near terrain beats far building'
scene~boxes=.array~new
scene~boxes~append(scene~cuboid('BUILDING_AFTER_NODATA',50,-20,0,4,6,15,1,0,0,1))
r=.HarbourTerrainVisibility~trace(tile,scene,.array~of(0,-20,7),.array~of(60,-20,7),'AHD','AHD')
call check r['STATUS']=='UNKNOWN_NODATA','unsurveyed gap in front of wall fails closed'
call check r['METRIC_POSE_ADMISSION']=='NOT_ADMITTED','no camera admission after unknown terrain'
call check r['PROVENANCE']==tile~source,'source retained in result'
say 'Power SLAM v022 SYNTHETIC TERRAIN VISIBILITY PASS' checks 'checks'
exit 0
check: procedure expose checks
  use arg passed,why
  if \passed then do
    say 'FAIL' why
    exit 4
  end
  checks+=1
  return
::requires 'SlamHarbourTerrain.cls'