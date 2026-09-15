say 'CAMERA FFMPEG FRAME DECODE SMOKE START'

paths=.array~new
p1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
p2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
p3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')
if p1 == '' then do
  say 'SKIP CAMERA FFMPEG FRAME DECODE reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA FFMPEG FRAME DECODE SMOKE: OK'
  exit 0
end
paths~append(p1)
if p2 \== '' then paths~append(p2)
if p3 \== '' then paths~append(p3)

count=0
do path over paths
  source=.CameraFFmpegMediaSource~new(path)
  decodeResult=source~decodeVideoFrames
  call assertEqual 'decoded width',640,decodeResult~width
  call assertEqual 'decoded height',360,decodeResult~height
  call assertEqual 'decoded pixel format yuv420p',0,decodeResult~pixelFormat
  call assertEqual 'decoded luma line size',640,decodeResult~lumaLineSize
  call assertEqual 'decoded frame count',900,decodeResult~frameCount
  call assertEqual 'video packet count',900,decodeResult~videoPacketCount
  call assertEqual 'all packet count',1837,decodeResult~packetCount
  call assertEqual 'full decode not limited',0,decodeResult~limited
  call assertTrue 'first luma prefix materialized',decodeResult~firstLumaPrefixHex~length=32
  call assertTrue 'codec version available',decodeResult~avcodecVersion>0
  call assertTrue 'util version available',decodeResult~avutilVersion>0
  say '  decoded:' path decodeResult~compactText
  ignored=source~close

  limitedSource=.CameraFFmpegMediaSource~new(path)
  limited=limitedSource~decodeVideoFrames(5)
  call assertEqual 'limited five frames',5,limited~frameCount
  call assertEqual 'limited flag',1,limited~limited
  call assertTrue 'limited consumes some video packets',limited~videoPacketCount>=5
  ignored=limitedSource~close
  count=count+1
end

call assertEqual 'three fixtures decoded',3,count

missing=.CameraFFmpegMediaSource~new('/definitely/not/a/camera/file.mp4')
bad=missing~decodeVideoFrames
call assertEqual 'missing no frames',0,bad~frameCount
call assertTrue 'missing status negative',bad~endStatus<0
call assertEqual 'missing unopened',0,missing~opened
ignored=missing~close

say 'CAMERA FFMPEG FRAME DECODE SMOKE: OK'
exit 0

assertEqual: procedure
  use arg label,expected,actual
  if expected==actual then return .true
  say 'ASSERT FAILED:' label
  say ' expected:' expected
  say ' actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label,actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  exit 1

::requires 'CameraFFmpegMediaSource.cls'
