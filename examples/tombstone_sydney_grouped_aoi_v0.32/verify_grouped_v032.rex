/* Native ooRexx v0.32 admission: grouped unclassified V5V AOI observations.
 * Source immutable; Power SLAM image-landmark hints are NOT world geometry.
 * Deliberately refuse TESTED, VESSEL identity and uncertified map poses.
 */
numeric digits 18
parse arg proposalDir groupFile featureFile
if proposalDir='' | groupFile='' | featureFile='' then do
 say 'USAGE: verify_grouped_v032.rex proposalDir all_groups.psv grouped_crops_features.psv'
 exit 2
end
props=.directory~new; seen=.directory~new; groups=.directory~new; featureKeys=.directory~new
prefix=.array~of('cruise_cam2','cruise_cam3','baseline_cam2','baseline_cam3')
counts=.directory~new
ph='source_sha256|frame|timestamp_seconds|rank|box_x0|box_y0|box_x1|box_y1|lookup_x0|lookup_y0|lookup_x1|lookup_y1|score100|outside_water_changes|total_changes|palette_edges|water_cells|proposal_state|evidence_state'
do stem over prefix
 f=proposalDir||'/'||stem||'_proposals.psv'
 if stream(f,'c','query exists')='' then call bad 'source proposals not found'
 if linein(f)\==ph then call bad 'proposal schema'
 do while lines(f)>0
  line=linein(f)
  if pipeCount(line)<>18 then call bad 'proposal pipe count'
  parse var line sha '|' frame '|' pts '|' rank '|' bx0 '|' by0 '|' bx1 '|' by1 '|' x0 '|' y0 '|' x1 '|' y1 '|' score '|' outside '|' changed '|' edges '|' water '|' state '|' authority
  if state\=='UNCLASSIFIED_CANDIDATE' | authority\=='OBSERVED_UNTESTED' then call bad 'source candidate promoted'
  call validSource sha,stem
  if \datatype(frame,'W') | \datatype(rank,'W') | \datatype(pts,'N') then call bad 'source chronology malformed'
  if rank<1 | rank>5 | (frame<>450 & frame<>900 & frame<>1350) | abs(pts-(1.4+frame/30))>0.00001 then call bad 'source chronology wrong'
  vals=.array~of(bx0,by0,bx1,by1,x0,y0,x1,y1,score,outside,changed,edges,water)
  do v over vals
   if \datatype(v,'W') then call bad 'source pixel fields not whole'
  end
  if bx1-bx0<>12 | by1-by0<>12 | x0<>max(0,bx0-2) | y0<>max(0,by0-2) | x1<>min(80,bx1+2) | y1<>min(45,by1+2) then call bad 'source candidate bounds altered'
  id=sha||'.'||frame||'.'||rank
  if props~hasIndex(id) then call bad 'duplicated source candidate'
  props[id]=.array~of(x0,y0,x1,y1,pts)
 end
 call stream f,'c','close'
end
if props~items<>60 then call bad 'expected 60 prior unclassified proposals'
gh='source_sha256|frame|timestamp_seconds|group|member_ranks|members|lookup_x0|lookup_y0|lookup_x1|lookup_y1|bbox_cells|union_cells|previous_separate_cells|duplicate_saved_cells|unchanged_upper_cells|changing_upper_cells|changing_water_cells|provisional_landmark_overlap|static_review_state|proposal_state|evidence_state'
if linein(groupFile)\==gh then call bad 'group schema'
n=0; groupArea=0; previousArea=0
 do while lines(groupFile)>0
  line=linein(groupFile)
  if pipeCount(line)<>20 then call bad 'group pipe count'
  parse var line sha '|' frame '|' pts '|' rank '|' ranks '|' memberCount '|' x0 '|' y0 '|' x1 '|' y1 '|' area '|' uni '|' previous '|' saved '|' stable '|' moving '|' water '|' land '|' hint '|' state '|' authority
  if state\=='UNCLASSIFIED_GROUP' | authority\=='OBSERVED_UNTESTED' then call bad 'group identity or authority promoted'
  if \datatype(frame,'W') | \datatype(pts,'N') | \datatype(rank,'W') | \datatype(memberCount,'W') then call bad 'group chronology malformed'
  if rank<1 | rank>5 | memberCount<1 | memberCount>5 | (frame<>450 & frame<>900 & frame<>1350) | abs(pts-(1.4+frame/30))>0.00001 then call bad 'group chronology invalid'
  metrics=.array~of(x0,y0,x1,y1,area,uni,previous,saved,stable,moving,water,land)
  do v over metrics
   if \datatype(v,'W') then call bad 'group metric is not whole'
  end
  if x0<0 | y0<0 | x1>80 | y1>45 | x0>=x1 | y0>=y1 then call bad 'group rectangle invalid'
  if area<>(x1-x0)*(y1-y0) | area>1200 | uni<1 | uni>area | saved<0 | stable<0 | moving<0 | water<0 then call bad 'group area or conservation failed'
  if stable+moving+water>area then call bad 'group temporal evidence exceeds area'
  id=sha||'.'||frame||'.G'||rank
  if groups~hasIndex(id) then call bad 'duplicate grouped identity'
  union=.directory~new
  expectedPrevious=0; minX=80;minY=45;maxX=0;maxY=0
  terms=translate(ranks,' ', ',')
  if words(terms)<>memberCount then call bad 'member count mismatch'
  do j=1 to words(terms)
   r=word(terms,j)
   if \datatype(r,'W') | r<1 | r>5 then call bad 'member identity malformed'
   pid=sha||'.'||frame||'.'||r
   if \props~hasIndex(pid) then call bad 'member not in V5V proposals'
   if seen~hasIndex(pid) then call bad 'proposal used in multiple groups'
   seen[pid]=1
   p=props[pid]
   if abs(p[5]-pts)>0.00001 then call bad 'source-to-group PTS different'
   minX=min(minX,p[1]);minY=min(minY,p[2]);maxX=max(maxX,p[3]);maxY=max(maxY,p[4])
   expectedPrevious=expectedPrevious+(p[3]-p[1])*(p[4]-p[2])
   do yy=p[2] to p[4]-1
    do xx=p[1] to p[3]-1
     union[xx||'.'||yy]=1
    end
   end
  end
  if x0<>minX | y0<>minY | x1<>maxX | y1<>maxY then call bad 'merged rectangle not member hull'
  if uni<>union~items | expectedPrevious<>previous | saved<>previous-uni then call bad 'area overlap accounting falsified'
  /* Source class ties site label to the existing v0.27a image mask only. */
  if sha='c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e' | sha='58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d' then do
   expectedLand=max(0,min(43,x1)-max(3,x0))*max(0,min(25,y1)-max(7,y0))
   if land<>expectedLand then call bad 'Café Sydney landmark control mismatch'
   if expectedLand>0 then expectedHint='UNSURVEYED_LANDMARK_OVERLAP_REVIEW'
   else expectedHint='NO_REGISTERED_OVERLAP'
  end
  else do
   if sha\=='6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830' & sha\=='bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0' then call bad 'unregistered video SHA'
   expectedLand=0;expectedHint='UNKNOWN_UNSURVEYED'
  end
  if hint\==expectedHint then call bad 'landmark status promoted'
  groups[id]=.array~of(sha,frame,x0,y0,x1,y1,pts)
  n=n+1;groupArea=groupArea+area;previousArea=previousArea+previous
 end
