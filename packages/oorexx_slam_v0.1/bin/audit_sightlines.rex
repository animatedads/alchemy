numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
p=.HarbourOcclusionPanorama~new
r=p~configure
say 'site feature bearing elevation status blocker'
do key over .array~of('NORTH_PTZ','CAFE_SYDNEY','OPERA_WEST_WALK')
 cam=p~siteCamera(key)
 do id over .array~of('O','N','S','T','BPT_ROOF','STATION_C','CAHILL_C')
  pt=p~scene~features[id]
  x=p~pointAngles(pt,cam)
  ignore=''
  if id=='O' then ignore='OPERA'
  if id=='T' then ignore='SALESFORCE'
  if id=='BPT_ROOF' then ignore='BLUES_POINT_TOWER'
  blocker=.HarbourRayOcclusion~firstHit(p~scene,cam,pt,ignore)
  if blocker=='' then blocker='CLEAR'
  say key id x[1] x[2] blocker
 end
end
::requires 'SlamHarbourOcclusion.cls'