numeric digits 30
parse arg filename
if filename='' then filename='/mnt/data/WebcamSydney 1 Live Stream of Harbour 247 4K(1).mp4'
src=.MediaLocalByteSource~new(filename)
f=.MediaMp4AvcAccess~new(src)
say 'OPEN MP4 source='filename 'sampleCount=' f~sampleCount 'scale=' f~timeScale 'syncPoints=' f~syncCount
x=f~frameAt(90000*5,4000000,180)
if x==.nil then do
 say 'NO FRAME AT 5 seconds; compressed bytes='f~frameReadBytes
 exit 4
end
say 'DECODED' x~width x~height 'PTS=' x~presentationTicks 'compressed bytes=' f~frameReadBytes
x~savePpm('/mnt/data/moonsault_20261110/frame5.ppm')
src~close
say 'PASS: native ooRexx MP4 H264 sample map and pixels'
::requires '../src/MediaByteSource.cls'
::requires '../src/MediaLocalByteSource.cls'
::requires 'support/MediaMp4AvcAccess.cls'