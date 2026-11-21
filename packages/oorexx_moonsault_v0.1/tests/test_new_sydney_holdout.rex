/* Held-out independent 1080p MP4 decoded frames. Never used to fit 9 tracks. */
numeric digits 30
root='/mnt/data'
files=.array~of('WebcamSydney 1 Live Stream of Harbour 247 4K(1).mp4', -
                 'WebcamSydney 1 Live Stream of Harbour 247 4K(2).mp4')
trackFile='/mnt/data/moonsault_20261110/six_frame_star_tracks.tsv'
ignore=stream(trackFile,'C','OPEN READ');ignore=linein(trackFile)
tracks=.array~new
do while lines(trackFile)>0
 row=linein(trackFile);if row='' then iterate
 parse var row x0 '09'x y0 '09'x xlast '09'x ylast '09'x vx '09'x vy '09'x rms
 tracks~append(.array~of(x0,y0,vx,vy))
end
ignore=stream(trackFile,'C','CLOSE')
if tracks~items<>9 then raise syntax 88.900 array('wrong reference track count')
output='/mnt/data/moonsault_20261110/heldout_star_residuals.tsv'
ignore=charout(output,'clip'||'09'x||'second'||'09'x||'track'||'09'x||'expected_x'||'09'x||'expected_y'||'09'x|| -
 'measured_x'||'09'x||'measured_y'||'09'x||'error_pixels'||'0a'x,1)
samples=.array~of(15,45)
total=0;hits=0;errSum=0
 do i=1 to files~items
 source=.MediaLocalByteSource~new(root||'/'||files[i])
 mp4=.MediaMp4AvcAccess~new(source)
 do j=1 to samples~items
   secs=samples[j]
   frame=mp4~frameAt(secs*90000,2097152,180)
   if frame==.nil then raise syntax 88.900 array('heldout media frame missing')
   lum=.MediaRasterPlanes~luma(frame~pixels,1920,1080,3)
   proposals=.MoonsaultStillPointScan~scan(lum,1920,1080,45,1875,25,375,8,2000)
   global=(i-1)*275+secs
   localHits=0
   do k=1 to tracks~items
     t=tracks[k]
     predictedX=t[1]+t[3]*(global-5)
     predictedY=t[2]+t[4]*(global-5)
     closest=3.5*3.5;winner=.nil
     do p over proposals
       dx=p['X']-predictedX;dy=p['Y']-predictedY;dist2=dx*dx+dy*dy
       if dist2<closest then do
         closest=dist2;winner=p
       end
     end
     total+=1
     if winner<>.nil then do
       hits+=1;localHits+=1;errSum+=closest
       say 'HELDOUT' i secs k 'measured' winner['X'] winner['Y'] 'err='format(sqrtLocal(closest),,2)
       ignore=charout(output,i||'09'x||secs||'09'x||k||'09'x|| -
         format(predictedX,,3)||'09'x||format(predictedY,,3)||'09'x|| -
         winner['X']||'09'x||winner['Y']||'09'x||format(sqrtLocal(closest),,3)||'0a'x)
     end
     else say 'MISS heldout' i secs k 'prediction' predictedX predictedY
   end
   say 'HELDOUT_FRAME' i secs 'matched' localHits 'of 9 proposals' proposals~items
 end
 source~close
end
ignore=stream(output,'C','CLOSE')
say 'TOTAL_HELDOUT_MATCHES' hits '/' total
if hits<28 then exit 4
say 'HELDOUT_RMS_PIXELS' format(sqrtLocal(errSum/hits),,3)
say 'PASS: independent 4-frame 9-track held-out native evidence'
exit 0
sqrtLocal: procedure
 use strict arg n
 if n<=0 then return 0
 guess=max(1,n)
 do 28
 guess=(guess+n/guess)/2
 end
 return guess
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaLocalByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaMp4AvcAccess.cls'
::requires '../src/MoonsaultStillPointScan.cls'