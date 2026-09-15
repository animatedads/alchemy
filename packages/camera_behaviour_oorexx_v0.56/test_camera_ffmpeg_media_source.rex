say 'CAMERA FFMPEG MEDIA SOURCE SMOKE START'

paths=.array~new
p1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
p2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
p3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')
if p1 == '' then do
  say 'SKIP CAMERA FFMPEG MEDIA SOURCE reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA FFMPEG MEDIA SOURCE SMOKE: OK'
  exit 0
end
paths~append(p1)
if p2 \== '' then paths~append(p2)
if p3 \== '' then paths~append(p3)

count=0
do path over paths
  source=.CameraFFmpegMediaSource~new(path)
  inspection=source~open
  call assertEqual 'source opened',1,source~opened
  call assertEqual 'stream info loaded',1,source~streamInfoLoaded
  call assertEqual 'open rc',0,source~lastOpenStatus
  call assertTrue 'stream info rc nonnegative',source~lastStreamInfoStatus>=0
  call assertTrue 'FFmpeg version nonzero',inspection~avformatVersion>0
  call assertTrue 'video stream found',inspection~hasVideo
  call assertTrue 'video stream index nonnegative',inspection~videoStreamIndex>=0
  call assertTrue 'compact inspection populated',inspection~compactText~pos('CFI1|V=')=1
  say '  direct:' path inspection~compactText
  ignored=source~close
  call assertEqual 'source closed',0,source~opened
  count=count+1
end

call assertTrue 'at least one fixture tested',count>=1

/* Invalid media must fail closed without fabricating stream identity. */
missing=.CameraFFmpegMediaSource~new('/definitely/not/a/camera/file.mp4')
missingInspection=missing~open
call assertEqual 'missing source not opened',0,missing~opened
call assertTrue 'missing source negative open status',missing~lastOpenStatus<0
call assertEqual 'missing source no video',0,missingInspection~hasVideo
ignored=missing~close
say 'CAMERA FFMPEG MEDIA SOURCE SMOKE: OK'
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
