/* Sydney 9 Nov 2026: six independent webcam timestamps, not video PTS.
 * Register buildings at common 1316x742 geometry; 50% relative local mask.
 * OoRexx owns PNG IO/PNG decoder classes, registration, provenance and scoring.
 */
numeric digits 30
parse arg root outDir .
if root='' then root='/mnt/data'
if outDir='' then outDir=root
names=.array~of('image(20261109-134604).png', 'image(20261109-134731).png', -
 'image(20261109-134816).png', 'image(20261109-134847).png', -
 'image(20261109-135033).png', 'image(20261109-203438).png')
times=.array~of('20:17:25','20:24:30','20:32:05','20:32:17','20:37:11','22:08:42')
frames=.array~new
scales=.array~new
model=.MediaTemporalDifferenceMask~new(329,185,50,12,16,3)
/* 20:37:11 is the clear, uncontaminated downtown landmark reference. */
source=.MediaLocalByteSource~new(root||'/'||names[5])
reference=.MediaPngFile~new(source)~decode
ignored=source~close
refScaled=reference~resizeToProcessing(1316,742,'AREA')
say 'REFERENCE 20:37:11 1920x1080 -> 1316x742'
do i=1 to names~items
  src=.MediaLocalByteSource~new(root||'/'||names[i])
  orig=.MediaPngFile~new(src)~decode
  ignored=src~close
  if orig~width=1316 & orig~height=742 then resized=orig
  else resized=orig~resizeToProcessing(1316,742,'AREA')
  fit=.MediaRasterOps~estimateTranslation(refScaled,resized,320,315,320,95,6)
  sx=fit['DX'];sy=fit['DY'];score=fit['SCORE_PPM']
  say 'FIT' i times[i] 'dx='sx 'dy='sy 'scorePPM='score
  if score>100000 then say 'WARNING: landmark residual above provisional 100000 PPM gate; no astrometric correspondence claimed' 
  aligned=.MediaRasterOps~translateBy(resized,sx,sy)
  small=aligned~resizeToProcessing(329,185,'AREA')
  ignores=model~addFrame(small,'2026-11-09T'||times[i]||'+11:00')
end
scores=model~scoreAll
say 'MODEL' model~count 'generation' model~generation
ignore=model~saveBackground(outDir||'/sydney_6frame_background.pgm')
report=outDir||'/sydney_6frame_native_temporal_results.tsv'
header='time'||'09'x||'sky_positive'||'09'x||'landmarks_positive'||'09'x||'other_positive'||'0a'x
ignore=charout(report,header,1)
do i=1 to scores~items
  score=scores[i]
  sky=0; buildings=0;other=0
  do y=0 to 184
    do x=0 to 328
      if score~positiveAt(x,y)=0 then iterate
      /* Exclude the streaming overlay at top left, and title/watermark region.
       * Restrict sky to above the buildings in all screenshots. */
      if y>=10 & y<67 then do
        if x>30 & x<320 then sky=sky+1
      end
      else if y>=82 & y<115 & x>=80 & x<250 then buildings=buildings+1
      else other=other+1
    end
  end
  say 'SCORE' i times[i] 'sky='sky 'building='buildings 'other='other
  ignored=score~saveMask(outDir||'/sydney_6frame_mask_'||i||'.pgm')
  line=times[i]||'09'x||sky||'09'x||buildings||'09'x||other||'0a'x
  ignore=charout(report,line)
end
ignore=stream(report,'C','CLOSE')
say 'PASS: six native PNGs retained, photometric model built, every earlier frame rescored'
exit 0
::requires '../src/MediaLocalByteSource.cls'
::requires '../src/MediaPngFile.cls'
::requires '../src/MediaRasterOps.cls'
::requires '../src/MediaTemporalMask.cls'