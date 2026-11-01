/* Render user-provided north shore coordinate; preserve earlier viewpoints. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg dest
if dest=='' then dest='.'
p=.HarbourNorthShorePanorama~new
site='NORTH_SHORE'
file=dest || '/north_shore_360.svg'
p~render(site,file)
say 'POWER SLAM NORTH-SHORE CANDIDATE lat=-33.848849 lon=151.213921, z=50m ASL'
say 'SVG:' file 'cuboids:' p~scene~boxes~items
cam=p~siteCamera(site)
do id over .array~of('N','S','O','T','CQ2','CQ3','CQ4','CQ5','CQ6','WB23','WB45','WB67','WB89')
  v=p~pointAngles(p~scene~features[id],cam)
  say id~left(5) 'bearing' format(v[1],3,2) 'elevation' format(v[2],3,2) 'range(m)' format(v[3],5,1)
end
say 'POSITION / WATER / BUILDING OCCLUSION NOT YET CERTIFIED'
exit 0
::requires 'SlamHarbourNorthShore.cls'
