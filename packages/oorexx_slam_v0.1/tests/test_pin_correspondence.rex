/* Power SLAM v0.13 roof-pin correspondence and fail-closed holdout tests. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
c=.HarbourPinCorrespondence~new
checks=0
alts=c~alternatives
call ok alts~items=4,'all four north/south identity assignments'
do pair over alts
  o=c~observations(pair[1],pair[2])
  call ok o~items=4,'four image controls for 'pair[1]||'/'||pair[2]
  call ok o[1][1]==pair[1]||'_ROOF_PIN','physical south roof feature ID'
  call ok o[2][1]==pair[2]||'_ROOF_PIN','physical north roof feature ID'
  call ok o[3][1]==pair[1]||'_DECK_PROXY','same south pylon deck proxy'
  call ok o[4][1]==pair[2]||'_DECK_PROXY','same north pylon deck proxy'
  a=c~world(o[1][1]);b=c~world(o[2][1])
  call ok a[3]=89 & b[3]=89,'pylon tops 89m ASL'
  call ok c~world(o[3][1])[3]=50 & c~world(o[4][1])[3]=50,'deck proxies 50m ASL'
end
call ok expectReject(c,'S_TOP'),'midpoint south top refused as photographed tower'
call ok expectReject(c,'N_DECK'),'midpoint north deck refused as photographed tower'
f=c~fitter
initial=f~initialCamera
call ok c~nearBoundary(initial)==.false,'initial roof centre not at envelope boundary'
b=f~cameraPolygon~bounds
p=initial~copy;p[1]=b[1]+0.5
call ok c~nearBoundary(p)==.true,'roof polygon boundary detected'
q=.directory~new;q['CHI2']=0;q['POSE']=initial
r=c~qualify(q,c~observations('SW','NW'))
call ok r['STATUS']\=='ACCEPTED','even perfect training reprojection is unqualified'
call ok r['ARCH_HOLDOUT_PX']>0,'independent arch holdout computed'
q['POSE']=.nil
r=c~qualify(q,c~observations('SW','NW'))
call ok r['STATUS']=='BLOCKED_NO_CAMERA_SOLUTION','nil pose must fail closed'
say 'POWER SLAM PIN CORRESPONDENCE v0.13:' checks '/ ' checks 'PASS'
exit 0
ok: procedure expose checks
  use arg pass,label
  if \pass then do
    say 'FAIL:' label
    exit 1
  end
  checks+=1
  say 'PASS:' label
  return
expectReject: procedure
  use arg c,id
  signal on syntax name trap
  dummy=c~world(id)
  return .false
trap:
  return .true
::requires 'SlamHarbourPinCorrespondence.cls'