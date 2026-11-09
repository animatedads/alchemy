/* Test media operation wrappers with real resident JPEG: sample points,
 * signed difference against same frame, and independent RGBA alpha. */
numeric digits 30
parse arg root .
if root='' then root='/mnt/data'
src=.MediaLocalByteSource~new(root||'/1000069595.jpg')
frame=.MediaJpegFile~new(src)~decode
call eq 1536,frame~width,'jpeg width'
small=frame~crop(138,0,1260,600)~resizeToProcessing(315,150,'AREA')
call eq 4,small~channels,'JPEG preserves explicit RGBA channels'
raw=small~subtractFrame(small,.true)
call eq 0,raw~deltaAt(150,75,4),'RGBA alpha subtract zero'
call eq 0,raw~deltaAt(150,75,1),'RGB subtract same frame zero'
call eq 255,small~pixelAt(150,75)[4],'JPEG alpha is opaque'
call eq 0,c2d(substr(raw~magnitude,12345,1)),'real JPEG absolute difference zero'
ignore=src~close
say 'PASS: 1536x709 JPEG crop, AREA resize, signed RGBA self-subtraction including opaque alpha'
exit 0
eq: procedure
  use strict arg exp,got,label
  if exp<>got then do
    say 'FAIL:'label 'expected='exp 'got='got
    exit 1
  end
  return
::requires '../src/MediaLocalByteSource.cls'
::requires '../src/MediaJpegFile.cls'
::requires '../src/MediaTemporalMask.cls'