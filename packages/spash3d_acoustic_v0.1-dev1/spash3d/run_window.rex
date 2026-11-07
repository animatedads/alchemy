/* run_window.rex -- SPASH 3D: one window, end to end, no gates.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * usage: run_window.rex fdTime label [scoreSec] [renderSec]
 * env  : SPASH_PCM, SPASH_WORK, SPASH_OUT, SPASH_MAPS (blank-separated TSVs), SPASH_CLOCK ("a b"),
 *        SPASH_POSITIONS ("NAME:x,y,z;NAME:@ROOM;..." named virtual microphone positions;
 *                         @ROOM = this window's hotspot: best-scoring position inside that room)
 * Units (Tom Dyer): UNIT_AEF = rooms A, E, F; UNIT_OTHER = every other room.
 * Outputs (SPASH_OUT/label/): map.tsv (every position, INTER/INTRA/combined), top.tsv, map.svg,
 *   vm_<NAME>.f32/.wav (+32 dB derived listening copies), raw_fd/raw_fc.wav (+32 dB), likeness.tsv, run.tsv
 */
numeric digits 20
parse arg fdTime label scoreSec renderSec .
if scoreSec='' then scoreSec=4; if renderSec='' then renderSec=20
env=.directory~new
do k over .array~of('SPASH_PCM','SPASH_WORK','SPASH_OUT','SPASH_MAPS','SPASH_CLOCK','SPASH_POSITIONS')
  env[k]=value(k,,'ENVIRONMENT')
end
parse value env['SPASH_CLOCK'] with cA cB
outDir=env['SPASH_OUT']'/'label; call sysMkDir outDir
work=env['SPASH_WORK']; prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(env['SPASH_PCM'],'CONTINUOUS')
t=hms2sec(fdTime~left(8)); if fdTime~pos('.')>0 then t=t+('0.'fdTime~substr(fdTime~pos('.')+1))
off=cA+cB*(t-hms2sec('120000'))/3600
/* scoring window and render window (FC shifted onto the FD clock by the model) */
fdS=work'/'label'_fd_score.f32'; fcS=work'/'label'_fc_score.f32'
ch['FD']~writeWindow(t,scoreSec*8000,fdS); ch['FC']~writeWindow(t+off,scoreSec*8000,fcS)
r0=t+scoreSec/2-renderSec/2
fdR=outDir'/raw_fd.f32'; fcR=outDir'/raw_fc.f32'
ch['FD']~writeWindow(r0,renderSec*8000,fdR); ch['FC']~writeWindow(r0+off,renderSec*8000,fcR)
/* curves + score */
cur=.Spash3DWindow~curves(prov,fdS,fcS,work,label)
maps=.array~new; do w over env['SPASH_MAPS']~space~makeArray(' '); maps~append(w); end
pts=.Spash3DWindow~loadMap(maps)
res=.Spash3DWindow~score(pts,cur)
delta=res['DELTA']; ranked=res['RANKED']
/* map.tsv */
o=.stream~new(outDir'/map.tsv'); o~open('WRITE REPLACE')
o~lineout('rank'||'09'x||'x_m'||'09'x||'y_m'||'09'x||'z_m'||'09'x||'region'||'09'x||'room'||'09'x||'inter'||'09'x||'intra'||'09'x||'combined'||'09'x||'pred_fc_minus_fd_ms'||'09'x||'pred_fc_over_fd_db_1k'||'09'x||'unit')
do i=1 to ranked~items
  r=ranked[i]; p=r['P']; tau=p['FC'][1]['DELAY']-p['FD'][1]['DELAY']
  o~lineout(i'09'x||p['X']'09'x||p['Y']'09'x||p['Z']'09'x||p['REGION']'09'x||p['ROOM']'09'x||format(r['SINTER'],,4)'09'x||format(r['SINTRA'],,4)'09'x||format(r['S'],,4)'09'x||format(tau,,2)'09'x||r['PRED_LEVEL_DB']'09'x||unitOf(p['ROOM']))
