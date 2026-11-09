/* Native PNG -> grayscale -> ooRexx five-frame sky tracks and streak rejection. */
numeric digits 30
parse arg root output
if root='' then root='/mnt/data'
if output='' then output='out'
names=.array~of('image(20261109-134604).png', -
  'image(20261109-134731).png','image(20261109-134816).png', -
  'image(20261109-134847).png','image(20261109-135033).png')
times=.array~of('20:17:25','20:24:30','20:32:05','20:32:17','20:37:11')
clock=.array~of(0,425,880,892,1186)
all=.array~new;greys=.array~new;alignments=.array~new
report=output||'/sydney_stars_candidates.tsv'
header='frame'||'09'x||'time'||'09'x||'x'||'09'x||'y'||'09'x||'contrast'||'09'x||'peak'||'0a'x
ignore=charout(report,header,1)
do i=1 to names~items
  source=.MediaLocalByteSource~new(root'/'names[i])
  frame=.MediaPngFile~new(source)~decode
  source~close
  lum=.MediaRasterPlanes~luma(frame~pixels,frame~width,frame~height,4)
  greys~append(lum)
  points=.MoonsaultStillPointScan~scan(lum,frame~width,frame~height)
  all~append(points)
  do p over points
    line=i||'09'x||times[i]||'09'x||p['X']||'09'x||p['Y']||'09'x|| -
      format(p['CONTRAST'],,2)||'09'x||p['PEAK']||'0a'x
    ignore=charout(report,line)
  end
  say 'SKY' i times[i] 'sky candidates='points~items
  if i=1 then alignments~append(.array~of(0,0,0))
  else do
    registration=.MoonsaultStillPointScan~register(greys[1],lum,1920,1080)
    say 'REGISTER' i 'dx='registration[1] 'dy='registration[2] 'mean absolute error='registration[3]
    alignments~append(registration)
  end
end
ignore=stream(report,'C','CLOSE')
tracks=.MoonsaultStillPointScan~trackFive(all,clock,alignments)
trackFile=output||'/sydney_fiveframe_tracks.tsv'
ignore=charout(trackFile,'x0 y0 x5 y5 vx_px_s vy_px_s rms_px'||'0a'x,1)
do tr over tracks
  say 'TRACK 5/5' tr['START_X'] tr['START_Y'] '->' tr['END_X'] tr['END_Y'] 'rms='format(tr['RMS'],,3)
  line=tr['START_X']' 'tr['START_Y']' 'tr['END_X']' 'tr['END_Y']' ' -
       tr['VX']' 'tr['VY']' 'tr['RMS']||'0a'x
  ignore=charout(trackFile,line)
end
ignore=stream(trackFile,'C','CLOSE')
if tracks~items<3 then do
  say 'FAIL fewer than 3 temporal tracks across five stills'
  exit 32
end
clusters=.MoonsaultStillPointScan~elongatedClusters(all[4])
foundStreak=.false
do cl over clusters
  say 'MULTI_PEAK' cl['LEFT'] cl['TOP'] cl['RIGHT'] cl['BOTTOM'] 'peaks='cl['MEMBERS']
  if cl['LEFT']>=310 & cl['RIGHT']<=330 & cl['TOP']>=255 & cl['BOTTOM']<=265 then -
    foundStreak=.true
end
if \foundStreak then do
  say 'FAIL streak-like multi-peak candidate missing from frame 4'
  exit 33
end
pairs=.MoonsaultStillPointScan~shortMatches(all[3],all[4])
say 'PERSIST 12 seconds 20:32:05 to 20:32:17 candidate pairs='pairs~items
say 'PASS ooRexx five-frame sky tracking and observed transient streak proposal'
exit 0
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaLocalByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaPngFile.cls'
::requires '../src/MoonsaultStillPointScan.cls'