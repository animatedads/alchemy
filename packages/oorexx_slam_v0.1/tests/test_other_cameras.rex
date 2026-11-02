numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
f=.HarbourOtherCameraFit~new
checks=0
p=f~seed('BLUES_TOWER');n=f~seed('NORTH_SHORE')
call ok f~model~scene~features~hasIndex('NW_ROOF_PIN'),'physical rooftop source installed'
call ok f~model~scene~features~hasIndex('SE_ROOF_PIN'),'all four pylon roof points installed'
call ok abs(f~geodetic(p)[1]+33.8490006)<0.000001,'Blues seed latitude'
call ok abs(f~geodetic(p)[2]-151.203533)<0.000001,'Blues seed longitude'
call ok abs(f~geodetic(n)[1]+33.848849)<0.000001,'North seed latitude'
call ok abs(f~geodetic(n)[2]-151.213921)<0.000001,'North seed longitude'
call ok f~activeWidth=1260,'active source width excludes black bars'
call ok f~activeHorizontalFov(440)>109 & f~activeHorizontalFov(440)<111,'Blues active FOV is approximately 110 degrees'
call ok f~activeHorizontalFov(740)>80 & f~activeHorizontalFov(740)<82,'North active FOV is approximately 81 degrees'
call ok f~activeHorizontalFov(740)<f~horizontalFov(740),'sidebars cannot widen optical FOV'
do key over .array~of('BLUES_TOWER','NORTH_SHORE')
  ob=f~observations(key,'BRIDGE')
  all=f~observations(key,'ALL')
  call ok ob~items=4,'pylon photo features explicitly 4'
  call ok all~items=7,'holdouts explicitly 3'
  call ok f~limits(key)[1][3]<f~limits(key)[2][3],'height range defined'
  do o over ob
    call ok f~model~scene~features~hasIndex(o[1]),'roof/deck point has true physical id'
    call ok o[4]>0,'observation uncertainty is positive'
  end
  q=f~seed(key)
  call ok f~score(q,ob)<1e20,'initial camera is projectable'
  hs=f~holdouts(key,q)
  call ok hs~items=3,'independent three-holdout set'
  d=.directory~new;d['POSE']=q
  call ok f~qualify(key,d)\=='ACCEPTED','no unverified camera admission'
end
say 'POWER SLAM OTHER CAMERA v0.14:' checks '/' checks 'PASS'
exit 0
ok: procedure expose checks
 use arg good,label
 if \good then do
   say 'FAIL:' label
   exit 1
 end
 checks+=1
 return
::requires 'SlamHarbourOtherCameraFit.cls'