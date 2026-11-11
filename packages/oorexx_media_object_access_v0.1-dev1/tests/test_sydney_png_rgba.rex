/* Real 1920x1080 Sydney screenshot PNG qualification; ooRexx 5.3. */
numeric digits 30
parse arg root output
if root='' then root='/mnt/data'
if output='' then output='out'
names=.array~of('image(20261109-134604).png', -
  'image(20261109-134731).png','image(20261109-134816).png', -
  'image(20261109-134847).png','image(20261109-135033).png')
do i=1 to names~items
  source=.MediaLocalByteSource~new(root'/'names[i])
  format=.MediaFileProbe~detect(source)
  if format<>'PNG' then call fail 'sniffer failed on 'names[i]
  file=.MediaFileProbe~open(source)
  frame=file~decode
  if frame~width<>1920 | frame~height<>1080 | -
     frame~pixels~length<>8294400 | frame~pixelFormat<>'RGBA32' then -
    call fail 'unexpected PNG frame dimensions/pixel bytes 'names[i]
  center=frame~pixelAt(960,540)
  say 'PASS 'names[i]' 1920x1080 RGBA32 center' center[1] center[2] center[3] center[4]
  if i=4 then do
    prefix=output'/sydney_203217'
    paths=frame~saveSplit(prefix)
    frame~savePpm(prefix||'.rgb.ppm')
    frame~savePam(prefix||'.rgba.pam')
    do c over .array~of('R','G','B','A')
      say 'PLANE 'c 'bytes='stream(paths[c],'C','QUERY SIZE') 'path='paths[c]
    end
    say 'PPM bytes='stream(prefix||'.rgb.ppm','C','QUERY SIZE')
    say 'PAM bytes='stream(prefix||'.rgba.pam','C','QUERY SIZE')
  end
  source~close
end
say 'PASS five native Sydney 1080p PNGs and one R/G/B/A export'
exit 0
fail: procedure
  use strict arg message
  say 'FAIL' message
  exit 31
::requires '../src/MediaByteSource.cls'
::requires '../src/MediaLocalByteSource.cls'
::requires '../src/MediaPngFile.cls'
::requires '../src/MediaFileProbe.cls'
/* dispatch file class already provided by standalone probe; existing MP4
   MediaFile is optional for PNG-only testing. */