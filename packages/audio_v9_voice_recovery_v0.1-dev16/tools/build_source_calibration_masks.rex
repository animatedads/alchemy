numeric digits 30
parse arg prefix edgeSerial windowStartSerial outDir minBoxes maxGroups
if outDir='' then do
  say 'usage: build_source_calibration_masks.rex ACOUSTIC_PREFIX EDGE_SERIAL WINDOW_START_SERIAL OUT_DIR [MIN_BOXES_PER_QUADRANT] [MAX_GROUPS]'
  exit 2
end
if minBoxes='' then minBoxes=3
if maxGroups='' then maxGroups=8
minBoxes=minBoxes+0; maxGroups=maxGroups+0
if minBoxes<1 then do; say 'FAIL minBoxes must be >=1'; exit 2; end
if maxGroups<1 then do; say 'FAIL maxGroups must be >=1'; exit 2; end
edgeMs=(edgeSerial+0)*1000; baseMs=(windowStartSerial+0)*1000; sr=8000
call sysMkDir outDir

trackFamily=.directory~new
familyTracks=.directory~new
path=prefix||'.appearances.tsv'; call requireFile path
r=.AudioV9TsvReader~new(path,.array~of('family_id','track_id','start_ms','end_ms','members'))
do forever
  f=r~next; if f==.nil then leave
  if f~items=1 & f[1]='' then iterate
  if f~items<>5 then call fail 'bad appearances row'
  if trackFamily~hasIndex(f[2]) then call fail 'track appears in more than one family: '||f[2]
  trackFamily[f[2]]=f[1]
  if \familyTracks~hasIndex(f[1]) then familyTracks[f[1]]=.array~new
  familyTracks[f[1]]~append(f[2])
end
r~close

familySpeaker=.directory~new
path=prefix||'.speakers.tsv'; call requireFile path
r=.AudioV9TsvReader~new(path,.array~of('speaker_id','family_id'))
do forever
  f=r~next; if f==.nil then leave
  if f~items=1 & f[1]='' then iterate
  if f~items<>2 then call fail 'bad speakers row'
  if familySpeaker~hasIndex(f[2]) then call fail 'family appears in more than one speaker cluster: '||f[2]
  familySpeaker[f[2]]=f[1]
end
r~close

charTrack=.directory~new
path=prefix||'.track_members.tsv'; call requireFile path
r=.AudioV9TsvReader~new(path,.array~of('track_id','character_id','start_ms','end_ms','feed','band'))
do forever
  f=r~next; if f==.nil then leave
  if f~items=1 & f[1]='' then iterate
  if f~items<>6 then call fail 'bad track_members row'
  if charTrack~hasIndex(f[2]) then call fail 'character appears in more than one track: '||f[2]
  charTrack[f[2]]=f[1]
end
r~close

groups=.directory~new
path=prefix||'.characters.tsv'; call requireFile path
charHeader=.array~of('id','start_ms','end_ms','feed','band','center_hz','motion','turn','active','coherence','ratio_db','crest','lag_abs_ms')
r=.AudioV9TsvReader~new(path,charHeader)
do forever
  f=r~next; if f==.nil then leave
  if f~items=1 & f[1]='' then iterate
  if f~items<>13 then call fail 'bad characters row'
  cid=f[1]
  if \charTrack~hasIndex(cid) then iterate
  track=charTrack[cid]
  if \trackFamily~hasIndex(track) then iterate
  fam=trackFamily[track]
  groupId=fam; kind='FAMILY'
  if familySpeaker~hasIndex(fam) then do; groupId=familySpeaker[fam]; kind='SPEAKER'; end
  st=f[2]+0; en=f[3]+0
  side=''
  if en<=edgeMs then side='BEFORE'
  else if st>=edgeMs then side='AFTER'
  else iterate
  feed=f[4]~upper
  if feed\='FC' then if feed\='FD' then call fail 'bad character feed'
  if \groups~hasIndex(groupId) then do
    g=.directory~new; g['id']=groupId; g['kind']=kind; g['families']=.directory~new; g['rowsFC']=.array~new; g['rowsFD']=.array~new; g['FC_BEFORE']=0; g['FC_AFTER']=0; g['FD_BEFORE']=0; g['FD_AFTER']=0; g['score']=0; groups[groupId]=g
  end
  g=groups[groupId]; g['families'][fam]=1
  motion=f[7]+0; active=f[9]+0; coh=f[10]+0
  mm=motion/3; if mm>1 then mm=1; if mm<0 then mm=0
  w=.25+.25*active+.25*coh+.25*mm; if w>1 then w=1; if w<.20 then w=.20
  localStart=st-baseMs; localEnd=en-baseMs
  if localEnd<=0 then iterate
  if localStart<0 then localStart=0
  startSample=trunc(localStart*sr/1000); endSample=trunc(localEnd*sr/1000)
  center=f[6]+0; lo=center-120; hi=center+120; if lo<120 then lo=120; if hi>3800 then hi=3800
  if hi<=lo then iterate
  maskrow=startSample||'09'x||endSample||'09'x||lo||'09'x||hi||'09'x||w
  if feed='FC' then g['rowsFC']~append(maskrow); else g['rowsFD']~append(maskrow)
  key=feed||'_'||side; g[key]=g[key]+1; g['score']=g['score']+w
