/* Native ooRexx fail-closed v0.33 evidence admission. The only admitted
 * quantity is image-plane change; ferry identity and world position BLOCKED.
 */
numeric digits 20
parse arg groupsFile temporalFile
if groupsFile='' | temporalFile='' then do
 say 'USAGE verify_occlusion_v033.rex v032_groups.psv v033_temporal.psv'
 exit 2
end
if stream(groupsFile,'c','query exists')='' | stream(temporalFile,'c','query exists')='' then call reject 'missing file'
expected=.directory~new
seen=.directory~new
headers='source_sha256|frame|timestamp_seconds|group|member_ranks|members|lookup_x0|lookup_y0|lookup_x1|lookup_y1|bbox_cells|union_cells|previous_separate_cells|duplicate_saved_cells|unchanged_upper_cells|changing_upper_cells|changing_water_cells|provisional_landmark_overlap|static_review_state|proposal_state|evidence_state'
if linein(groupsFile)\==headers then call reject 'group schema'
do while lines(groupsFile)>0
 s=linein(groupsFile)
 g=s~makeArray('|')
 if g~items<>21 | g[20]\=='UNCLASSIFIED_GROUP' | g[21]\=='OBSERVED_UNTESTED' then call reject 'bad source grouping'
 key=g[1]||':'||g[2]||':'||g[4]
 if expected~hasIndex(key) then call reject 'duplicate source group'
 expected[key]=g
end
call stream groupsFile,'c','close'
if expected~items<>28 then call reject 'expected 28 grouped source regions'
head='source_sha256|camera|frame|group|src_x0|src_y0|src_x1|src_y1|static_control_q95|difference_gate|changed_pixels|total_pixels|changed_fraction|nonwater_changed|nonwater_pixels|water_changed|water_pixels|coherent_eight_pixel_tiles|largest_tile_cluster|temporal_state|geometry_state|evidence_state'
if linein(temporalFile)\==head then call reject 'temporal schema'
count=0; coherent=0; cam2=0;cam3=0
do while lines(temporalFile)>0
 line=linein(temporalFile)
 r=line~makeArray('|')
 if r~items<>22 then call reject 'wrong number of evidence fields'
 sha=r[1];cam=r[2];frame=r[3];grp=r[4]
 if length(sha)<>64 | verify(sha,'0123456789abcdef')<>0 then call reject 'digest malformed'
 if cam\=='2' & cam\=='3' then call reject 'unauthorised camera'
 if cam=='2' then do
  if sha\=='6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830' & sha\=='bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0' then call reject 'camera2 hash forged'
  scale=16;cam2+=1
 end
 else do
  if sha\=='c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e' & sha\=='58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d' then call reject 'camera3 hash forged'
  scale=8;cam3+=1
 end
 if \datatype(frame,'W') | \datatype(grp,'W') then call reject 'frame/group is noninteger'
 if frame<>450 & frame<>900 & frame<>1350 then call reject 'frame is not held-out target'
 key=sha||':'||frame||':'||grp
 if \expected~hasIndex(key) then call reject 'unknown grouped frame'
 if seen~hasIndex(key) then call reject 'duplicate temporal receipt'
 seen[key]=1
 g=expected[key]
 do i=5 to 12
  if \datatype(r[i],'W') then call reject 'invalid geometry integer'
 end
 if \datatype(r[13],'N') then call reject 'invalid fraction'
 do i=14 to 19
  if \datatype(r[i],'W') then call reject 'invalid count integer'
 end
 if r[5]<>g[7]*scale | r[6]<>g[8]*scale | r[7]<>g[9]*scale | r[8]<>g[10]*scale then call reject 'source rectangle does not match V5V source geometry'
 if r[11]<0 | r[11]>r[12] | r[12]<>(r[7]-r[5])*(r[8]-r[6]) then call reject 'changed pixel/area conservation'
 if r[14]+r[16]<>r[11] | r[15]+r[17]<>r[12] then call reject 'land-water pixel accounting'
 if r[14]>r[15] | r[16]>r[17] | r[14]<0 | r[16]<0 then call reject 'changed mask bounds'
 if abs(r[11]/r[12]-r[13])>0.000000011 then call reject 'changed fraction untruthful'
 if r[9]>255 | r[9]<0 | r[10]<>max(20,r[9]+6) then call reject 'static-control brightness gate changed'
 if r[18]<0 | r[19]<0 | r[19]>r[18] then call reject 'coherent-tile bounds'
 if r[19]>=4 & r[11]>=64 then status='SPATIALLY_COHERENT_IMAGE_CHANGE'
 else status='WEAK_OR_FRAGMENTED_CHANGE'
 if r[20]\==status then call reject 'change interpretation does not match evidence'
 if r[21]\=='IMAGE_PLANE_ONLY_UNCALIBRATED' then call reject 'forged geometry authority'
 if r[22]\=='OBSERVED_UNTESTED' then call reject 'forged tested/identity authority'
 if status=='SPATIALLY_COHERENT_IMAGE_CHANGE' then coherent+=1
 count+=1
end
call stream temporalFile,'c','close'
if count<>expected~items | seen~items<>expected~items | cam2<>15 | cam3<>13 then call reject 'missing temporal evidence / source coverage'
say 'V033_OCCLUSION_RECEIPT_PASS rows='count 'cam2='cam2 'cam3='cam3 'structured='coherent
say 'WORLD=BLOCKED_UNCALIBRATED; FERRY_IDENTITY=UNVERIFIED; AUTHORITY=OBSERVED_UNTESTED'
exit 0
reject: procedure
 use arg why
 say 'V033_OCCLUSION_RECEIPT_REJECT:' why
 exit 3
