/* Regression: existing PNG RGBA object supports dev6 crop/resize/difference. */
parse arg sourcePath .
if sourcePath='' then sourcePath='/mnt/data/image(20261109-134604).png'
source=.MediaLocalByteSource~new(sourcePath)
frame=.MediaPngFile~new(source)~decode
c=frame~crop(200,50,800,500)
s=c~resizeToProcessing(200,125,'AREA')
if s~width<>200 | s~height<>125 | s~channels<>4 then do
  say 'FAIL: PNG RGBA transform dimensions'
  exit 1
end
d=s~subtractFrame(s,.true)
if d~deltaAt(100,50,4)<>0 | d~deltaAt(100,50,1)<>0 then do
  say 'FAIL: PNG RGBA self-difference'
  exit 1
end
say 'PASS: real PNG RGBA crop/AREA resize/signed RGBA subtraction (alpha preserved)'
source~close
exit 0
::requires '../src/MediaLocalByteSource.cls'
::requires '../src/MediaPngFile.cls'