/* Native ooRexx r13196 similarity registration:
 * 2.5 percent camera zoom, ~2-pixel drift, 20 percent illumination increase.
 * Independent nonoverlapping building ROIs, warp validity, and retrospective
 * moving point through four time samples.
 */
numeric digits 30
w=160;h=100
raw=''
do y=0 to h-1
  do x=0 to w-1
    val=24
    if y>=23+(x//19) then val=74+(x*37+y*17+(x*x)//7)//105
    if y>=53+(x//9) then val=108+(x*19+y*43+(x*x)//3)//103
    if y>=65 & (x//8)=0 then val=215
    if y>=25 & x//17=0 then val=195
    raw=raw||d2c(val,1)||d2c(val,1)||d2c(val,1)
  end
end
ref=.MediaRasterImage~new(raw,w,h,3,'LANDMARK_REFERENCE')
/* Inverse warp: target enlarged 1.025 about centre then offset - see method contract. */
inv=.directory~new
inv['SCALE_PPM']=975610
inv['DX_MILLI']=-1951
inv['DY_MILLI']=976
inv['QUALIFIED']=0
target=.MediaRasterOps~warpSimilarity(ref,inv,.true)
brightness=''
b=target~pixels
do i=1 to b~length
  v=min(255,trunc(c2d(substr(b,i,1))*1.2))
  brightness=brightness||d2c(v,1)
end
brighter=.MediaRasterImage~new(brightness,w,h,3,'ZOOM_AND_20_PERCENT_BRIGHTER')
fit=.MediaRasterOps~estimateSimilarity(ref,brighter,9,28,72,58,5,40,5)
say 'FIT dxMilli='fit['DX_MILLI'] 'dyMilli='fit['DY_MILLI'] -
    'scalePPM='fit['SCALE_PPM'] 'scorePPM='fit['SCORE_PPM'] -
    'next='fit['NEXT_BEST_PPM'] 'samples='fit['LANDMARK_SAMPLES']
ind=.MediaRasterOps~scoreSimilarity(ref,brighter,fit,93,30,60,58)
say 'HELDOUT scorePPM='ind['SCORE_PPM'] 'samples='ind['LANDMARK_SAMPLES']
if abs(fit['DX_MILLI']-2000)>1600 | abs(fit['DY_MILLI']+1000)>1600 | -
    abs(fit['SCALE_PPM']-1025000)>12000 then do
  say 'FAIL: zoom/shift fit outside conservative tolerance';exit 1
end
both=.MediaRasterOps~estimateSimilarityValidated(ref,brighter,9,28,72,58, -
     93,30,60,58,5,40,5,250000,250000,0)
if both['QUALIFIED']<>1 then do
  say 'FAIL: two clean independent synthetic city regions declined'
  exit 1
end
aligned=.MediaRasterOps~warpSimilarity(brighter,both)
valid=.MediaRasterOps~similarityValidity(w,h,both)
/* A separate zoom-out/translation must invalidate the missing border. */
outFit=.directory~new
outFit['DX_MILLI']=5000
outFit['DY_MILLI']=0
outFit['SCALE_PPM']=975000
outFit['QUALIFIED']=1
edgeValidity=.MediaRasterOps~similarityValidity(w,h,outFit)
if c2d(substr(edgeValidity,1,1))<>0 then do
  say 'FAIL: out-of-bounds source falsely valid';exit 1
end
if c2d(substr(valid,50*w+80+1,1))<>255 then do
  say 'FAIL: central registered sample not valid';exit 1
end
if abs(aligned~pixelAt(75,56)[1]-trunc(ref~pixelAt(75,56)[1]*1.2))>32 then do
  say 'FAIL: no successful pixel return from warper';exit 1
end
history=.MediaTemporalDifferenceMask~new(w,h,50,12,16,3)
ignored=history~addFrame(ref,'baseline')
ignored=history~addSimilarityFrame(brighter,'zoomed',both)
if history~sample(2)['SCALE_PPM']<>both['SCALE_PPM'] then do
  say 'FAIL: similarity provenance not retained';exit 1
end
if history~sample(2)['HELDOUT_PPM']<>both['HELDOUT_PPM'] then do
  say 'FAIL: independent validation provenance not retained';exit 1
end
if history~scoreAt(2)~maskAt(0,0)<>0 then do
  say 'FAIL: invalid warp corner created false detection';exit 1
end
say 'PASS: native independent similarity ROI, subpixel warp, validity and time-model provenance'
exit 0
::requires '../src/MediaRasterOps.cls'
::requires '../src/MediaTemporalMask.cls'