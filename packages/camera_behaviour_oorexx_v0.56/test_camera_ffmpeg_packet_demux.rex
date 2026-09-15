say 'CAMERA FFMPEG PACKET DEMUX SMOKE START'

paths=.array~new
p1=value('CAMERA_MEDIA_FIXTURE_1',,'ENVIRONMENT')
p2=value('CAMERA_MEDIA_FIXTURE_2',,'ENVIRONMENT')
p3=value('CAMERA_MEDIA_FIXTURE_3',,'ENVIRONMENT')

if p1 == '' then do
  say 'SKIP CAMERA FFMPEG PACKET DEMUX reason=CAMERA_MEDIA_FIXTURE_1 not set'
  say 'CAMERA FFMPEG PACKET DEMUX SMOKE: OK'
  exit 0
end

paths~append(p1)
if p2 \== '' then paths~append(p2)
if p3 \== '' then paths~append(p3)

count=0
do path over paths
  /* Full demux. */
  source=.CameraFFmpegMediaSource~new(path)
  inspection=source~open
  call assertTrue 'source opened',source~opened
  packets=source~demuxPackets
  call assertTrue 'packet count substantial',packets~packetCount > 1000
  call assertEqual 'full read not limited',0,packets~limited
  call assertTrue 'EOF/error terminal status negative',packets~endStatus < 0
  call assertTrue 'libavcodec version nonzero',packets~avcodecVersion > 0
  say '  demux:' path packets~compactText
  ignored=source~close

  /* Limited cursor-style read must stop exactly at the requested packet count. */
  limited=.CameraFFmpegMediaSource~new(path)
  ignoredInspection=limited~open
  first25=limited~demuxPackets(25)
  call assertEqual 'limited packet count',25,first25~packetCount
  call assertEqual 'limited flag',1,first25~limited
  ignored=limited~close
  count=count+1
end

call assertTrue 'at least one fixture demuxed',count>=1

/* Missing source still fails closed before packet allocation. */
missing=.CameraFFmpegMediaSource~new('/definitely/not/a/camera/file.mp4')
bad=missing~demuxPackets
call assertEqual 'missing packet count',0,bad~packetCount
call assertTrue 'missing end/open status negative',bad~endStatus<0
call assertEqual 'missing remains unopened',0,missing~opened
ignored=missing~close

say 'CAMERA FFMPEG PACKET DEMUX SMOKE: OK'
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
