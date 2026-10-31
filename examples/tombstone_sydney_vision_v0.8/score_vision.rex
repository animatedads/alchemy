/* Tombstone Sydney v0.7: ooRexx visual EVIDENCE scorer, NOT SLAM's code-graph score.
   Pixel features are supplied by extract_features.py; classification is native ooRexx.
   Leave-ONE-SOURCE-FRAME-out. REVIEW observations never train or become negatives.
   This is a narrow colour-based yellow/green ferry detector, not all ferry classes.
*/
/* signal on syntax name syntaxError */
numeric digits 16
parse arg referenceFile heldoutFile
if referenceFile='' then referenceFile='features.psv'
if heldoutFile='' then heldoutFile='video_features.psv'
expected='source|source_group|object_id|truth|view|width|height|yellow|dark|green|white|edges|aspect|sha256_crop'
seen=.directory~new
count=0
call readRecords referenceFile,0
refs=count
if refs=0 then call fatal 'no references'
call readRecords heldoutFile,1
all=count
say 'TOMBSTONE VISION EVIDENCE/0.7: objects='refs 'heldout=' (all-refs)
/* A frame group is a complete holdout: no other crop from that source image
   may supply either class prior, reference or threshold for that test. */
tp=0;tn=0;fp=0;fn=0;ap=0;an=0;reviews=0;videoHit=0;videoTotal=0
predictions='predictions_v08.psv'
call stream predictions,'c','open write replace'
call lineout predictions,'object_id|truth|guess|score_support|raw_ratio|fold|feature_yellow|feature_dark'
do k=1 to all
 if kind.k='review' then do
   reviews=reviews+1
   iterate
 end
 if kind.k='heldout_positive' then fold='VIDEO_HELDOUT'
 else fold=group.k
 minY=2;minD=2;training=0
 do t=1 to refs
   if kind.t<>'positive' then iterate
   if group.t=fold then iterate
   if yellow.t<minY then minY=yellow.t
   if dark.t<minD then minD=dark.t
   training=training+1
 end
 if training<2 | minY<=0 | minD<=0 then call fatal 'insufficient positive training evidence'
 /* Conservative candidate requirements derived only from other positive instances.
    Ratios are support evidence, not statistical probabilities or SLAM-tested edges. */
 ylimit=.75*minY
 dlimit=.65*minD
 ry=yellow.k/ylimit
 rd=dark.k/dlimit
 raw=ry
 if rd<raw then raw=rd
 if raw>1.1 then guess='ferry'
 else if raw<.9 then guess='not_ferry'
 else guess='abstain'
 support=raw/(1+raw)
 call lineout predictions,oid.k||'|'||kind.k||'|'||guess||'|'||format(support,,6)||'|'||format(raw,,6)||'|'||fold||'|'||yellow.k||'|'||dark.k
 if kind.k='heldout_positive' then do
    videoTotal=videoTotal+1
    if guess='ferry' then videoHit=videoHit+1
    iterate
 end
 select
  when kind.k='positive' & guess='ferry' then tp=tp+1
  when kind.k='positive' & guess='not_ferry' then fn=fn+1
  when kind.k='positive' & guess='abstain' then ap=ap+1
  when kind.k='negative' & guess='not_ferry' then tn=tn+1
  when kind.k='negative' & guess='ferry' then fp=fp+1
  when kind.k='negative' & guess='abstain' then an=an+1
  otherwise call fatal 'unsupported truth/guess combination'
 end
end
call stream predictions,'c','close'
say 'FRAME-HELD-OUT: TP='tp 'FN='fn 'FP='fp 'TN='tn 'ABSTAIN_POS='ap 'ABSTAIN_NEG='an
say 'REVIEW_EXCLUDED='reviews
say 'VIDEO_MANUALLY_SEEDED_POSITIVE_CROPS='videoHit || '/' || videoTotal
if tp+fp>0 then say 'DECIDED_PRECISION='format(tp/(tp+fp),,4)
if tp+fn+ap>0 then say 'RECALL_WITH_ABSTENTION='format(tp/(tp+fn+ap),,4)
say 'SCORES_ARE_FEATURE_SUPPORT_NOT_PROBABILITIES_OR_SLAM_GRAPH_SCORES'
say 'FERRY_CLASS_LIMIT=TRADITIONAL_YELLOW_GREEN_ONLY'
say 'GEO_WATER_PLANE_CALIBRATION=NOT_AVAILABLE'
say 'VISION EVIDENCE QUALIFICATION: PASS'
exit 0
readRecords: procedure expose expected seen count src. group. oid. kind. view. width. height. yellow. dark. green. white. edges. aspect. sha.
 parse arg file,isVideo
 if stream(file,'c','query exists')='' then call fatal 'missing feature file:' file
 hdr=linein(file)
 if hdr<>expected then call fatal 'schema mismatch:' file
 do while lines(file)>0
  rec=linein(file)
  if rec='' then iterate
  parse var rec source '|' grp '|' id '|' truth '|' v '|' w '|' h '|' y '|' d '|' g '|' wh '|' e '|' a '|' hash
  if source='' | grp='' | id='' | hash='' then call fatal 'missing required data'
  if seen~hasIndex(id) then call fatal 'duplicated id:' id
  seen[id]=1
  if isVideo then do
   if truth<>'heldout_positive' | grp<>'video_manly' then call fatal 'invalid heldout provenance'
  end
  else if truth<>'positive' & truth<>'negative' & truth<>'review' then call fatal 'invalid class'
  if \datatype(w,'W') | \datatype(h,'W') | w<=0 | h<=0 then call fatal 'invalid dimensions'
  if \datatype(y,'N') | \datatype(d,'N') | \datatype(g,'N') | \datatype(wh,'N') | \datatype(e,'N') | \datatype(a,'N') then call fatal 'invalid feature numeric'
  if y<0 | y>1 | d<0 | d>1 | g<0 | g>1 | wh<0 | wh>1 | e<0 | e>1 | a<=0 then call fatal 'out-of-range feature'
  if length(hash)<>64 then call fatal 'invalid image hash length'
  count=count+1
  src.count=source;group.count=grp;oid.count=id;kind.count=truth;view.count=v
  width.count=w;height.count=h;yellow.count=y;dark.count=d;green.count=g;white.count=wh;edges.count=e;aspect.count=a;sha.count=hash
 end
 call stream file,'c','close'
 return
fatal:
 parse arg msg
 say 'VISION EVIDENCE QUALIFICATION: FAIL:' msg
 exit 2
syntaxError:
 say 'VISION EVIDENCE QUALIFICATION: SYNTAX:' condition('C') condition('E') condition('I') condition('O')
 exit 3
