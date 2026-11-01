/* Render both new camera candidates against bridge, wharf, rail and road solids. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg dir
if dir=='' then dir='.'
p=.HarbourQuayInfrastructurePanorama~new
say '3D cuboids:' p~scene~boxes~items
say 'Station platform length (m):' format(p~getStructure('CQ_STATION')['LENGTH_M'],5,2)
do site over .array~of('CAFE_SYDNEY','NORTH_SHORE','BLUES')
  file=dir || '/' || site~lower || '_quay_360.svg'
  camera=p~render(site,file)
  say site 'height:' camera[3] 'm ASL  SVG:' file
  do id over .array~of('STATION_W','STATION_E','CAHILL_C','O','S','N','T')
    f=p~scene~features[id]
    ang=p~pointAngles(f,camera)
    say '  ' id~left(12) 'bearing' format(ang[1],3,2) 'elevation' format(ang[2],3,2)
  end
end
exit 0
::requires 'SlamHarbourQuayInfrastructure.cls'
