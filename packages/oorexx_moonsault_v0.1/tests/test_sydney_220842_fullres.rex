/* Revisit selected sky pixels in the actual PNG at native 1316x742.
 * Coarse input was produced by native six-frame dev6 temporal model.
 * These results are morphology candidates, NOT identified stars.
 */
numeric digits 30
parse arg root maskFile reportFile .
if root='' then root='/mnt/data'
if maskFile='' then maskFile=root||'/sydney_6frame_mask_6.pgm'
if reportFile='' then reportFile=root||'/sydney_220842_fullres_candidates.tsv'
f=.MediaLocalByteSource~new(root||'/image(20261109-203438).png')
img=.MediaPngFile~new(f)~decode
ignore=f~close
header='P5'||'0a'x||'329 185'||'0a'x||'255'||'0a'x
bytes=charin(maskFile,1,60880)
ignore=stream(maskFile,'C','CLOSE')
if substr(bytes,1,header~length)<>header then do
  say 'FAIL: unexpected grayscale temporal evidence header';exit 1
end
mask=substr(bytes,header~length+1)
if mask~length<>329*185 then do
  say 'FAIL: incomplete reference difference mask';exit 1
end
spots=.MoonsaultFullResolutionRevisit~examine(img,mask,329,185,31,10,319,66,512,20,12)
nPoint=0;nDiffuse=0
head='status'||'09'x||'x'||'09'x||'y'||'09'x||'contrast'||'09'x||'coarse_area'||'09'x||'half_max_area'||'0a'x
ignore=charout(reportFile,head,1)
do c over spots
  if c['STATUS']='POINT_LIKE_UNIDENTIFIED' then nPoint+=1
  else nDiffuse+=1
  line=c['STATUS']||'09'x||c['FRAME_X']||'09'x||c['FRAME_Y']||'09'x|| -
    c['CONTRAST']||'09'x||c['COARSE_AREA']||'09'x||c['HALF_MAX_AREA']||'0a'x
  ignore=charout(reportFile,line)
end
ignore=stream(reportFile,'C','CLOSE')
say 'FRAME' img~width img~height 'TEMPORAL_CLUSTER_COUNT' spots~items
say 'POINT_LIKE_UNIDENTIFIED' nPoint 'DIFFUSE_OR_OTHER' nDiffuse
say 'PASS: full-resolution candidate revisit computed from native PNG; no star identity promoted'
exit 0
::requires '../src/MoonsaultFullResolutionRevisit.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaLocalByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaPngFile.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaRasterOps.cls'