/* Five user-supplied selected/scrubbed webcam JPEGs, non-continuous time.
 * Native ooRexx JPEG -> RGBA -> crop -> area resize -> evolving mask.
 */
numeric digits 30
parse arg root outputDir .
if root='' then root='/mnt/data'
if outputDir='' then outputDir='../outputs'
model=.MediaTemporalDifferenceMask~new(315,150,50,12,16,3)
files=.array~of('1000069592.jpg','1000069593.jpg','1000069594.jpg', -
  '1000069595.jpg','1000069596.jpg')
clocks=.array~of('03:45:21','04:05:09','04:05:41','04:41:17','04:46:43')
do i=1 to files~items
  path=root||'/'||files[i]
  src=.MediaLocalByteSource~new(path)
  frame=.MediaJpegFile~new(src)~decode
  call eq 1536,frame~width,'real JPEG width'
  call eq 709,frame~height,'real JPEG height'
  view=frame~crop(138,0,1260,600)
  small=view~resizeToProcessing(315,150,'AREA')
  added=model~addFrame(small,'2026-11-10T'||clocks[i]||'+11:00')
  say 'READ' files[i] 'webcamSydney='clocks[i] 'processing='small~width'x'small~height
  ignore=src~close
end
scores=model~scoreAll
say 'MODEL' 'frames='model~count 'generation='model~generation 'threshold='model~thresholdPercent||'%'
call eq 5,scores~items,'all five retrospective scores'
model~saveBackground(outputDir||'/sydney_selected_background.pgm')
do i=1 to scores~items
  score=scores[i]
  bright=0;building=0
  do y=0 to 149
    do x=0 to 314
      at=y*315+x+1
      if c2d(substr(score~positiveMask,at,1))>0 then do
        if y<72 then bright=bright+1
        else building=building+1
      end
    end
  end
  say 'SCORE' clocks[i] 'gainPPM='model~sample(i)['GAIN_PPM'] -
      'upperSkyBright='bright 'lowerSceneBright='building
  score~saveMask(outputDir||'/sydney_selected_mask_'||i||'.pgm')
end
say 'PASS: five real native JPEGs scored against rebuilt temporal mask, with first frame rescored'
exit 0
eq: procedure
  use strict arg exp,actual,label
  if exp<>actual then do
    say 'FAIL:'label 'expected='exp 'actual='actual
    exit 1
  end
  return
::requires '../src/MediaLocalByteSource.cls'
::requires '../src/MediaJpegFile.cls'
::requires '../src/MediaTemporalMask.cls'