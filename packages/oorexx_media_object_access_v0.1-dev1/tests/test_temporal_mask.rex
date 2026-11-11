/* Native ooRexx 5.3 scientific raster geometry and temporal subtraction.
 * Four exposures, one moving star per exposure, background 20% brighter
 * in later two images. Rebuilding must expose an earlier missed star.
 */
numeric digits 30
w=12;h=8
f1=makeExposure(w,h,2,0)
f2=makeExposure(w,h,4,0)
f3=makeExposure(w,h,6,1)
f4=makeExposure(w,h,8,1)

crop=f1~crop(1,1,6,4)
call eq 6,crop~width,'crop width'
call eq 4,crop~height,'crop height'
call eq 230,crop~pixelAt(1,0)[1],'crop identifies original star pixel'
small=f1~resizeToProcessing(6,4,'AREA')
call eq 6,small~width,'area resize width'
call eq 4,small~height,'area resize height'
call eq 120,small~pixelAt(0,3)[1],'AREA preserves uniform building average'

signed=f1~subtractFrame(f2)
call eq 200,signed~deltaAt(2,1,1),'star appeared in first frame signed-positive'
call eq -200,signed~deltaAt(4,1,1),'star missing from first frame signed-negative'
call eq 200,c2d(substr(signed~magnitude,1*w+2+1,1)),'absolute difference magnitude'

mono=x2c('0A141E28')
layer=.MediaRasterLayer~new(mono,2,2,1)
ld=f1~subtractLayer(layer,0,0,'R')
call eq 20,ld~deltaAt(0,0,1),'red-only layer subtraction'
call eq 10,ld~deltaAt(1,0,1),'red-only offset pixel'
call eq 0,ld~deltaAt(2,0,1),'layer difference outside overlap is zero'

model=.MediaTemporalDifferenceMask~new(w,h,50,12,16,3)
call eq 1,model~addFrame(f1,'t0'), 'first image'
call eq 2,model~addFrame(f2,'t300'), 'five-minute image'
firstPass=model~scoreAt(1)
call eq 255,firstPass~positiveAt(2,1),'first-star visible against initial 2-frame mask'
gen1=firstPass~modelGeneration
call eq 3,model~addFrame(f3,'t1200'), 'third brighter image'
call eq 4,model~addFrame(f4,'t1500'), 'fourth brighter image'
all=model~scoreAll
call eq 4,all~items,'retroactively scored all images'
if all[1]~modelGeneration<=gen1 then call fail 'retroactive score did not rebuild'
call eq 255,all[1]~positiveAt(2,1),'rescore finds star in first image'
call eq 255,all[2]~positiveAt(4,1),'rescore finds star in second image'
call eq 255,all[3]~positiveAt(6,1),'rescore finds star in third image'
call eq 255,all[4]~positiveAt(8,1),'rescore finds star in fourth image'
call eq 0,all[1]~maskAt(2,5),'building is suppressed in reference frame'
call eq 0,all[3]~maskAt(2,5),'20 percent daylight change suppressed'
call eq 0,all[4]~maskAt(9,6),'late building still suppressed'
if model~sample(3)['GAIN_PPM']<810000 | model~sample(3)['GAIN_PPM']>850000 then -
   call fail 'failed to normalise +20 percent illumination shift'
call eq 30,c2d(substr(model~backgroundPlane,1*w+2+1,1)),'star not burned into background'
call eq 60,c2d(substr(model~tolerancePlane,5*w+2+1,1)),'50 percent local building threshold'
call eq 15,c2d(substr(model~tolerancePlane,1*w+2+1,1)),'50 percent of sky local 30 with round ceiling'

/* Registration is explicit; no silent camera motion compensation. */
shifted=.MediaRasterOps~translateBy(f4,1,0)
restored=.MediaRasterOps~translateBy(shifted,-1,0)
call eq 240,restored~pixelAt(8,1)[1],'one-pixel geometric registration before temporal fit'
call eq 0,restored~pixelAt(11,1)[1],'registration border explicitly invalid/zero'
/* Pixel left outside the translated source is invalid, not false motion. */
shiftModel=.MediaTemporalDifferenceMask~new(w,h,50,12,16,3)
ignore=shiftModel~addFrame(f1,'shift-reference')
shiftedSecond=.MediaRasterOps~translateBy(f2,1,0)
ignore=shiftModel~addFrame(shiftedSecond,'shifted-camera',-1,0)
shiftScore=shiftModel~scoreAt(2)
call eq 0,shiftScore~maskAt(w-1,1),'registration invalid right edge suppressed'
call eq 255,shiftScore~positiveAt(4,1),'star preserved after manual translation correction'
say 'PASS: native crop, AREA resize, signed subtractFrame, subtractLayer, RGB delta magnitude'
say 'PASS: four-frame absolute 50 percent mask, +20 percent illumination normalisation'
say 'PASS: building suppression and retrospective detection of original-frame star'
say 'PASS: explicit translational registration; native model generation='model~generation
exit 0
makeExposure: procedure
  use strict arg w,h,starX,bright
  result=''
  do y=0 to h-1
    do x=0 to w-1
      val=30
      if y>=4 then val=120
      if bright=1 then val=val*12/10
      if y=1 & x=starX then do
        val=230
        if bright=1 then val=240
      end
      result=result||d2c(val,1)||d2c(val,1)||d2c(val,1)
    end
  end
  return .MediaRasterImage~new(result,w,h,3,'SYNTHETIC_EXPOSURE')
eq: procedure
  use strict arg expected,got,label
  if expected<>got then call fail label||': expected='expected||' got='got
  return
fail: procedure
  use strict arg reason
  say 'FAIL:'reason
  exit 1
::requires '../src/MediaTemporalMask.cls'