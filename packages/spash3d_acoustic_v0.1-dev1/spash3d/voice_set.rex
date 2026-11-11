/* voice_set.rex -- listening versions of a weak voice: baseline vs enhancer + aggressive AGC vs pitch-lowered.
 * Architecture: Tom Dyer (5 Nov 2026: more aggressive; add a lower-pitch version).  Coding: Claude (Opus 5.5).
 * Per item, the context window (clip +- ctx s) is processed whole, then the clip is cut.
 *   A_baseline   200-3600 Hz, +22 dB fixed, -1 dBFS limiter            (Tom's earlier listening chain)
 *   B_enh_agc    adaptive enhancer (256, 3 s, 0.98, over 2, floor 0.1) then speech AGC (target -16 dBFS,
 *                up to +36 dB, 10/400 ms, gate 6 dB over the 20th-percentile floor, -1 dBFS look-ahead limiter)
 *   C_lower4     enhancer, pitch -4 semitones (same duration), then the same AGC
 *   D_lower7     enhancer, pitch -7 semitones (same duration), then the same AGC
 * items file: name<TAB>FD|FC|path.f32<TAB>start (hh:mm:ss.sss chain time, or seconds into the file)<TAB>durSec
 * usage: voice_set.rex itemsTsv outDir [ctxSec]
 */
numeric digits 16
parse arg itemsF outDir ctx .
if ctx='' then ctx=20
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS'); work=value('SPASH_WORK',,'ENVIRONMENT')
s=.stream~new(itemsF); s~open('READ')
do while s~lines>0
  l=s~linein; if l='' | l~left(1)='#' then iterate
  parse var l name '09'x src '09'x st '09'x dur
  cx=work'/vs_ctx.f32'
  if src='FD' | src='FC' then do
    parse var st hh ':' mm ':' ss; t=hh*3600+mm*60+ss
    pre=min(ctx,t-ch[src]~startSec); ch[src]~writeWindow(t-pre,(pre+dur+ctx)*8000,cx)
  end
  else do
    n=.stream~new(src)~query('size')/4; pre=min(ctx,st)
    len=min(trunc((pre+dur+ctx)*8000), n-trunc((st-pre)*8000)); call cut src, trunc((st-pre)*8000), len, cx
  end
  n=.stream~new(cx)~query('size')/4
  mk=work'/vs.mask.tsv'; q=.stream~new(mk); q~open('WRITE REPLACE'); q~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); q~lineout(0'09'x||n'09'x||200'09'x||3600'09'x||1); q~close
  x=prov~renderSelection(cx,mk,work'/vs_A0.f32',8000,256,64)
  g=RxCalcPower(10,22/20,16); x=prov~renderAlignedMix(work'/vs_A0.f32',work'/vs_A0.f32',work'/vs_A.f32',0,g/2,g/2)
  x=prov~enhance(cx,work'/vs_E.f32',8000,256,64,3,0.98,2,0.1,200,3600)
  x=prov~speechAgc(work'/vs_E.f32',work'/vs_B.f32',8000,-16,36,10,400,6,-1)
  /* pitch first, then the same AGC, so every version is level-matched by the AGC */
  x=prov~pitchShift(work'/vs_E.f32',work'/vs_Ep4.f32',8000,-4); x=prov~speechAgc(work'/vs_Ep4.f32',work'/vs_C.f32',8000,-16,36,10,400,6,-1)
  x=prov~pitchShift(work'/vs_E.f32',work'/vs_Ep7.f32',8000,-7); x=prov~speechAgc(work'/vs_Ep7.f32',work'/vs_D.f32',8000,-16,36,10,400,6,-1)
  do v over .array~of('A_baseline|A','B_enh_agc|B','C_lower4|C','D_lower7|D')
    parse var v lab '|' f
    call cut work'/vs_'f'.f32', trunc(pre*8000), trunc(dur*8000), work'/vs_cut.f32'
    address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'work'/vs_cut.f32" -af "alimiter=limit=0.89:level=disabled" -c:a pcm_s16le "'outDir'/'name'_'lab'.wav"'
    m=prov~measure(work'/vs_cut.f32',work'/vs_cut.f32')
    say name~left(28) lab~left(11) 'rms' format(20*RxCalcLog10(max(m~rmsA,1e-12),16),,1)~right(6) 'dBFS  peak' format(20*RxCalcLog10(max(m~peakA,1e-12),16),,1)~right(6) 'dBFS'
  end
end
s~close
exit 0
cut: procedure
  use arg inF, startSample, n, outF
  i=.stream~new(inF); i~open('READ'); d=i~charin(startSample*4+1,n*4); i~close
  o=.stream~new(outF); o~open('WRITE REPLACE'); o~charout(d); o~close
  return
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
