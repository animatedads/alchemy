/* batch_map.rex -- SPASH 3D map over many known-speech windows (V7 Tier A, user-reviewed), one process.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * usage: batch_map.rex listTsv outTsv shard nShards
 *   listTsv rows: clip<TAB>fc_wall_seconds_of_peak
 * env: SPASH_PCM SPASH_WORK SPASH_MAPS SPASH_CLOCK
 * Per window: FC time t_fc; FD time = t_fc - clock(t). Scores as Spash3DWindow (delta step 2 ms, +-50 ms).
 */
numeric digits 20
parse arg listF outF shard nShards .
if shard='' then do; shard=1; nShards=1; end
parse value value('SPASH_CLOCK',,'ENVIRONMENT') with cA cB
work=value('SPASH_WORK',,'ENVIRONMENT')
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS')
maps=.array~new; do w over value('SPASH_MAPS',,'ENVIRONMENT')~space~makeArray(' '); maps~append(w); end
pts=.Spash3DWindow~loadMap(maps)
o=.stream~new(outF); o~open('WRITE REPLACE')
o~lineout('clip'||'09'x||'fd_time'||'09'x||'fc_time'||'09'x||'delta_ms'||'09'x||'best_x'||'09'x||'best_y'||'09'x||'best_z'||'09'x||'best_room'||'09'x||'best_unit'||'09'x||'S1'||'09'x||'S2'||'09'x||'top10_unit_AEF'||'09'x||'top10_unit_OTHER'||'09'x||'top10_STREET'||'09'x||'top10_REAR'||'09'x||'top10_STAIR'||'09'x||'meas_fc_over_fd_db_B3'||'09'x||'top10_points'||'09'x||'klaxon_gates')
s=.stream~new(listF); s~open('READ'); i=0
do while s~lines>0
  l=s~linein; if l='' then iterate
  i+=1; if (i-1)//nShards<>shard-1 then iterate
  parse var l clip '09'x tfc
  tfc=tfc+0; off=cA+cB*(tfc-hms2sec('120000'))/3600; tfd=tfc-off
  /* 20 s around the peak; klaxon bursts gated by TIME on FC (Tom's method), same gates applied to FD */
  fdR=work'/b'shard'_fdr.f32'; fcR=work'/b'shard'_fcr.f32'; fdS=work'/b'shard'_fd.f32'; fcS=work'/b'shard'_fc.f32'
  bs=value('SPASH_BATCH_SEC',,'ENVIRONMENT'); if bs='' then bs=20
  ch['FD']~writeWindow(tfd-bs/2,bs*8000,fdR); ch['FC']~writeWindow(tfc-bs/2,bs*8000,fcR)
  gt=work'/b'shard'_gates.tsv'
  call 'klaxon_gate.rex' fcR fcS gt 0 15 0.15 96
  x=prov~renderSelection(fdR,fcS'.mask.tsv',fdS,8000,1024,256)
  gcount=.stream~new(gt)~lines-1
  cur=.Spash3DWindow~curves(prov,fdS,fcS,work,'b'shard)
  res=.Spash3DWindow~score(pts,cur,-50,50,2)
  rk=res['RANKED']; vr=.array~new
  do r over rk; if r['P']['ROOM']<>'WALL/OTHER' then vr~append(r); end
  cnt=.directory~new; do k over .array~of('UNIT_AEF','UNIT_OTHER','STREET','REAR','STAIRWELL_SHAFT','Stairs'); cnt[k]=0; end
  top=''
  do j=1 to min(10,vr~items)
    p=vr[j]['P']; u=unitOf(p['ROOM']); if u='Stairs' then u='STAIRWELL_SHAFT'
    if cnt~hasIndex(u) then cnt[u]=cnt[u]+1
    top=top||p['X']','p['Y']','p['Z']';'
  end
  b=vr[1]['P']; c=cur['B3']
  if c['RMS_FD']>0 & c['RMS_FC']>0 then lv=format(20*RxCalcLog10(c['RMS_FC']/c['RMS_FD'],16),,1); else lv='NA'
  line=clip'09'x||sec2hms(tfd)'09'x||sec2hms(tfc)'09'x||res['DELTA']'09'x||b['X']'09'x||b['Y']'09'x||b['Z']'09'x||b['ROOM']'09'x||unitOf(b['ROOM'])'09'x||format(vr[1]['S'],,3)'09'x||format(vr[2]['S'],,3)'09'x||cnt['UNIT_AEF']'09'x||cnt['UNIT_OTHER']'09'x||cnt['STREET']'09'x||cnt['REAR']'09'x||cnt['STAIRWELL_SHAFT']'09'x||lv'09'x||top
  o~lineout(line||'09'x||gcount); call stream outF,'C','FLUSH'
  if i//20=0 then say 'shard' shard 'windows' i
end
s~close; o~close
say 'shard' shard 'DONE'
exit 0
unitOf: procedure
  use arg room
  if wordpos(room,'A E F')>0 then return 'UNIT_AEF'
  if wordpos(room,'B C D G H I Corridor')>0 then return 'UNIT_OTHER'
  return room
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'Spash3DWindow.cls'
::requires 'rxmath' LIBRARY
