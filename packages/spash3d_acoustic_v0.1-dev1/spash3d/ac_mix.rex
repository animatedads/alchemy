/* ac_mix.rex -- A + C: the original voice and its pitch-lowered copy, time-aligned, as one listening file.
 * Architecture: Tom Dyer (5 Nov 2026: "A + C with the timing identical").  Coding: Claude (Opus 5.5).
 * A = 200-3600 Hz, +22 dB fixed (Tom's chain).  C = enhancer, pitch -semis (duration kept), speech AGC.
 * Bird screech: native tonal-burst suppression on the whole context window first (events TSV per item).
 * Alignment: lag of C against A measured on 1 ms linear envelopes over the whole clip (native xcorr,
 * +-30 ms), C shifted by it, then re-measured per 1 s segment (must be 0 ms).
 * Outputs per item: <name>_AC_mix.wav (A and C at equal RMS, summed, -1 dBFS limiter),
 *                   <name>_AC_stereo.wav (A left, C right, same alignment), plus A and C alone.
 * items: name<TAB>FD|FC|path.f32<TAB>start<TAB>durSec      usage: ac_mix.rex itemsTsv outDir [semis] [ctx]
 */
numeric digits 16
parse arg itemsF outDir semis ctx .
if semis='' then semis=-4; if ctx='' then ctx=20
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS'); w=value('SPASH_WORK',,'ENVIRONMENT')
s=.stream~new(itemsF); s~open('READ')
do while s~lines>0
  l=s~linein; if l='' | l~left(1)='#' then iterate
  parse var l name '09'x src '09'x st '09'x dur
  cx=w'/ac_ctx.f32'
  if src='FD' | src='FC' then do
    parse var st hh ':' mm ':' ss; t=hh*3600+mm*60+ss
    pre=min(ctx,t-ch[src]~startSec); ch[src]~writeWindow(t-pre,(pre+dur+ctx)*8000,cx)
  end
  else do
    n=.stream~new(src)~query('size')/4; pre=min(ctx,st)
    len=min(trunc((pre+dur+ctx)*8000), n-trunc((st-pre)*8000)); call cut src, trunc((st-pre)*8000), len, cx
  end
  /* bird screech first (Tom, 5 Nov 2026): tonal bursts in 1.9-3.95 kHz pinned the limiter and AGC */
  nbursts=prov~suppressTonalBursts(cx,w'/ac_ctx_ns.f32',outDir'/'name'_screech_events.tsv')
  cx=w'/ac_ctx_ns.f32'
  n=.stream~new(cx)~query('size')/4
  mk=w'/ac.mask.tsv'; q=.stream~new(mk); q~open('WRITE REPLACE'); q~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); q~lineout(0'09'x||n'09'x||200'09'x||3600'09'x||1); q~close
  x=prov~renderSelection(cx,mk,w'/ac_A0.f32',8000,256,64)
  g=RxCalcPower(10,22/20,16); x=prov~renderAlignedMix(w'/ac_A0.f32',w'/ac_A0.f32',w'/ac_Af.f32',0,g/2,g/2)
  x=prov~enhance(cx,w'/ac_E.f32',8000,256,64,3,0.98,2,0.1,200,3600)
  x=prov~pitchShift(w'/ac_E.f32',w'/ac_P.f32',8000,semis)
  x=prov~speechAgc(w'/ac_P.f32',w'/ac_Cf.f32',8000,-16,36,10,400,6,-1)
  call cut w'/ac_Af.f32', trunc(pre*8000), trunc(dur*8000), w'/ac_A.f32'
  call cut w'/ac_Cf.f32', trunc(pre*8000), trunc(dur*8000), w'/ac_C.f32'
  lag=envLag(w'/ac_A.f32', w'/ac_C.f32', 30)          /* ms, C later than A when > 0 */
  ls=lag*8
  /* shifted C: c'[i] = c[i+ls]  (renderAlignedMix with A weight 0) */
  x=prov~renderAlignedMix(w'/ac_A.f32',w'/ac_C.f32',w'/ac_Cs.f32',ls,0,1)
  segs=''; nn=trunc(dur)
  do k=0 to nn-1
    call cut w'/ac_A.f32', k*8000, 8000, w'/ac_a1.f32'; call cut w'/ac_Cs.f32', k*8000, 8000, w'/ac_c1.f32'
    segs=segs envLag(w'/ac_a1.f32', w'/ac_c1.f32', 15)
  end
  ra=prov~measure(w'/ac_A.f32',w'/ac_A.f32')~rmsA; rc=prov~measure(w'/ac_Cs.f32',w'/ac_Cs.f32')~rmsA
  tgt=RxCalcPower(10,-24/20,16)
  x=prov~renderAlignedMix(w'/ac_A.f32',w'/ac_Cs.f32',w'/ac_mix.f32',0,tgt/ra,tgt/rc)
  x=prov~renderAlignedMix(w'/ac_A.f32',w'/ac_A.f32',w'/ac_An.f32',0,tgt/ra/2,tgt/ra/2)
  x=prov~renderAlignedMix(w'/ac_Cs.f32',w'/ac_Cs.f32',w'/ac_Cn.f32',0,tgt/rc/2,tgt/rc/2)
  call wav w'/ac_mix.f32', outDir'/'name'_AC_mix.wav'
  call wav w'/ac_An.f32', outDir'/'name'_A.wav'
  call wav w'/ac_Cn.f32', outDir'/'name'_C'abs(semis)'.wav'
  address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'w'/ac_An.f32" -f f32le -ar 8000 -ac 1 -i "'w'/ac_Cn.f32" -filter_complex "[0:a][1:a]join=inputs=2:channel_layout=stereo,alimiter=limit=0.89:level=disabled" -c:a pcm_s16le "'outDir'/'name'_AC_stereo.wav"'
  say name~left(28) 'screech bursts removed' nbursts' | C lag' lag 'ms; after alignment per 1 s (ms):'segs
end
s~close
exit 0
envLag: procedure expose prov w
  use arg a, b, maxMs
  x=prov~envelope(a,w'/ac_ea.env',8,0,0); x=prov~envelope(b,w'/ac_eb.env',8,0,0)
  r=prov~xcorr(w'/ac_ea.env',w'/ac_eb.env',-maxMs,maxMs,1,1); best=-9; bi=1
  do i=1 to r['SCORES']~items; if r['SCORES'][i]>best then do; best=r['SCORES'][i]; bi=i; end; end
  return r['LAGS'][bi]
wav: procedure
  use arg f, out
  address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'f'" -af "alimiter=limit=0.89:level=disabled" -c:a pcm_s16le "'out'"'
  return
cut: procedure
  use arg inF, startSample, n, outF
  i=.stream~new(inF); i~open('READ'); d=i~charin(startSample*4+1,n*4); i~close
  o=.stream~new(outF); o~open('WRITE REPLACE'); o~charout(d); o~close
  return
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
