/* Adapter qualification against REAL Café Sydney Stream3 2-Nov V5V nodes.
 * Checks the complete original V5V chain but never touches 3D camera poses.
 */
numeric digits 18
parse arg nodeFile blobFile
if nodeFile=='' | blobFile=='' then exit 2
sha='c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e'
if stream(nodeFile,'c','query exists')=='' | stream(blobFile,'c','query exists')=='' then call bad 'missing recorded source'
call stream nodeFile,'c','open read'
head=linein(nodeFile)
if head\=='node_id|frame_index|timestamp_seconds|v5v_record|changed_cells|water_changed|excluded_changed|payload_offset|payload_bytes|source_ref|evidence_state' then call bad 'node schema mismatch'
count=0;expectedOff=0;key=0;delta=0
 do while lines(nodeFile)>0
  row=linein(nodeFile)
  parse var row id '|' frame '|' pts '|' typ '|' changed '|' water '|' excluded '|' offset '|' bytes '|' source '|' status
  if \datatype(frame,'W') | frame<>count then call bad 'index out of order'
  if \datatype(pts,'N') | abs(pts-(1.4+count/30))>0.00001 then call bad 'timestamp mismatch'
  if source\=='sha256:'||sha | status\=='OBSERVED_UNTESTED' then call bad 'source or authority forged'
  if \datatype(changed,'W') | \datatype(water,'W') | \datatype(excluded,'W') then call bad 'invalid changed counters'
  if changed<0 | changed>3600 | water+excluded<>changed then call bad 'mask change conservation mismatch'
  if \datatype(offset,'W') | \datatype(bytes,'W') then call bad 'offset malformed'
  if offset<>expectedOff | bytes<0 then call bad 'packed payload offsets not contiguous'
  if count//30=0 then do
   if typ\=='KEYFRAME' | bytes<>2250 then call bad 'keyframe cadence or length mismatch'
   key=key+1
  end
  else do
   if typ\=='DELTA' | bytes<450 then call bad 'delta cadence or length mismatch'
   delta=delta+1
  end
  expectedOff=expectedOff+bytes
  count=count+1
 end
call stream nodeFile,'c','close'
if count<>1800 then call bad 'source frame count mismatch'
size=stream(blobFile,'c','query size')
if \datatype(size,'W') | size<>expectedOff then call bad 'packed V5V byte length mismatch'
if key<>60 | delta<>1740 then call bad 'keyframe count unexpected'
s=.CrossSlamEvidence~new
q=s~register('CAFE','MODEL_360_PANORAMA','b779bebb0d1372e1fef7d83c4390f709a6da3c99330309ce3cfb5d02095fb602',2048,512,'MODEL_BEARING_CANVAS','CAMERA_POSE_HYPOTHESIS')
q=s~register('V5V_CAM3','V5V_VIDEO',sha,80,45,'V5V_IMAGE_LATTICE_80x45','OBSERVED_UNTESTED')
if s~sourceToWorld('V5V_CAM3','CAFE')\=='BLOCKED_NO_QUALIFIED_TRANSFORM' then call bad 'uncalibrated source admitted'
say 'REAL_V5V_BOUNDARY_PASS frames='count 'keyframes='key 'deltas='delta 'packed_bytes='size
say 'PANORAMA_TO_CAMERA=BLOCKED_UNCALIBRATED'
exit 0
bad: procedure
 use arg why
 say 'REAL_V5V_BOUNDARY_REJECT:' why
 exit 3
::requires 'CrossSlamEvidence.cls'
