/* Only the four independently validated, identical-geometry screenshots.
 * The 20:17 and 22:08 samples are excluded from astronomical model.
 * Moonsault full-resolution second-pass is morphology only, not catalog.
 */
numeric digits 30
parse arg root reportFile .
if root='' then root='/mnt/data'
if reportFile='' then reportFile='/mnt/data/media_raster_dev7/outputs/sydney_four_qualified_candidates.tsv'
names=.array~of('image(20261109-134731).png', -
 'image(20261109-134816).png','image(20261109-134847).png', -
 'image(20261109-135033).png')
times=.array~of('20:24:30','20:32:05','20:32:17','20:37:11')
f=.MediaLocalByteSource~new(root||'/image(20261109-135033).png')
ref=.MediaPngFile~new(f)~decode
ignore=f~close
refCommon=ref~resizeToProcessing(1316,742,'AREA')
model=.MediaTemporalDifferenceMask~new(329,185,50,12,16,3)
full=.array~new
do i=1 to names~items
  f=.MediaLocalByteSource~new(root||'/'||names[i])
  frame=.MediaPngFile~new(f)~decode
  ignore=f~close
  common=frame~resizeToProcessing(1316,742,'AREA')
  if i<4 then do
    fit=.MediaRasterOps~estimateSimilarityValidated(refCommon,common, -
       320,315,300,95,815,310,240,95,6,40,5,125000,125000,2500)
    if fit['QUALIFIED']<>1 | fit['SCALE_PPM']<>1000000 | -
       fit['DX_MILLI']<>0 | fit['DY_MILLI']<>0 then do
      say 'FAIL: candidate cohort lacks identical qualified geometry' times[i]
      exit 1
    end
  end
  full~append(common)
  small=common~resizeToProcessing(329,185,'AREA')
  ignore=model~addFrame(small,'2026-11-09T'||times[i]||'+11:00')
end
/* The isolated bright compact transient at (218,178) in 20:32:17
 * is absent 12 seconds earlier. It is the aircraft-streak region and MUST
 * be rejected even though a single-frame point-shape test accepts it. */
short=.MoonsaultFullResolutionRevisit~corroborateShortInterval(full[2],full[3],218,178,12,2)
say 'AIRCRAFT_STREAK_EVIDENCE before='short['BEFORE_CONTRAST'] -
  'after='short['AFTER_CONTRAST'] 'status='short['STATUS']
if short['BEFORE_CONTRAST']>=12 | short['AFTER_CONTRAST']<80 | -
   short['STATUS']<>'TRANSIENT_REJECTED' then do
  say 'FAIL: aircraft streak masquerades as persistent point';exit 1
end
scores=model~scoreAll
line='time'||'09'x||'coarse_positive_sky'||'09'x|| -
  'clusters'||'09'x||'point_like'||'09'x||'diffuse_other'||'0a'x
ignore=charout(reportFile,line,1)
do i=1 to scores~items
  score=scores[i]
  mask=score~positiveMask
  positives=0
  do y=10 to 66
    do x=31 to 319
      if c2d(substr(mask,y*329+x+1,1))>0 then positives+=1
    end
  end
  result=.MoonsaultFullResolutionRevisit~examine(full[i],mask,329,185, -
     31,10,319,66,512,20,12)
  points=0
  do candidate over result
    if candidate['STATUS']='POINT_LIKE_UNIDENTIFIED' then do
      points+=1
      say '  POINTLIKE_UNIDENTIFIED' candidate['FRAME_X'] candidate['FRAME_Y'] 'contrast='candidate['CONTRAST']
    end
  end
  other=result~items-points
  say 'SKY' times[i] 'changed_pixels='positives 'clusters='result~items -
    'pointlike='points 'other='other
  line=times[i]||'09'x||positives||'09'x||result~items||'09'x|| -
    points||'09'x||other||'0a'x
  ignore=charout(reportFile,line)
end
ignore=stream(reportFile,'C','CLOSE')
say 'PASS: real four-image registered cohort, 50% mask and original-resolution point morphology'
exit 0
::requires '../src/MoonsaultFullResolutionRevisit.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaLocalByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaPngFile.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaTemporalMask.cls'