/* Tombstone Sydney Quay baseline /0.10.
   User-visible map scale: approx 200 metres across ferry-wharf frontage.
   This records ONE measured world-length constraint. It cannot qualify a
   3x3 water-plane homography, 2D scale everywhere, or vessel speed.
*/
numeric digits 20
parse arg inputFile outputFile
if inputFile='' | outputFile='' then call fail 'USAGE: quay_baseline.rex metadata.psv result.psv'
if inputFile=outputFile then call fail 'input and output must differ'
if stream(inputFile,'c','query exists')='' then call fail 'input missing'
if stream(outputFile,'c','query exists')<>'' then call fail 'output exists: no silent overwrites of measured evidence'
if linein(inputFile)<>'key|value' then call fail 'bad header'
fields=.directory~new
do while lines(inputFile)>0
 row=linein(inputFile)
 if row='' then iterate
 if length(row)-length(changestr('|',row,''))<>1 then call fail 'invalid number of fields'
 parse var row k '|' v
 if k='' | v='' then call fail 'empty key or value'
 if fields~hasIndex(k) then call fail 'duplicate key'
 allowed='mode baseline_label length_m length_status length_source image_sha256 native_width native_height east_u east_v west_u west_v pixel_source'
 if wordpos(k,allowed)=0 then call fail 'unknown key'
 fields[k]=v
end
call stream inputFile,'c','close'
if \fields~hasIndex('mode') | \fields~hasIndex('baseline_label') | \fields~hasIndex('length_m') | \fields~hasIndex('length_status') | \fields~hasIndex('length_source') then call fail 'required metadata absent'
mode=fields['mode']
if mode<>'LENGTH_ONLY' & mode<>'PIXEL_TIED_CANDIDATE' then call fail 'unsupported mode'
if fields['baseline_label']<>'CIRCULAR_QUAY_FIVE_WHARF_FRONTAGE' then call fail 'wrong baseline'
if fields['length_status']<>'APPROXIMATE_USER_MAP_READING' then call fail 'cannot claim surveyed geometry'
if fields['length_source']<>'USER_MAP_2026-10-31' then call fail 'unrecognized provenance'
if \datatype(fields['length_m'],'N') then call fail 'length nonnumeric'
if fields['length_m']<>200 then call fail 'baseline does not match recorded user observation'
if mode='LENGTH_ONLY' then do
 if fields~items<>5 then call fail 'LENGTH_ONLY must not contain invented pixel anchors'
 state='LENGTH_RECORDED_IMAGE_UNLOCATED'
 pixel='NA';scale='NA';dx='NA';dy='NA'
end
else do
 if fields~items<>13 then call fail 'PIXEL_TIED requires full 13-field schema'
 if fields['pixel_source']<>'MANUAL_IMAGE_MARKING' & fields['pixel_source']<>'SYNTHETIC_TEST_ONLY' then call fail 'pixel source not admitted'
 hash=fields['image_sha256']
 if length(hash)<>64 | verify(hash,'0123456789abcdef')<>0 then call fail 'invalid frame SHA256'
 if \datatype(fields['native_width'],'W') | \datatype(fields['native_height'],'W') then call fail 'native frame dimensions invalid'
 w=fields['native_width'];h=fields['native_height']
 if w<32 | h<32 then call fail 'native frame dimensions too small'
 u1=fields['east_u'];v1=fields['east_v'];u2=fields['west_u'];v2=fields['west_v']
 if \datatype(u1,'N') | \datatype(v1,'N') | \datatype(u2,'N') | \datatype(v2,'N') then call fail 'pixel anchor not numeric'
 if u1<0 | u1>=w | u2<0 | u2>=w | v1<0 | v1>=h | v2<0 | v2>=h then call fail 'anchor off image'
 dx=u2-u1;dy=v2-v1
 if abs(dx)<2 then call fail 'frontage pixels not horizontally distinct'
 pixel=rsqrt(dx*dx+dy*dy)
 if pixel<10 then call fail 'baseline too short to resolve'
 scale=fields['length_m']/pixel
 if fields['pixel_source']='SYNTHETIC_TEST_ONLY' then state='SYNTHETIC_PIXEL_INTERVAL_ONLY'
 else state='APPROXIMATE_BASELINE_SECANT_ONLY_UNSURVEYED'
end
call stream outputFile,'c','open write replace'
call lineout outputFile,'key|value'
call lineout outputFile,'status|'||state
call lineout outputFile,'baseline|'||fields['baseline_label']
call lineout outputFile,'length_m|'||fields['length_m']
call lineout outputFile,'provenance|'||fields['length_source']
call lineout outputFile,'length_status|'||fields['length_status']
call lineout outputFile,'image_baseline_pixel_length|'||pixel
call lineout outputFile,'secant_metres_per_pixel|'||scale
call lineout outputFile,'horizontal_delta_px|'||dx
call lineout outputFile,'vertical_delta_px|'||dy
call lineout outputFile,'ground_plane_homography|NOT_AVAILABLE'
call lineout outputFile,'vessel_world_speed|NOT_AVAILABLE'
call stream outputFile,'c','close'
say 'TOMBSTONE QUAY BASELINE/0.10 PASS STATUS='state 'LENGTH_M='fields['length_m']
exit 0
rsqrt: procedure
 parse arg q
 if q=0 then return 0
 guess=q
 if guess<1 then guess=1
 do forever
   next=(guess+q/guess)/2
   if next>=guess then leave
   guess=next
 end
 return guess
fail: 
 parse arg msg
 say 'TOMBSTONE QUAY BASELINE/0.10 FAIL:' msg
 exit 2
