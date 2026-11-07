/* ab_batch.rex -- blind A/B listening pairs: band-limited original vs adaptive enhancer, loudness-matched.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Each item: a context window (clip +- ctx s) is processed whole so the noise tracker has the background,
 * then the clip is cut.  Both versions: 200-3600 Hz.  Version E: native enhance (fft, noiseWin, alpha, over, gmin).
 * Loudness match: both scaled to the same RMS (target -24 dBFS), then -1 dBFS limiter on export.
 * Which of X/Y is the enhanced one is seeded-random; the key goes to keyTsv, not into the clip folder.
 * items file lines: name<TAB>source<TAB>startSec<TAB>durSec
 *   source = FD | FC (chain time hh:mm:ss.sss in startSec) or a path to an 8 kHz f32 file (startSec = offset s)
 * usage: ab_batch.rex itemsTsv outDir keyTsv seed fft noiseWin alpha over gmin [ctxSec]
 */
numeric digits 16
parse arg itemsF outDir keyF seed fs nwin al ov gm ctx .
if ctx='' then ctx=20
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS'); work=value('SPASH_WORK',,'ENVIRONMENT')
call random ,,seed
k=.stream~new(keyF); k~open('WRITE REPLACE'); k~lineout('item'||'09'x||'X'||'09'x||'Y'||'09'x||'settings=ENH:'fs':'nwin':'al':'ov':'gm)
s=.stream~new(itemsF); s~open('READ')
do while s~lines>0
  l=s~linein; if l='' | l~left(1)='#' then iterate
  parse var l name '09'x src '09'x st '09'x dur
  cx=work'/ab_ctx.f32'
  if src='FD' | src='FC' then do
    parse var st hh ':' mm ':' ss; t=hh*3600+mm*60+ss
    pre=min(ctx,t-ch[src]~startSec); ch[src]~writeWindow(t-pre,(pre+dur+ctx)*8000,cx)
  end
  else do
    pre=min(ctx,st); n=.stream~new(src)~query('size')/4
    len=min(trunc((pre+dur+ctx)*8000), n-trunc((st-pre)*8000)); call cut src, trunc((st-pre)*8000), len, cx
  end
  n=.stream~new(cx)~query('size')/4
  mk=work'/ab.mask.tsv'; q=.stream~new(mk); q~open('WRITE REPLACE'); q~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); q~lineout(0'09'x||n'09'x||200'09'x||3600'09'x||1); q~close
  x=prov~renderSelection(cx,mk,work'/ab_O.f32',8000,256,64)
  x=prov~enhance(cx,work'/ab_E.f32',8000,fs,fs/4,nwin,al,ov,gm,200,3600)
  ver=.directory~new
  do v over .array~of('O','E')
    call cut work'/ab_'v'.f32', trunc(pre*8000), trunc(dur*8000), work'/ab_'v'c.f32'
    r=prov~measure(work'/ab_'v'c.f32',work'/ab_'v'c.f32')~rmsA
    g=RxCalcPower(10,-24/20,16)/max(r,1e-9)
    x=prov~renderAlignedMix(work'/ab_'v'c.f32',work'/ab_'v'c.f32',work'/ab_'v'g.f32',0,g/2,g/2)
    ver[v]=work'/ab_'v'g.f32'
  end
  if random(0,1)=1 then do; xv='E'; yv='O'; end; else do; xv='O'; yv='E'; end
  call export ver[xv], outDir'/'name'_X.wav'; call export ver[yv], outDir'/'name'_Y.wav'
  k~lineout(name'09'x||xv'09'x||yv)
end
s~close; k~close
say 'pairs written to' outDir
exit 0
export: procedure
  use arg f, w
  address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'f'" -af "alimiter=limit=0.89:level=disabled" -c:a pcm_s16le "'w'"'
  return
cut: procedure
  use arg inF, startSample, n, outF
  i=.stream~new(inF); i~open('READ'); d=i~charin(startSample*4+1,n*4); i~close
  o=.stream~new(outF); o~open('WRITE REPLACE'); o~charout(d); o~close
  return
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
