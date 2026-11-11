/* Fail-closed deliberately unqualified synthetic fit. */
numeric digits 30
raw=copies(x2c('808080'),80*50)
img=.MediaRasterImage~new(raw,80,50,3)
fit=.directory~new
fit['QUALIFIED']=0;fit['SCALE_PPM']=1005000;fit['DX_MILLI']=0;fit['DY_MILLI']=0
signal on syntax name expected
ignore=.MediaRasterOps~warpSimilarity(img,fit)
say 'FAIL: unqualified warp applied';exit 1
expected:
 say 'PASS: unqualified similarity fit is refused'
 exit 0
::requires '../src/MediaRasterOps.cls'