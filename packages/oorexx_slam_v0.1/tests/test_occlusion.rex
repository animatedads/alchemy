numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
s=.HarbourScene~new
s~boxes=.array~new
s~boxes~append(s~cuboid('WALL',10,0,0,4,6,15,1,0,0,1))
from=.array~of(0,0,5)
call check .HarbourRayOcclusion~firstHit(s,from,.array~of(20,0,5))=='WALL','occludes ray behind wall'
call check .HarbourRayOcclusion~firstHit(s,from,.array~of(20,10,5))=='','clear lateral ray'
call check .HarbourRayOcclusion~firstHit(s,from,.array~of(20,0,40))=='','clear above-wall ray'
call check .HarbourRayOcclusion~firstHit(s,from,.array~of(5,0,5))=='','target short of wall'
call check .HarbourRayOcclusion~firstHit(s,from,.array~of(20,0,5),'WALL')=='','ignored owning wall'
p=.HarbourOcclusionPanorama~new
call check p~scene~boxes~items==27,'preexisting quay solids'
st=p~configure
call check st['STATUS']=='APPROACH_BERM_UNSURVEYED_VISIBLE_OCCLUDER','explicit status'
call check st['SEGMENTS']>12,'multiple short segments'
call check st['BOXES_ADDED']==2*st['SEGMENTS'],'ramp and retaining pair per section'
call check st['EASTERN_TUNNEL']=='NOT_MODELLED_AS_SURFACE_BERM','no false tunnel overdraw'
call check p~scene~features~hasIndex('BPT_ROOF'),'tower reference retained'
call check p~scene~features~hasIndex('CAHILL_C'),'existing station retained'
call check p~scene~boxes~items==30+st['BOXES_ADDED'],'only additive berm geometry'
call check p~siteCamera('NORTH_PTZ')[3]==79,'north ptz camera height hypothesis'
call check p~siteCamera('OPERA_WEST_WALK')[3]==7,'opera walkway camera'
call check p~siteCamera('CAFE_SYDNEY')[3]==25,'cafe camera'
cam=p~siteCamera('NORTH_PTZ')
call check .HarbourRayOcclusion~firstHit(p~scene,cam,.array~of(3000,3000,1000))=='','sky ray clears structure'
call check p~approachSegments==st['SEGMENTS'],'segment count observable'
call check p~scene~features['S_DECK'][3]==49,'corrected bridge deck retained'
call check p~scene~features['BPT_ROOF'][3]==83,'tower reference with 0m assumed base'

/* Real scene evidence: foreground station behind Cahill; bridge partial blocking. */
cafe=p~siteCamera('CAFE_SYDNEY')
call check \p~featureVisible('STATION_C',cafe),'Cahill obscures station centre'
call check p~featureVisible('CAHILL_C',cafe),'Cahill top is visible'
walk=p~siteCamera('OPERA_WEST_WALK')
call check \p~featureVisible('S',walk),'south bridge coordinate hidden by solid pylon'
call check p~featureVisible('N',walk),'north bridge coordinate remains visible through gap'
call check p~featureVisible('BPT_ROOF',walk),'Blues tower visible around bridge solids'
/* Test a real generated berm prism alone. Low line blocked, high line clear. */
single=.HarbourScene~new
single~boxes=.array~new
b=.nil
n=0
do it over p~scene~boxes
 if it[1]=='CAHILL_BERM' then do
  n+=1
  if n==20 then b=it
 end
end
call check b\==.nil,'twentieth real berm block exists'
single~boxes~append(b)
v=b[2]
cx=(v[1][1]+v[4][1])/2;cy=(v[1][2]+v[4][2])/2
wx=v[2][1]-v[1][1];wy=v[2][2]-v[1][2]
w=HSqrt(wx*wx+wy*wy)
wx=wx/w;wy=wy/w
low0=.array~of(cx+wx*50,cy+wy*50,8)
low1=.array~of(cx-wx*50,cy-wy*50,8)
hi0=.array~of(cx+wx*50,cy+wy*50,80)
hi1=.array~of(cx-wx*50,cy-wy*50,80)
call check .HarbourRayOcclusion~firstHit(single,low0,low1)=='CAHILL_BERM','actual berm mass blocks ground ray'
call check .HarbourRayOcclusion~firstHit(single,hi0,hi1)=='','sky ray clears same berm'

say 'Power SLAM V021 OCCLUSION PASS' checks 'checks'
exit 0
check: procedure expose checks
  use arg passed,what
  if \passed then do
    say 'FAIL' what
    exit 3
  end
  checks+=1
  return
::requires 'SlamHarbourOcclusion.cls'