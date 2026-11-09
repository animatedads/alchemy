/* Native ooRexx six screenshot registration: independent facades/bridge.
 * Webcam clock is separate from the screenshot's saved-file time.
 * No celestial fix is issued when heldout evidence is weak.
 */
numeric digits 30
parse arg root reportPath .
if root='' then root='/mnt/data'
if reportPath='' then reportPath=root||'/sydney_six_similarity_results.tsv'
names=.array~of('image(20261109-134604).png', -
 'image(20261109-134731).png','image(20261109-134816).png', -
 'image(20261109-134847).png','image(20261109-135033).png', -
 'image(20261109-203438).png')
times=.array~of('20:17:25','20:24:30','20:32:05','20:32:17','20:37:11','22:08:42')
f=.MediaLocalByteSource~new(root||'/'||names[5])
ref=.MediaPngFile~new(f)~decode
ignore=f~close
refCommon=ref~resizeToProcessing(1316,742,'AREA')
header='time'||'09'x||'scale_ppm'||'09'x||'dx_milli'||'09'x||'dy_milli'||'09'x|| -
 'fit_ppm'||'09'x||'heldout_ppm'||'09'x||'margin_ppm'||'09'x||'qualified'||'0a'x
ignored=charout(reportPath,header,1)
qualified=0
/* Bridge ROI deliberately disjoint from downtown ROI. */
do i=1 to 6
  file=.MediaLocalByteSource~new(root||'/'||names[i])
  frame=.MediaPngFile~new(file)~decode
  ignore=file~close
  if frame~width=1316 & frame~height=742 then compare=frame
  else compare=frame~resizeToProcessing(1316,742,'AREA')
  if i=5 then do
    /* Same exact image: the identity reference needs no interpolation. */
    fit=.directory~new
    fit['SCALE_PPM']=1000000;fit['DX_MILLI']=0;fit['DY_MILLI']=0
    fit['SCORE_PPM']=0;fit['HELDOUT_PPM']=0
    fit['NEXT_BEST_PPM']=999999;fit['QUALIFIED']=1
  end
  else fit=.MediaRasterOps~estimateSimilarityValidated(refCommon,compare, -
    320,315,300,95,815,310,240,95,6,40,5,125000,125000,2500)
  margin=fit['NEXT_BEST_PPM']-fit['SCORE_PPM']
  line=times[i]||'09'x||fit['SCALE_PPM']||'09'x||fit['DX_MILLI']|| -
    '09'x||fit['DY_MILLI']||'09'x||fit['SCORE_PPM']||'09'x|| -
    fit['HELDOUT_PPM']||'09'x||margin||'09'x||fit['QUALIFIED']||'0a'x
  ignore=charout(reportPath,line)
  say 'REGISTER' times[i] 'scale='fit['SCALE_PPM'] -
    'shift_milli='fit['DX_MILLI'] fit['DY_MILLI'] -
    'downtown='fit['SCORE_PPM'] 'bridge='fit['HELDOUT_PPM'] -
    'margin='margin 'qualified='fit['QUALIFIED']
  qualified+=fit['QUALIFIED']
end
ignore=stream(reportPath,'C','CLOSE')
say 'QUALIFIED_IMAGES' qualified 'OF 6 (reference included)'
say 'PASS: independently checked per-frame scale fits recorded; failing frames not promoted'
exit 0
::requires '../src/MediaLocalByteSource.cls'
::requires '../src/MediaPngFile.cls'
::requires '../src/MediaRasterOps.cls'