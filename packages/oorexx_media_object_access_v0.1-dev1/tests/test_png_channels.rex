/* Native ooRexx PNG + individual R/G/B/A PGM + RGB PPM + RGBA PAM regression. */
numeric digits 30
parse arg fixture output
if fixture='' then do
  fixture='out/rgba2x2.png'
  code=strip(charin('rgba2x2.hex',1,20000))
  ignored=stream('rgba2x2.hex','C','CLOSE')
  if code='' then exit 42
  ignored=charout(fixture,x2c(code),1)
  ignored=stream(fixture,'C','CLOSE')
end
if output='' then output='out/fixture'
source=.MediaLocalByteSource~new(fixture)
file=.MediaPngFile~new(source)
call check file~width=2 & file~height=2, 'IHDR dimensions'
frame=file~decode
source~close
call check frame~pixelFormat='RGBA32', 'pixel format RGBA'
call check frame~pixels~length=16, 'decoded 16-byte RGBA payload'
expected=x2c('FF0000FF00FF00800000FF00FA7D1E40')
call check frame~pixels==expected, 'exact 4 RGBA pixels including transparent blue'
r=frame~channelPlane('R')
g=frame~channelPlane('G')
b=frame~channelPlane('B')
a=frame~channelPlane('A')
call check r==x2c('FF0000FA'), 'R split'
call check g==x2c('00FF007D'), 'G split'
call check b==x2c('0000FF1E'), 'B split'
call check a==x2c('FF800040'), 'A split preserved'
aPixel=frame~pixelAt(1,0)
call check aPixel[4]=128, 'half-transparent alpha sample'
aPixel=frame~pixelAt(0,1)
call check aPixel[4]=0, 'fully transparent sample'
aPixel=frame~pixelAt(1,1)
call check aPixel[4]=64, 'quarter-transparent sample'
paths=frame~saveSplit(output)
call check paths['A']=output'.a.pgm','alpha output path'
do channel over .array~of('R','G','B','A')
  path=paths[channel]
  content=charin(path,1,100)
  ignored=stream(path,'C','CLOSE')
  call check substr(content,1,2)='P5',channel' PGM magic'
  call check substr(content,4,3)='2 2',channel' PGM size'
end
ppm=output||'.rgb.ppm'
pam=output||'.rgba.pam'
frame~savePpm(ppm)
frame~savePam(pam)
raw=charin(ppm,1,100)
ignored=stream(ppm,'C','CLOSE')
call check substr(raw,1,2)='P6', 'PPM magic'
raw=charin(pam,1,200)
ignored=stream(pam,'C','CLOSE')
call check substr(raw,1,2)='P7', 'PAM magic'
call check pos('TUPLTYPE RGB_ALPHA',raw)>0,'PAM alpha declaration'
say 'PASS PNG native RGBA exact pixels, independent R/G/B/A PGM, RGB PPM, RGBA PAM'
exit 0
check: procedure
 use strict arg good,message
 if \good then do
   say 'FAIL' message
   exit 21
 end
 return
::requires '../src/MediaByteSource.cls'
::requires '../src/MediaLocalByteSource.cls'
::requires '../src/MediaPngFile.cls'