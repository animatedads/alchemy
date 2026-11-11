/* User-annotated screenshot provides 16 rough regions, never star identities.
 * Compare AFTER annotation only against unmarked frame evidence from ooRexx
 * MP4 demux/H264 decode: six independently timestamped exposures.
 */
numeric digits 30
sourceFile='/mnt/data/moonsault_20261110/all_bright_points.tsv'
trackFile='/mnt/data/moonsault_20261110/six_frame_star_tracks.tsv'
ignore=stream(sourceFile,'C','OPEN READ')
ignore=linein(sourceFile)
pts=.array~new
do i=1 to 6
 pts~append(.array~new)
end
do while lines(sourceFile)>0
 row=linein(sourceFile)
 if row='' then iterate
 parse var row clip '09'x sec '09'x xx '09'x yy '09'x con '09'x peak
 i=(clip-1)*3
 select
  when sec=5 then i+=1
  when sec=30 then i+=2
  when sec=60 then i+=3
 end
 pts[i]~append(.array~of(xx,yy,con))
end
ignore=stream(sourceFile,'C','CLOSE')
ignore=stream(trackFile,'C','OPEN READ')
ignore=linein(trackFile)
tracks=.array~new
do while lines(trackFile)>0
 row=linein(trackFile)
 if row='' then iterate
 parse var row x0 '09'x y0 '09'x x1 '09'x y1 '09'x vx '09'x vy '09'x rms
 tracks~append(.array~of(x0,y0,x1,y1,vx,vy,rms))
end
ignore=stream(trackFile,'C','CLOSE')
arrowTips=.array~of('15 91','309 95','284 142','304 158','290 252', -
  '47 217','513 28','562 33','626 35','519 118','563 184','498 228', -
  '1046 28','1027 90','1091 128','1160 165')
labels='ABCDEFGHIJKLMNOP'
out='/mnt/data/moonsault_20261110/arrow_region_matches.tsv'
ignore=charout(out,'label'||'09'x||'rough_video_x'||'09'x||'rough_video_y'||'09'x|| -
   'last_x'||'09'x||'last_y'||'09'x||'6frame_match'||'09'x||'video_roi_distance'||'0a'x,1)
strong=0;nearby=0
/* No annotated pixel is examined: only its geometric search-region center. */
do i=1 to arrowTips~items
 pos=arrowTips[i];parse var pos tipx tipy
 /* reference screenshot is 1317 x 737; source video 1920x1080. */
 x=tipx*1920/1317;y=tipy*1080/737
 bestDist=100000;winner=.nil
 do t over tracks
   dx=t[3]-x;dy=t[4]-y;dist2=dx*dx+dy*dy
   if dist2<bestDist then do
      bestDist=dist2;winner=t
   end
 end
 status='NO_SIX_FRAME_TRACK'
 xx='-';yy='-';separation='-'
 if bestDist<=28*28 then do
   xx=winner[3];yy=winner[4];separation=format(selfSqrt(bestDist),,2)
   status='PERSISTENT_6_OF_6';strong+=1
 end
 else do
   bestDist=28*28
   do point over pts[6]
     dx=point[1]-x;dy=point[2]-y;d2=dx*dx+dy*dy
     if d2<bestDist then do
       bestDist=d2;xx=point[1];yy=point[2]
     end
   end
   if xx<>'-' then do
     status='FRAME6_POINT_ONLY';nearby+=1;separation=format(selfSqrt(bestDist),,2)
   end
 end
 say 'ARROW' substr(labels,i,1) 'tip ('tipx','tipy') -> video ('format(x,,1)','format(y,,1)')' -
  'point ('xx','yy')' status 'distance='separation
 ignore=charout(out,substr(labels,i,1)||'09'x||format(x,,2)||'09'x||format(y,,2)||'09'x|| -
 xx||'09'x||yy||'09'x||status||'09'x||separation||'0a'x)
end
ignore=stream(out,'C','CLOSE')
say 'CONFIRMED ALL-SIX' strong 'ADDITIONAL END-FRAME' nearby 'ARROWS' arrowTips~items
if strong<8 then exit 1
say 'PASS: rough sky annotations intersect independently measured 6-epoch stars'
exit 0
selfSqrt: procedure
 use strict arg n
 if n<=0 then return 0
 guess=max(n,1)
 do 24
  guess=(guess+n/guess)/2
 end
 return guess