end
o~close
/* best per region/room, so alternatives are kept rather than discarded */
best=.directory~new
do r over ranked; k=r['P']['ROOM']; if \best~hasIndex(k) then best[k]=r; end
/* virtual microphone positions: model best + named */
vm=.array~new
b1=ranked[1]['P']; vm~append('BEST:'b1['X']','b1['Y']','b1['Z'])
do w over env['SPASH_POSITIONS']~makeArray(';'); if w<>'' then vm~append(w); end
gain='39.810717055'   /* +32 dB */
lk=.stream~new(outDir'/likeness.tsv'); lk~open('WRITE REPLACE')
lk~lineout('view'||'09'x||'position'||'09'x||'focus_lag_ms'||'09'x||'poi1_top_likeness'||'09'x||'match_start_s'||'09'x||'matches_ge_0.70')
q=.SpashAudioBlocks~observe(prov,value('SPASH_PCM',,'ENVIRONMENT')'/poi1.f32','POI1'); tmpl=.SpashAudioBlocks~activeTemplate(q,6)
fl=value('SPASH_FLOOR',,'ENVIRONMENT'); if fl='' then fl=0.70
srch=.SpashExampleSearch~new(fl,0.20)
do v over .array~of('RAW_FD','RAW_FC')
  if v='RAW_FD' then f=fdR; else f=fcR
  lv=likeness(prov,srch,tmpl,f,v)
  lk~lineout(v'09'x||'-'||'09'x||'-'||'09'x||lv)
  call toWav prov, f, outDir'/'v~lower'.wav', gain, 1, 0
end
do w over vm
  parse var w name ':' spec
  if spec~left(1)='@' then do
    p=.nil; do r over ranked; if r['P']['ROOM']=spec~substr(2) then do; p=r['P']; leave; end; end
    if p==.nil then iterate
  end
  else do
    parse var spec x ',' y ',' z
    p=nearest(pts,x,y,z)
  end
  tau=p['FC'][1]['DELAY']-p['FD'][1]['DELAY']
  lagS=trunc((tau+delta)*8+0.5)
  f=outDir'/vm_'name'.f32'
  x2=prov~renderAlignedMix(fdR,fcR,f,lagS,0.5,0.5)
  lv=likeness(prov,srch,tmpl,f,'VM_'name)
  lk~lineout('VM_'name'09'x||p['X']','p['Y']','p['Z']' ('p['ROOM']')'||'09'x||format(tau+delta,,2)'09'x||lv)
  call toWav prov, f, outDir'/vm_'name'.wav', gain, 1, 1
end
lk~close
/* top.tsv and run.tsv */
o=.stream~new(outDir'/top.tsv'); o~open('WRITE REPLACE')
o~lineout('room_or_region'||'09'x||'best_x'||'09'x||'best_y'||'09'x||'best_z'||'09'x||'combined'||'09'x||'inter'||'09'x||'intra')
do k over best~allIndexes~sort
  r=best[k]; p=r['P']
  o~lineout(k'09'x||p['X']'09'x||p['Y']'09'x||p['Z']'09'x||format(r['S'],,4)'09'x||format(r['SINTER'],,4)'09'x||format(r['SINTRA'],,4))
end
o~close
o=.stream~new(outDir'/run.tsv'); o~open('WRITE REPLACE')
o~lineout('label'||'09'x||label); o~lineout('fd_time'||'09'x||sec2hms(t)); o~lineout('fc_time'||'09'x||sec2hms(t+off))
o~lineout('clock_model_fc_minus_fd_s'||'09'x||format(off,,4)); o~lineout('clock_residual_delta_ms_fitted'||'09'x||delta)
o~lineout('score_window_s'||'09'x||scoreSec); o~lineout('render_window_s'||'09'x||renderSec||' starting FD '||sec2hms(r0))
do bn over .array~of('B1','B2','B3','B4','B5','B6','B7')
  c=cur[bn]; if c['RMS_FD']>0 & c['RMS_FC']>0 then lv=format(20*RxCalcLog10(c['RMS_FC']/c['RMS_FD'],16),,1); else lv='NA'
  o~lineout('measured_fc_over_fd_db_'bn||'09'x||lv)
end
b1r=ranked[1]
o~lineout('best_pred_fc_over_fd_db_1k'||'09'x||b1r['PRED_LEVEL_DB'])
o~lineout('best_position'||'09'x||b1['X']','b1['Y']','b1['Z']' '||b1['ROOM'])
o~lineout('runtime'||'09'x||'ooRexx 5.3.0 r13196; Audio V9 dev16 native provider + SPASH3D patch; Physics World dev50.2 F11 v0.4 scene')
o~lineout('authority'||'09'x||'positions are Physics World hypotheses ranked by measured FD/FC evidence; two observed microphones; virtual microphones are model-focused renders, not recordings')
o~close
call svgMap ranked, outDir'/map.svg', label' FD 'sec2hms(t)' delta='delta'ms'
say label 'delta' delta 'best' b1['X'] b1['Y'] b1['Z'] b1['ROOM'] 'S' format(ranked[1]['S'],,4)
exit 0

likeness: procedure
  use arg prov, srch, tmpl, f32, src
  c=.SpashAudioBlocks~observe(prov,f32,src)
  res=srch~find(tmpl,c['OBS'],50)
  if res~items=0 then return '0'||'09'x||'-'||'09'x||'0'
  return format(res[1]~at('LIKENESS'),,3)'09'x||format(res[1]~at('MATCH_START_MS')/1000,,2)'09'x||res~items

