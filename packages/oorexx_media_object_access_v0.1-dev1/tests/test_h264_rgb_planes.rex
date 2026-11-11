/* Shared raster exporters also work on decoded H264 RGB24 frames.
 * Synthesized A=255 is documented (H264 RGB24 has no alpha channel). */
numeric digits 30
rgb=''
do i=1 to 256
  rgb=rgb||x2c('FF0010')
end
packet='MHP1'||x2c('00000010000000100000000000000001')||rgb
frame=.MediaRgbFrame~new(packet)
if frame~width<>16 | frame~height<>16 then exit 11
if frame~pixels~length<>768 then exit 12
if frame~channelPlane('R')<>copies('ff'x,256) then exit 13
if frame~channelPlane('G')<>copies('00'x,256) then exit 14
if frame~channelPlane('B')<>copies('10'x,256) then exit 15
if frame~channelPlane('A')<>copies('ff'x,256) then exit 16
paths=frame~saveSplit('out/h264rgb')
frame~savePam('out/h264rgb.rgba.pam')
if stream(paths['A'],'C','QUERY SIZE')<>269 then exit 17
say 'PASS native RGB24 frame shared R/G/B/A exports, opaque alpha synthesized'
exit 0
::requires '../src/MediaH264Frames.cls'