/* Four-frame tracking on the real 1920x1080 native RGBA screenshot pixels.
 * 20:24:30 to 20:37:11, no field-of-view extrapolation or star identities. */
numeric digits 17
parse arg root
if root='' then root='/mnt/data'
names=.array~of('image(20261109-134731).png','image(20261109-134816).png', -
 'image(20261109-134847).png','image(20261109-135033).png')
times=.array~of(425,880,892,1186)
all=.array~new;g=.array~new;align=.array~new
m=.MoonsaultStillPointScan
do i=1 to 4
  source=.MediaLocalByteSource~new(root'/'names[i])
  f=.MediaPngFile~new(source)~decode;source~close
  lum=.MediaRasterPlanes~luma(f~pixels,f~width,f~height,4)
  g~append(lum)
  all~append(m~scan(lum,f~width,f~height))
  if i=1 then align~append(.array~of(0,0,0))
  else align~append(m~register(g[1],lum,1920,1080))
  say 'FRAME' i 'candidates='all[i]~items 'alignment='align[i][1] align[i][2]
end
tracks=m~trackWindow(all,times,align)
say 'FOUR_FRAME_RAW_TRACKS' tracks~items
tracks=m~uniqueTracks(tracks)
say 'FOUR_FRAME_UNIQUE_TRACKS' tracks~items
do tr over tracks
  p=tr['POINTS']
  say 'TRACK' tr['START_X'] tr['START_Y'] '->' tr['END_X'] tr['END_Y'] 'rms='format(tr['RMS'],,3) -
    'middle='p[2]['X'] p[2]['Y'] p[3]['X'] p[3]['Y']
end
if tracks~items<>6 then do
  say 'FAIL expected six distinct four-frame sources';exit 8
end
say 'PASS: six unique four-frame tracks, duplicate optical peak rejected'
::requires '../src/MoonsaultStillPointScan.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaLocalByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaPngFile.cls'