call stream groupFile,'c','close'
if n<>28 | seen~items<>60 then call bad 'grouped partition incomplete'
fh='camera|period|source_sha256|frame|timestamp_seconds|group|member_ranks|members|lookup_x0|lookup_y0|lookup_x1|lookup_y1|bbox_cells|union_cells|unchanged_upper_cells|changing_upper_cells|changing_water_cells|provisional_landmark_overlap|static_review_state|source_x|source_y|width|height|rgb_sha256|bright|vertical_edge|both_changes|dynamic_bright|coherent_blocks|evidence_state'
if linein(featureFile)\==fh then call bad 'source RGB features schema'
count=0
 do while lines(featureFile)>0
  line=linein(featureFile)
  if pipeCount(line)<>29 then call bad 'source feature pipe count'
  parse var line cam '|' period '|' sha '|' frame '|' pts '|' rank '|' ranks '|' members '|' x0 '|' y0 '|' x1 '|' y1 '|' area '|' uni '|' stable '|' moving '|' water '|' land '|' hint '|' sx '|' sy '|' sw '|' sh '|' digest '|' bright '|' vedge '|' both '|' dynamic '|' coherent '|' authority
  if authority\=='OBSERVED_UNTESTED' then call bad 'crop authority promoted'
  id=sha||'.'||frame||'.G'||rank
  if \groups~hasIndex(id) then call bad 'source crop not linked to group'
  if featureKeys~hasIndex(id) then call bad 'duplicate crop source identity'
  featureKeys[id]=1
  g=groups[id]
  if g[3]<>x0 | g[4]<>y0 | g[5]<>x1 | g[6]<>y1 | abs(g[7]-pts)>0.00001 then call bad 'crop group geometry or PTS altered'
  if cam<>'2' & cam<>'3' then call bad 'unknown camera for grouped crop'
  if period<>'cruise' & period<>'baseline' then call bad 'unknown period'
  if cam='2' then factor=16
  else factor=8
  if \datatype(sx,'W') | \datatype(sy,'W') | \datatype(sw,'W') | \datatype(sh,'W') then call bad 'non-integer source coordinates'
  if sx<>x0*factor | sy<>y0*factor | sw<>(x1-x0)*factor | sh<>(y1-y0)*factor then call bad 'source ROI not V5V aligned'
  if length(digest)<>64 | verify(digest,'0123456789abcdef')<>0 then call bad 'cropped RGB SHA malformed'
  if \datatype(bright,'N') | \datatype(vedge,'N') | \datatype(both,'N') | \datatype(dynamic,'N') | \datatype(coherent,'W') then call bad 'noncanonical native feature numeric'
  if bright<0 | bright>1 | vedge<0 | vedge>1 | both<0 | both>1 | dynamic<0 | dynamic>1 | coherent<0 then call bad 'native feature bounds'
  count=count+1
 end
call stream featureFile,'c','close'
if count<>28 | featureKeys~items<>groups~items then call bad 'not all grouped source regions materialized'
if groupArea<>11923 | previousArea<>15040 then call bad 'reference total group area mismatch'
say 'SYDNEY V032 NATIVE OOREXX GROUP RECEIPT PASS: proposals=60 groups='n 'group_cells='groupArea 'previous_cells='previousArea 'saving='previousArea-groupArea
say 'STATUS=OBSERVED_UNTESTED, GEOMETRY=UNSURVEYED, VESSEL_IDENTITY=UNRESOLVED'
exit 0
validSource: procedure
 use arg sha, stem
 select
  when stem='cruise_cam2' then expected='6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830'
  when stem='cruise_cam3' then expected='c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e'
  when stem='baseline_cam2' then expected='bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0'
  when stem='baseline_cam3' then expected='58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d'
  otherwise call bad 'source lookup inconsistent'
 end
 if sha\==expected then call bad 'original source hash mismatch'
 return
pipeCount: procedure
 use arg s
 count=0
 do i=1 to length(s)
  if substr(s,i,1)=='|' then count=count+1
 end
 return count
bad: procedure
 use arg message
 say 'V032_GROUP_REJECT:' message
 exit 3
