numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
parse arg baseDir
if baseDir=='' then baseDir='examples'
a=.HarbourTerrainTile~new(baseDir'/SYNTHETIC_harbour_dem.tile')
b=.HarbourTerrainTile~new(baseDir'/SYNTHETIC_neighbour.tile')
c=.HarbourTerrainTile~new(baseDir'/SYNTHETIC_conflict.tile')
m=.HarbourTerrainMosaic~new
m~appendTile(a)
m~appendTile(b)
call check m~datum=='AHD','shared vertical datum'
call check m~frame==a~frame,'matched local frame'
call check m~sample(0,-10)['STATUS']=='LAND_AHD','first tile sampled'
call check m~sample(120,-10)['STATUS']=='LAND_AHD','second tile sampled'
call check m~sample(60,-10)['STATUS']=='LAND_AHD','consistent overlap admitted'
call check m~sample(90,-10)['HEIGHT_M']==9,'ridge in second tile returned'
call check m~sample(150,-10)['STATUS']=='UNKNOWN_OUTSIDE_MOSAIC','outside tile coverage unknown'
call check m~sample(40,-20)['STATUS']=='UNKNOWN_NODATA_IN_MOSAIC','nodata cannot be filled from another cell'
s=.HarbourScene~new;s~boxes=.array~new
r=.HarbourTerrainVisibility~trace(m,s,.array~of(0,-10,20),.array~of(120,-10,20),'AHD','AHD')
call check r['STATUS']=='CLEAR','ray clears two consistent tiles'
r=.HarbourTerrainVisibility~trace(m,s,.array~of(0,-10,5),.array~of(120,-10,5),'AHD','AHD')
call check r['STATUS']=='BLOCKED_TERRAIN','first tile ridge still blocks'
r=.HarbourTerrainVisibility~trace(m,s,.array~of(65,-10,5),.array~of(120,-10,5),'AHD','AHD')
call check r['STATUS']=='BLOCKED_TERRAIN','second tile ridge blocks independently'
r=.HarbourTerrainVisibility~trace(m,s,.array~of(65,-10,20),.array~of(120,-10,20),'AHD','AHD')
call check r['STATUS']=='CLEAR','second tile higher ray clears'
q=.HarbourTerrainMosaic~new
q~appendTile(a)
q~appendTile(c)
call check q~sample(60,-10)['STATUS']=='UNKNOWN_TILE_ROLE_CONFLICT','overlap land water role conflict'
r=.HarbourTerrainVisibility~trace(q,s,.array~of(0,-10,20),.array~of(120,-10,20),'AHD','AHD')
call check r['STATUS']=='UNKNOWN_TILE_ROLE_CONFLICT','no clear ray across contradictory seam'
call check r['METRIC_POSE_ADMISSION']=='NOT_ADMITTED','mosaic conflict cannot qualify camera'
h=.HarbourTerrainTile~new(baseDir'/SYNTHETIC_height_conflict.tile')
x=.HarbourTerrainMosaic~new
x~appendTile(a)
x~appendTile(h)
call check x~sample(60,-10)['STATUS']=='UNKNOWN_TILE_HEIGHT_CONFLICT','overlap heights disagree beyond uncertainty'
rot=.HarbourTerrainTile~new(baseDir'/SYNTHETIC_rotated.tile')
call check rot~sample(10,-20)['HEIGHT_M']==4,'affine rotation locates row2 column2'
call check rot~sample(0,-20)['HEIGHT_M']==2,'affine rotation locates row1 column2'
call check rot~sample(10,-30)['HEIGHT_M']==3,'affine rotation locates row2 column1'

say 'Power SLAM v022 SYNTHETIC TILE MOSAIC PASS' checks 'checks'
exit 0
check: procedure expose checks
  use arg passed,why
  if \passed then do; say 'FAIL' why; exit 4; end
  checks+=1
  return
::requires 'SlamHarbourTerrain.cls'