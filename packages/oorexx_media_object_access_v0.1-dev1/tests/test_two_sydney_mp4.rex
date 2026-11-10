/* Native ooRexx MP4 sample-table random access, no video subprocess. */
numeric digits 30
root='/mnt/data';output='/mnt/data/moonsault_20261110'
names=.array~of('WebcamSydney 1 Live Stream of Harbour 247 4K(1).mp4', -
  'WebcamSydney 1 Live Stream of Harbour 247 4K(2).mp4')
times=.array~of(5,30,60)
do i=1 to names~items
 src=.MediaLocalByteSource~new(root||'/'||names[i])
 f=.MediaMp4AvcAccess~new(src)
 say 'MEDIA' i 'samples=' f~sampleCount 'timescale=' f~timeScale 'syncs=' f~syncCount
 do j=1 to times~items
   target=times[j]*90000
   frame=f~frameAt(target,2097152,200)
   if frame==.nil then do
     say 'UNAVAILABLE' i times[j] 'seekBytes='f~frameReadBytes
     iterate
   end
   filename=output||'/clip'||i||'_t'||times[j]||'.ppm'
   frame~savePpm(filename)
   say 'DECODE' i times[j] 'pts='frame~presentationTicks 'bytes=' f~frameReadBytes 'rgb='frame~width frame~height
 end
 src~close
end
::requires '../src/MediaByteSource.cls'
::requires '../src/MediaLocalByteSource.cls'
::requires 'support/MediaMp4AvcAccess.cls'