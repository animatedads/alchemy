/* enh_bench.rex -- score speech enhancers against a clean reference voice mixed with real recording noise.
 * Architecture: Tom Dyer (clean phone-call reference poi1 supplied 31 Oct 2026).  Coding: Claude (Opus 5.5).
 * Reference: 15 s silence + poi1 (5.1 s, clean phone-call voice) + 1 s silence, so every method has 15 s of
 *   noise-only lead-in to learn the background, as it would inside a long recording.
 * Noise: nNoise random 21.1 s windows from FD and from FC (seeded), the real background incl. distant talk.
 * Mix: speech-band (200-3600 Hz) RMS of poi1 / speech-band RMS of the noise at each SNR in snrList.  All native Audio V9 primitives.
 * Methods: RAW (mix, band 200-3600 only), STAT (current stationary suppression, tom_chain settings),
 *   ENH:<fft>:<noiseWin>:<alpha>:<over>:<gmin> (new adaptive enhancer).
 * Scores (native compare vs reference, active frames): SNR_DB, SEGSNR_DB, LSD_DB (lower is better).
 * usage: enh_bench.rex outTsv seed nNoise snr,snr,... method,method,...
 */
numeric digits 16
parse arg outF seed nNoise snrList methods .
snrList=snrList~changestr(',',' '); methods=methods~changestr(',',' ')
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS'); work=value('SPASH_WORK',,'ENVIRONMENT')
poi=value('SPASH_PCM',,'ENVIRONMENT')'/poi1.f32'
pn=.stream~new(poi)~query('size')/4
lead=15*8000; tail=8000; total=lead+pn+tail
ref=work'/eb_ref.f32'
z=.stream~new(ref); z~open('WRITE REPLACE'); z~charout(copies('00000000'x,lead))
i=.stream~new(poi); i~open('READ'); z~charout(i~charin(1,pn*4)); i~close
z~charout(copies('00000000'x,tail)); z~close
mk=work'/eb.mask.tsv'; q=.stream~new(mk); q~open('WRITE REPLACE'); q~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); q~lineout(0'09'x||total'09'x||200'09'x||3600'09'x||1); q~close
q=.stream~new(work'/eb.maskN.tsv'); q~open('WRITE REPLACE'); q~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); q~lineout(0'09'x||12*8000'09'x||200'09'x||3600'09'x||1); q~close
/* SNR is set in the speech band 200-3600 Hz: the recordings' low-frequency hum/wind/rumble does not mask speech */
x=prov~renderSelection(poi,mk,work'/eb_poi_band.f32',8000,256,64); sp=prov~measure(work'/eb_poi_band.f32',work'/eb_poi_band.f32')~rmsA
/* noise windows */
call random ,,seed
nw=.array~new
do feed over .array~of('FD','FC')
  do k=1 to nNoise
    t0=ch[feed]~startSec+30; t1=ch[feed]~endSec-60
    t=t0+(random(0,99999)/99999)*(t1-t0); t=trunc(t*1000)/1000
    f=work'/eb_noise_'feed||k'.f32'; ch[feed]~writeWindow(t,total,f)
    nw~append(feed'|'sec2hms(t)'|'f)
  end
end
o=.stream~new(outF); o~open('WRITE REPLACE')
o~lineout('noise'||'09'x||'noise_time'||'09'x||'snr_in_db'||'09'x||'method'||'09'x||'NOISE_REMOVED_DB'||'09'x||'SPEECH_SNR_DB'||'09'x||'SPEECH_SEGSNR_DB'||'09'x||'SPEECH_LSD_DB')
/* regions: noise-only = 3..15 s (after a 3 s warm-up); speech = the poi1 span */
refS=work'/eb_refS.f32'; call cut ref, lead, pn, refS
do w over nw
  parse var w feed '|' nt '|' nf
  x=prov~renderSelection(nf,mk,work'/eb_nband.f32',8000,256,64); nr=prov~measure(work'/eb_nband.f32',work'/eb_nband.f32')~rmsA
  do snr over snrList~space~makeArray(' ')
    gb=sp/(nr*RxCalcPower(10,snr/20,16))
    mix=work'/eb_mix.f32'; x=prov~renderAlignedMix(ref,nf,mix,0,1,gb)
    do m over methods~space~makeArray(' ')
      out=work'/eb_out.f32'
      select
        when m='RAW' then do
          x=prov~renderSelection(mix,mk,out,8000,256,64)
        end
        when m='STAT' then x=prov~suppressStationary(mix,out,8000,1024,256,50,1.5,0.05,250,3400)
        otherwise do
          parse var m 'ENH:' fs ':' nwin ':' al ':' ov ':' gm
          x=prov~enhance(mix,out,8000,fs,fs/4,nwin,al,ov,gm,200,3600)
        end
      end
      call cut mix, 3*8000, 12*8000, work'/eb_mixN.f32'; call cut out, 3*8000, 12*8000, work'/eb_outN.f32'
      x=prov~renderSelection(work'/eb_mixN.f32',work'/eb.maskN.tsv',work'/eb_mixNb.f32',8000,256,64)
      ri=prov~measure(work'/eb_mixNb.f32',work'/eb_mixNb.f32')~rmsA; ro=prov~measure(work'/eb_outN.f32',work'/eb_outN.f32')~rmsA
      nrd=20*RxCalcLog10(ri/max(ro,1e-12),16)
      call cut out, lead, pn, work'/eb_outS.f32'
      s=prov~compare(refS,work'/eb_outS.f32',8000,256,200,3600)
      line=feed'09'x||nt'09'x||snr'09'x||m'09'x||format(nrd,,2)'09'x||format(s['SNR_DB'],,2)'09'x||format(s['SEGSNR_DB'],,2)'09'x||format(s['LSD_DB'],,2)
      o~lineout(line)
    end
  end
end
o~close
say 'done' nw~items 'noise windows'
exit 0
cut: procedure
  use arg inF, startSample, n, outF
  i=.stream~new(inF); i~open('READ'); d=i~charin(startSample*4+1,n*4); i~close
  o=.stream~new(outF); o~open('WRITE REPLACE'); o~charout(d); o~close
  return
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
