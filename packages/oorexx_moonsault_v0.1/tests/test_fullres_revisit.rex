/* Native ooRexx full-resolution point/nonpoint morphology regression. */
numeric digits 30
w=100;h=80;cw=25;ch=20
raw=''
do y=0 to h-1
  do x=0 to w-1
    v=25
    if x>=58 & x<=81 & y>=12 & y<=42 then v=125
    if x=22 & y=21 then v=230
    raw=raw||d2c(v,1)||d2c(v,1)||d2c(v,1)
  end
end
mask=copies('00'x,cw*ch)
mask=overlay('ff'x,mask,5*cw+5+1)
do y=4 to 8
  do x=15 to 19
    mask=overlay('ff'x,mask,y*cw+x+1)
  end
end
frame=.MediaRasterImage~new(raw,w,h,3,'SYNTHETIC_STARS_AND_CLOUDS')
clusters=.MoonsaultFullResolutionRevisit~examine(frame,mask,cw,ch,2,2,22,12)
points=0;diffuse=0
say 'NCLUSTERS' clusters~items
do c over clusters
 say 'CANDIDATE coarse='c['COARSE_X'] c['COARSE_Y'] 'px='c['FRAME_X'] c['FRAME_Y'] -
   'area='c['COARSE_AREA'] 'contrast='c['CONTRAST'] 'status='c['STATUS']
 if c['STATUS']='POINT_LIKE_UNIDENTIFIED' then points+=1
 else diffuse+=1
end
if points<>1 | diffuse<>1 then do
  say 'FAIL: full-resolution point/cloud separation';exit 1
end
/* A second independent image with a one-pixel star displacement should
 * corroborate; removing that point should instead reject it. */
removed=overlay(x2c('191919'),raw,(21*w+22)*3+1)
shifted=overlay(x2c('E6E6E6'),removed,(21*w+23)*3+1)
second=.MediaRasterImage~new(shifted,w,h,3,'STAR_ONE_PIXEL_RIGHT')
none=.MediaRasterImage~new(removed,w,h,3,'STAR_ABSENT')
confirmed=.MoonsaultFullResolutionRevisit~corroborateShortInterval(frame,second,22,21,12,2)
if confirmed['STATUS']<>'PERSISTENT_POINT_UNIDENTIFIED' then do
  say 'FAIL: real moving point not corroborated';exit 1
end
missing=.MoonsaultFullResolutionRevisit~corroborateShortInterval(none,frame,22,21,12,2)
if missing['STATUS']<>'TRANSIENT_REJECTED' then do
  say 'FAIL: missing point passed time corroboration';exit 1
end
say 'PASS: full-resolution point retained; diffuse cloud rejected'
exit 0
::requires '../src/MoonsaultFullResolutionRevisit.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaRasterOps.cls'