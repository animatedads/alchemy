/* rake_test.rex -- does combining the 3D model's reflection paths raise speech SNR, and how sensitive is it?
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026.
 * Simulation: clean poi1 sent along the Physics World arrival paths of a point P to receiver FD
 *   (advance_k = delay_k - delay_first; gains = model 1 kHz amplitudes relative to the strongest, floored at 0.1),
 *   plus independent pink noise at 0 dB speech-band SNR.  Score: native compare against clean poi1.
 * Methods: NONE, RAKE_TRUE (P's paths), RAKE_WRONG (another room's paths), RAKE_JIT<ms> (P's paths with
 *   uniform random path-delay error +-ms, i.e. model geometry error).
 * usage: rake_test.rex roomP roomW seed */
numeric digits 16
parse arg roomP roomW seed .
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
work=value('SPASH_WORK',,'ENVIRONMENT')
maps=.array~new; do w over value('SPASH_MAPS',,'ENVIRONMENT')~space~makeArray(' '); maps~append(w); end
pts=.Spash3DWindow~loadMap(maps)
P=pick(pts,roomP); W=pick(pts,roomW)
say 'P' P['ID'] 'room' P['ROOM'] 'at' P['X'] P['Y'] P['Z'] 'FD paths' P['FD']~items
say 'W' W['ID'] 'room' W['ROOM'] 'at' W['X'] W['Y'] W['Z'] 'FD paths' W['FD']~items
tp=taps(P); tw=taps(W)
do i=1 to tp~items; say '  path' i 'advance_ms' format(tp[i]~word(1)/8,,3) 'gain' format(tp[i]~word(2),,3); end
/* simulate: x(t) = sum g_k s(t - adv_k)  == rake with NEGATIVE advances on the clean signal */
poi=value('SPASH_PCM',,'ENVIRONMENT')'/poi1.f32'
neg=work'/rk_sim.tsv'; o=.stream~new(neg); o~open('WRITE REPLACE'); gs=0
do t over tp; parse var t a g; o~lineout((-a)'09'x||g); gs+=g; end
o~close
x=prov~rake(poi,work'/rk_rev.f32',neg)                 /* normalised by sum g: rescale not needed for SNR */
/* noise at 0 dB in 300-3400 Hz */
n=.stream~new(poi)~query('size')/4
address system 'ffmpeg -v error -y -f lavfi -i "anoisesrc=color=pink:seed='seed':sample_rate=8000:duration='n/8000+1'" -t' n/8000 '-f f32le' work'/rk_noise.f32'
mk=work'/rk.mask.tsv'; q=.stream~new(mk); q~open('WRITE REPLACE'); q~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); q~lineout(0'09'x||n'09'x||300'09'x||3400'09'x||1); q~close
x=prov~renderSelection(work'/rk_rev.f32',mk,work'/rk_sb.f32',8000,256,64); sp=prov~measure(work'/rk_sb.f32',work'/rk_sb.f32')~rmsA
x=prov~renderSelection(work'/rk_noise.f32',mk,work'/rk_nb.f32',8000,256,64); nr=prov~measure(work'/rk_nb.f32',work'/rk_nb.f32')~rmsA
x=prov~renderAlignedMix(work'/rk_rev.f32',work'/rk_noise.f32',work'/rk_mix.f32',0,1,sp/nr)
call score 'NONE', work'/rk_mix.f32'
call runrake 'RAKE_TRUE', tp
call runrake 'RAKE_WRONG', tw
call random ,,seed
do jit over .array~of(0.05,0.1,0.25,0.5,1.0)
  tj=.array~new; do t over tp; parse var t a g; e=(random(0,20000)/10000-1)*jit*8; tj~append((a+e) g); end
  call runrake 'RAKE_JIT'jit'ms', tj
end
exit 0
runrake: procedure expose prov work poi
  use arg lab, tl
  f=work'/rk_t.tsv'; o=.stream~new(f); o~open('WRITE REPLACE'); do t over tl; parse var t a g; o~lineout(a'09'x||g); end; o~close
  x=prov~rake(work'/rk_mix.f32',work'/rk_out.f32',f)
  call score lab, work'/rk_out.f32'
  return
score: procedure expose prov poi
  use arg lab, f
  s=prov~compare(poi,f,8000,256,300,3400)
  say lab~left(16) 'SNR' format(s['SNR_DB'],,2)~right(7) 'dB  segSNR' format(s['SEGSNR_DB'],,2)~right(7) '  LSD' format(s['LSD_DB'],,2)~right(6)
  return
pick: procedure
  use arg pts, room
  best=.nil
  do id over pts~allIndexes
    p=pts[id]; if p['ROOM']<>room then iterate
    if best==.nil then best=p; else if p['FD']~items>best['FD']~items then best=p
  end
  if best==.nil then raise syntax 88.900 array('no map point in room',room)
  return best
taps: procedure
  use arg p
  arr=p['FD']; d0=9e9; mx=0
  do a over arr; d0=min(d0,a['DELAY']); mx=max(mx,a['A1000']); end
  out=.array~new
  eq=value('RAKE_EQUAL',,'ENVIRONMENT')
  do a over arr; g=max(a['A1000']/mx,0.1); if eq<>'' then g=1; out~append(((a['DELAY']-d0)*8) g); end
  return out
::requires 'Spash3DWindow.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