unitOf: procedure
  use arg room
  if wordpos(room,'A E F')>0 then return 'UNIT_AEF'
  if wordpos(room,'B C D G H I Corridor')>0 then return 'UNIT_OTHER'
  return room
nearest: procedure
  use arg pts, x, y, z
  best=.nil; bd=1e9
  do id over pts~allIndexes
    p=pts[id]; d=(p['X']-x)**2+(p['Y']-y)**2+(p['Z']-z)**2
    if d<bd & p['FD']~items>0 & p['FC']~items>0 then do; bd=d; best=p; end
  end
  return best

toWav: procedure
  /* +32 dB is a derived listening copy: float gain, then ffmpeg container export with a -1 dBFS limiter */
  use arg prov, f32, wav, gain, mono, isMix
  if isMix then g=gain; else g=gain
  call sysFileDelete wav
  cmd='ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'f32'" -af "volume='g',alimiter=limit=0.89:level=disabled" -c:a pcm_s16le "'wav'"'
  address system cmd
  return

svgMap: procedure
  use arg ranked, path, title
  s=.mutablebuffer~new; sc=34; ox=20; oy=40   /* px per metre, plan x 0..21, y -4..14 */
  W=ox*2+21*sc; H=oy+18*sc+40
  s~append('<svg xmlns="http://www.w3.org/2000/svg" width="'W'" height="'H'" font-family="sans-serif" font-size="11">')
  s~append('<rect width="100%" height="100%" fill="#fff"/><text x="'ox'" y="20" font-size="13">'title'</text>')
  mx=-9; mn=9; do r over ranked; if r['S']>mx then mx=r['S']; if r['S']<mn then mn=r['S']; end
  if mx=mn then mx=mn+1
  do r over ranked
    p=r['P']; v=(r['S']-mn)/(mx-mn)
    if p['REGION']='INTERIOR' then sz=1.0; else sz=1.0
    px=ox+(p['X']-sz/2)*sc; py=oy+(p['Y']+4-sz/2)*sc
    red=trunc(255*v); blue=trunc(255*(1-v))
    s~append('<rect x="'format(px,,1)'" y="'format(py,,1)'" width="'format(sz*sc,,1)'" height="'format(sz*sc,,1)'" fill="rgb('red',60,'blue')" fill-opacity="0.75"/>')
  end
  rooms=.array~of('A 142 161 383 370','E 76 371 280 699','F 294 371 495 699','B 510 176 725 699','C 744 161 960 371','D 976 161 1230 371','G 744 458 921 699','H 1078 382 1217 517','I 1001 516 1250 766','Stairs 398 145 486 371')
  do rm over rooms
    parse var rm n x1 y1 x2 y2
    a=.F11SceneV04~pxToM(x1,y1); b=.F11SceneV04~pxToM(x2,y2)
    parse var a mx1 my1; parse var b mx2 my2
    s~append('<rect x="'format(ox+mx1*sc,,1)'" y="'format(oy+(my1+4)*sc,,1)'" width="'format((mx2-mx1)*sc,,1)'" height="'format((my2-my1)*sc,,1)'" fill="none" stroke="#000" stroke-width="1.2"/>')
    s~append('<text x="'format(ox+mx1*sc+3,,1)'" y="'format(oy+(my1+4)*sc+12,,1)'">'n'</text>')
  end
  do mic over .array~of('FC 14.267 9.449','FD 7.014 3.422')
    parse var mic n x y
    s~append('<circle cx="'format(ox+x*sc,,1)'" cy="'format(oy+(y+4)*sc,,1)'" r="5" fill="#0a0"/><text x="'format(ox+x*sc+7,,1)'" y="'format(oy+(y+4)*sc-6,,1)'" font-weight="bold">'n'</text>')
  end
  b=ranked[1]['P']
  s~append('<circle cx="'format(ox+b['X']*sc,,1)'" cy="'format(oy+(b['Y']+4)*sc,,1)'" r="8" fill="none" stroke="#fd0" stroke-width="3"/>')
  s~append('<text x="'ox'" y="'H-12'">rear y&lt;0 | street y&gt;10.2 | colour: combined score (blue low, red high) | ring: best</text></svg>')
  call sysFileDelete path
  o=.stream~new(path); o~open('WRITE REPLACE'); o~charout(s~string); o~close
  return

::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'Spash3DWindow.cls'
::requires 'SpashAudioBlocks.cls'
::requires 'SpashExampleSearch.cls'
::requires 'F11SceneV04.cls'
::requires 'rxmath' LIBRARY
