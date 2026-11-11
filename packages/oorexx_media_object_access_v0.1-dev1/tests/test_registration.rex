/* Synthetic multi-edge skyline, +1 pixel source shift, global light +20%.
 * A texture-free sky MUST not produce a confident camera registration.
 */
numeric digits 30
w=80;h=48
raw=''
do y=0 to h-1
  do x=0 to w-1
    k=20
    if y>=12+(x//13) then k=95+(x*17+y*11)//93
    if y>=28+(x//7) then k=140+(x*19+y*31)//91
    raw=raw||d2c(k,1)||d2c(k,1)||d2c(k,1)
  end
end
baseline=.MediaRasterImage~new(raw,w,h,3)
shifted=.MediaRasterOps~translateBy(baseline,1,0)
fit=.MediaRasterOps~estimateTranslation(baseline,shifted,3,15,72,30,3)
if fit['DX']<>-1 | fit['DY']<>0 then do
  say 'FAIL: registration returned' fit['DX'] fit['DY'] fit['SCORE_PPM']
  exit 1
end
aligned=.MediaRasterOps~translateBy(shifted,fit['DX'],fit['DY'])
if aligned~pixelAt(30,33)[1]<>baseline~pixelAt(30,33)[1] then do
  say 'FAIL: registered landmark mismatch'
  exit 1
end
/* Moving viewpoint plus 20% illumination shift: landmark registration
 * should still recover translation on suitably textured reference. */
brightPixels=''
old=shifted~pixels
do i=1 to old~length
  q=min(255,trunc(c2d(substr(old,i,1))*1.2))
  brightPixels=brightPixels||d2c(q,1)
end
brightShifted=.MediaRasterImage~new(brightPixels,w,h,3)
fit2=.MediaRasterOps~estimateTranslation(baseline,brightShifted,3,15,72,30,3)
if fit2['DX']<>-1 | fit2['DY']<>0 then do
  say 'FAIL: photometric landmark registration did not preserve geometric shift'
  exit 1
end
mask=.MediaTemporalDifferenceMask~new(w,h,50,12,16,3)
ignored=mask~addFrame(baseline,'baseline')
reg=mask~addRegisteredFrame(brightShifted,'shifted-and-brighter',baseline,3,15,72,30,3)
if reg['DX']<>-1 then do
  say 'FAIL: automatically registered sample did not apply expected dx'
  exit 1
end
if mask~sample(2)['GAIN_PPM']<810000 | mask~sample(2)['GAIN_PPM']>850000 then do
  say 'FAIL: photometric gain not recovered after geometric registration'
  exit 1
end
scores=mask~scoreAll
if scores[2]~maskAt(w-1,10)<>0 then do
  say 'FAIL: translated invalid border falsely detected'
  exit 1
end
say 'PASS: native landmark registration dx='fit['DX'] 'dy='fit['DY'] -
  'scorePPM='fit['SCORE_PPM'] 'samples='fit['LANDMARK_SAMPLES']
exit 0
::requires '../src/MediaRasterOps.cls'
::requires '../src/MediaTemporalMask.cls'