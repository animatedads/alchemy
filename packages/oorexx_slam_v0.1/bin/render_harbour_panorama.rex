/* Power SLAM three-location panorama renderer. All geometry computed in ooRexx. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg dest
if dest=='' then dest='.'
p=.HarbourPanorama~new
checks=0
call check p~scene~boxes~items=7,'four pylons, deck, Opera, Salesforce'
call check p~bearing(0,1)=0,'north bearing zero'
call check p~bearing(1,0)=90,'east bearing 90'
call check p~bearing(0,-1)=180,'south bearing 180'
call check p~bearing(-1,0)=270,'west bearing 270'
call check abs(p~bearing(1,1)-45)<0.00001,'NE bearing 45'
call check abs(p~bearing(-1,-1)-225)<0.00001,'SW bearing 225'
call check p~scene~features['T'][3]=263,'Salesforce top at 263m'
do key over .array~of('KIRRIBILLI','CIRCULAR','BLUES')
  cam=p~siteCamera(key)
  call check cam[3]=50,key 'camera has 50m sea level elevation'
  call check cam\==.nil,key 'camera exists'
  file=dest || '/' || key~lower || '_model_360.svg'
  say 'Rendering' key 'to' file
  p~render(key,file)
  call check stream(file,'C','QUERY EXISTS')\=='',key 'SVG written'
  do id over .array~of('N','S','O','T')
    pt=p~scene~features[id]
    projected=p~project(pt,cam,2880,720)
    say 'BEARING' key id 'azimuth' format(projected[4],3,2) 'elevation' format(projected[5],3,2)
    call check projected[1]>=0 & projected[1]<2880,key id 'projected azimuth within panorama'
  end
end
say 'POWER SLAM EQUIRECT MODEL PANORAMA: PASS (' || checks || ' checks)'
exit 0
check: procedure expose checks
  use arg yes,message
  checks+=1
  if yes then say 'PASS' message
  else do
    say 'FAIL' message
    exit 1
  end
  return
::requires 'SlamHarbourPanorama.cls'