end
r~close

eligible=.array~new
do gid over groups~allIndexes
  g=groups[gid]
  ok=.true
  do key over .array~of('FC_BEFORE','FC_AFTER','FD_BEFORE','FD_AFTER')
    if g[key]<minBoxes then ok=.false
  end
  if ok then eligible~append(g)
end
ordered=sortGroups(eligible)
manifest=outDir||'/groups.tsv'; call stream manifest,'C','OPEN WRITE REPLACE'
call lineout manifest,'group_id'||'09'x||'kind'||'09'x||'families'||'09'x||'fc_before'||'09'x||'fc_after'||'09'x||'fd_before'||'09'x||'fd_after'||'09'x||'score'||'09'x||'fc_mask'||'09'x||'fd_mask'
emitted=0
do i=1 to ordered~items
  if emitted>=maxGroups then leave
  g=ordered[i]; gid=g['id']; famText=joinKeys(g['families'])
  safe=safeName(gid); fcMask=outDir||'/'||safe||'.fc.select.tsv'; fdMask=outDir||'/'||safe||'.fd.select.tsv'
  call writeMask fcMask,g['rowsFC']; call writeMask fdMask,g['rowsFD']
  call lineout manifest,gid||'09'x||g['kind']||'09'x||famText||'09'x||g['FC_BEFORE']||'09'x||g['FC_AFTER']||'09'x||g['FD_BEFORE']||'09'x||g['FD_AFTER']||'09'x||g['score']||'09'x||fcMask||'09'x||fdMask
  emitted=emitted+1
end
call stream manifest,'C','CLOSE'
say 'PASS source calibration masks groups='||emitted||' eligible='||eligible~items||' min_boxes='||minBoxes||' out='||manifest
exit 0

writeMask: procedure
  use arg path,rows
  call stream path,'C','OPEN WRITE REPLACE'; call lineout path,'start_sample'||'09'x||'end_sample'||'09'x||'low_hz'||'09'x||'high_hz'||'09'x||'weight'
  do r over rows; call lineout path,r; end
  call stream path,'C','CLOSE'; return

sortGroups: procedure
  use arg a
  out=.array~new
  do g over a
    placed=.false; tmp=.array~new
    do i=1 to out~items
      if \placed then do
        before=.false
        if g['score']>out[i]['score'] then before=.true
        else if g['score']=out[i]['score'] then if g['id']<out[i]['id'] then before=.true
        if before then do; tmp~append(g); placed=.true; end
      end
      tmp~append(out[i])
    end
    if \placed then tmp~append(g)
    out=tmp
  end
  return out

joinKeys: procedure
  use arg d
  a=.array~new; do k over d~allIndexes; a~append(k); end; a~sort
  s=''; do i=1 to a~items; if i>1 then s=s||','; s=s||a[i]; end; return s

safeName: procedure
  use arg s
  out=''; do i=1 to s~length; c=s~substr(i,1); if c~datatype('A') | c~datatype('N') | c='_' | c='-' then out=out||c; else out=out||'_'; end
  return out

requireFile: procedure
  use arg p
  if stream(p,'C','QUERY EXISTS')='' then call fail 'required analysis file missing: '||p
  return

sysMkDir: procedure
  use arg p
  address system 'mkdir -p '||quote(p)
  if rc<>0 then call fail 'cannot create output directory: '||p
  return

quote: procedure
  use arg s
  return "'"||s~changestr("'","'\\''")||"'"

fail: procedure
  use arg m
  say 'FAIL '||m
  exit 2

::requires 'AudioV9Tsv.cls'
