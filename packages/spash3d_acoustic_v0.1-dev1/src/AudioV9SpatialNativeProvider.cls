/* AudioV9SpatialNativeProvider.cls
 * Foreign Runtime binding for deterministic dual-feed spatial measurements.
 */

::options numeric inherit

::class AudioV9SpatialMeasurement public
::method init
  expose values
  use strict arg text
  values=.directory~new
  fields=self~splitTabs(text~string~strip('T','0A'x))
  if fields~items<2 | fields[1]\='AUDIO_V9_SPATIAL/2' then raise syntax 88.900 array('spatial measurement header missing',text)
  do i=2 to fields~items
    p=fields[i]~pos('=')
    if p<2 then raise syntax 88.900 array('spatial measurement field malformed',fields[i])
    k=fields[i]~substr(1,p-1); v=fields[i]~substr(p+1)
    if values~hasIndex(k) then raise syntax 88.900 array('duplicate spatial measurement field',k)
    values[k]=v
  end
  required=.array~of('SAMPLES','SR','RMS_A','RMS_B','PEAK_A','PEAK_B','CREST_A','CREST_B','RATIO_DB','ENV_LAG_SAMPLES','ENV_LAG_MS','ENV_SCORE','DIRECT_LAG_SAMPLES','DIRECT_LAG_MS','DIRECT_SCORE','DIRECT_COHERENCE','REFINED_LAG_SAMPLES','REFINED_LAG_MS','REFINED_SCORE','REFINED_COHERENCE')
  do k over required; if \values~hasIndex(k) then raise syntax 88.900 array('spatial measurement field missing',k); end
::method at
  expose values
  use strict arg key
  k=key~string~upper
  if \values~hasIndex(k) then raise syntax 88.900 array('unknown spatial measurement field',k)
  return values[k]+0
::method samples; return self~at('SAMPLES')
::method sampleRate; return self~at('SR')
::method rmsA; return self~at('RMS_A')
::method rmsB; return self~at('RMS_B')
::method peakA; return self~at('PEAK_A')
::method peakB; return self~at('PEAK_B')
::method crestA; return self~at('CREST_A')
::method crestB; return self~at('CREST_B')
::method ratioDb; return self~at('RATIO_DB')
::method envelopeLagSamples; return self~at('ENV_LAG_SAMPLES')
::method envelopeLagMs; return self~at('ENV_LAG_MS')
::method envelopeScore; return self~at('ENV_SCORE')
::method directLagSamples; return self~at('DIRECT_LAG_SAMPLES')
::method directLagMs; return self~at('DIRECT_LAG_MS')
::method directScore; return self~at('DIRECT_SCORE')
::method directCoherence; return self~at('DIRECT_COHERENCE')
::method refinedLagSamples; return self~at('REFINED_LAG_SAMPLES')
::method refinedLagMs; return self~at('REFINED_LAG_MS')
::method refinedScore; return self~at('REFINED_SCORE')
::method refinedCoherence; return self~at('REFINED_COHERENCE')
::method impulseDominated
  threshold=6.0
  return self~crestA>=threshold | self~crestB>=threshold
::method canonicalText
  return 'AUDIO_V9_SPATIAL_MEASUREMENT/2|samples='||self~samples||'|sr='||self~sampleRate||'|envLagMs='||self~envelopeLagMs||'|directLagMs='||self~directLagMs||'|refinedLagMs='||self~refinedLagMs||'|envScore='||self~envelopeScore||'|directScore='||self~directScore||'|refinedScore='||self~refinedScore||'|directCoherence='||self~directCoherence||'|refinedCoherence='||self~refinedCoherence||'|ratioDb='||self~ratioDb
::method splitTabs private
  use strict arg line
  out=.array~new; rest=line
  do forever
    p=rest~pos('09'x)
    if p=0 then do; out~append(rest); leave; end
    out~append(rest~substr(1,p-1)); rest=rest~substr(p+1)
  end
  return out

::class AudioV9SpatialScanRow public
::method init
  expose index startSample startMs measurement
  use strict arg indexValue,startSampleValue,startMsValue,measurementValue
  index=indexValue+0; startSample=startSampleValue+0; startMs=startMsValue+0; measurement=measurementValue
::method index; expose index; return index
::method startSample; expose startSample; return startSample
::method startMs; expose startMs; return startMs
::method measurement; expose measurement; return measurement
::method canonicalText
  expose index startSample startMs measurement
  return 'AUDIO_V9_SPATIAL_SCAN_ROW/1|index='||index||'|startSample='||startSample||'|startMs='||startMs||'|'||measurement~canonicalText

::class AudioV9SpatialScan public
::method init
  expose header rows
  use strict arg text
  rows=.array~new; remaining=text~string; first=.true; header=''
  do while remaining<>''
    p=remaining~pos('0A'x)
    if p=0 then do; line=remaining; remaining=''; end
    else do; line=remaining~substr(1,p-1); remaining=remaining~substr(p+1); end
    if line='' then iterate
    if first then do
      first=.false; if line~left(24)\='AUDIO_V9_SPATIAL_SCAN/1' then raise syntax 88.900 array('spatial scan header missing')
      header=line; iterate
    end
    fields=self~splitTabs(line)
    if fields~items<5 | fields[1]\='W' then raise syntax 88.900 array('spatial scan row malformed',line)
    prefix='AUDIO_V9_SPATIAL/2'
    do i=5 to fields~items; prefix=prefix||'09'x||fields[i]; end
    rows~append(.AudioV9SpatialScanRow~new(fields[2],fields[3],fields[4],.AudioV9SpatialMeasurement~new(prefix)))
  end
  if header='' then raise syntax 88.900 array('spatial scan empty')
::method rows; expose rows; return rows~copy
::method size; expose rows; return rows~items
::method header; expose header; return header
::method splitTabs private
  use strict arg line
  out=.array~new; rest=line
  do forever
    p=rest~pos('09'x)
    if p=0 then do; out~append(rest); leave; end
    out~append(rest~substr(1,p-1)); rest=rest~substr(p+1)
  end
  return out

::class AudioV9SpatialNativeProvider public
::method init
  expose lib bridgePath
  use strict arg bridgePathValue
  bridgePath=bridgePathValue~string
  lib=.foreign~load(bridgePath)
::method measure
  expose lib
  use strict arg aPath,bPath,sampleRate=8000,maxEnvelopeMs=500,maxDirectResidualMs=25
  text=lib~measure_tsv(aPath~string,bPath~string,sampleRate,maxEnvelopeMs,maxDirectResidualMs)
  if text==.nil then raise syntax 88.900 array('native spatial measurement failed',lib~last_error)
  return .AudioV9SpatialMeasurement~new(text)
::method scan
  expose lib
  use strict arg aPath,bPath,sampleRate=8000,windowMs=8000,stepMs=4000,maxEnvelopeMs=500,maxDirectResidualMs=25
  text=lib~scan_tsv(aPath~string,bPath~string,sampleRate,windowMs,stepMs,maxEnvelopeMs,maxDirectResidualMs)
  if text==.nil then raise syntax 88.900 array('native spatial scan failed',lib~last_error)
  return .AudioV9SpatialScan~new(text)
::method scanLoudEchoEvents
  expose lib
  use strict arg aPath,bPath,outPath,sampleRate=8000,minPeak=0.5,minRatio=6,refractoryMs=120,templateMs=6,radiusMs=2,startSerial=0
  rc=lib~loud_echo_scan_tsv(aPath~string,bPath~string,outPath~string,sampleRate,minPeak,minRatio,refractoryMs,templateMs,radiusMs,startSerial)
  if rc<>0 then raise syntax 88.900 array('native loud echo scan failed',lib~last_error,rc)
  return outPath

::method scanLoudEchoEventsV2
  expose lib
  use strict arg aPath,bPath,outPath,sampleRate=8000,minAbsPeak=0.001,minRatio=6,refractoryMs=120,templateMs=6,radiusMs=4,startSerial=0,strongScore=0.70
  rc=lib~loud_echo_scan_v2_tsv(aPath~string,bPath~string,outPath~string,sampleRate,minAbsPeak,minRatio,refractoryMs,templateMs,radiusMs,startSerial,strongScore)
  if rc<>0 then raise syntax 88.900 array('native loud echo v2 scan failed',lib~last_error,rc)
  return outPath

::method scanLoudEchoEventsV3
  expose lib
  use strict arg aPath,bPath,outPath,sampleRate=8000,minAbsPeak=0.001,minRatio=6,refractoryMs=120,templateMs=6,radiusMs=4,startSerial=0,strongScore=0.70,globalMinMs=6,globalMaxMs=80,globalSeparationMs=3
  rc=lib~loud_echo_scan_v3_tsv(aPath~string,bPath~string,outPath~string,sampleRate,minAbsPeak,minRatio,refractoryMs,templateMs,radiusMs,startSerial,strongScore,globalMinMs,globalMaxMs,globalSeparationMs)
  if rc<>0 then raise syntax 88.900 array('native loud echo v3 scan failed',lib~last_error,rc)
  return outPath

::method renderAlignedMix
  expose lib
  use strict arg aPath,bPath,outPath,lagBSamples,weightA=0.5,weightB=0.5
  rc=lib~render_mix_f32(aPath~string,bPath~string,outPath~string,lagBSamples,weightA,weightB)
  if rc<>0 then raise syntax 88.900 array('native spatial render failed',lib~last_error,rc)
  return outPath
::method renderPlan
  expose lib
  use strict arg aPath,bPath,planPath,outPath,fadeSamples=800
  rc=lib~render_plan_f32(aPath~string,bPath~string,planPath~string,outPath~string,fadeSamples)
  if rc<>0 then raise syntax 88.900 array('native spatial plan render failed',lib~last_error,rc)
  return outPath
::method renderMask
  expose lib
  use strict arg inputPath,maskPath,outPath,sampleRate=8000,fftSize=256,hopSamples=64
  rc=lib~render_mask_f32(inputPath~string,maskPath~string,outPath~string,sampleRate,fftSize,hopSamples)
  if rc<>0 then raise syntax 88.900 array('native time-frequency mask render failed',lib~last_error,rc)
  return outPath

::method renderSelection
  expose lib
  use strict arg inputPath,maskPath,outPath,sampleRate=8000,fftSize=256,hopSamples=64
  rc=lib~render_select_f32(inputPath~string,maskPath~string,outPath~string,sampleRate,fftSize,hopSamples)
  if rc<>0 then raise syntax 88.900 array('native source selection render failed',lib~last_error,rc)
  return outPath
/* SPASH 3D additions (proposed patch). Coding: Claude (Opus 5.5), 31 Oct 2026. */
::method envelope
  expose lib
  use strict arg inputPath,outPath,binSamples=80,logDb=1,detrendBins=0
  rc=lib~envelope_f32(inputPath~string,outPath~string,binSamples,logDb,detrendBins)
  if rc<=0 then raise syntax 88.900 array('native envelope failed',lib~last_error,rc)
  return rc
/* returns an array of 'lag score' strings plus header via .directory: LAGS, SCORES (arrays) */
::method xcorr
  expose lib
  use strict arg aPath,bPath,minLag,maxLag,lagStep=1,stride=1
  text=lib~xcorr_tsv(aPath~string,bPath~string,minLag,maxLag,lagStep,stride)
  if text==.nil then raise syntax 88.900 array('native xcorr failed',lib~last_error)
  r=.directory~new; lags=.array~new; scores=.array~new
  lines=text~makeArray('0a'x)
  do i=2 to lines~items
    l=lines[i]; if l='' then iterate
    parse var l lg '09'x sc
    lags~append(lg+0); scores~append(sc+0)
  end
  r['HEADER']=lines[1]; r['LAGS']=lags; r['SCORES']=scores
  return r
/* GCC-PHAT: array of directories LAG (samples, fractional), VALUE, SHARP (peak/RMS); positive => B later */
::method gccPhat
  expose lib
  use strict arg aPath,bPath,sampleRate=8000,maxLag=240,loHz=300,hiHz=3400
  text=lib~gccphat_tsv(aPath~string,bPath~string,sampleRate,maxLag,loHz,hiHz)
  if text==.nil then raise syntax 88.900 array('native gcc-phat failed',lib~last_error)
  out=.array~new; lines=text~makeArray('0a'x)
  do i=2 to lines~items
    l=lines[i]; if l='' then iterate
    parse var l lg '09'x v '09'x sh
    d=.directory~new; d['LAG']=lg+0; d['VALUE']=v+0; d['SHARP']=sh+0; out~append(d)
  end
  return out
/* Template scan: array of directories OFFSET, SCORE, Z (top non-overlapping matches) */
::method templateScan
  expose lib
  use strict arg longPath,templatePath,step=1,topK=5
  text=lib~template_scan_tsv(longPath~string,templatePath~string,step,topK)
  if text==.nil then raise syntax 88.900 array('native template scan failed',lib~last_error)
  out=.array~new; lines=text~makeArray('0a'x)
  do i=2 to lines~items
    l=lines[i]; if l='' then iterate
    parse var l o '09'x s '09'x z
    d=.directory~new; d['OFFSET']=o+0; d['SCORE']=s+0; d['Z']=z+0; out~append(d)
  end
  return out
/* Stationary suppression (klaxon/hum/whine): per-bin percentile noise estimate, Wiener-style gain, speech band. */
::method suppressStationary
  expose lib
  use strict arg inputPath,outPath,sampleRate=8000,fftSize=1024,hop=256,percentile=50,over=1.5,floorGain=0.05,loHz=250,hiHz=3400
  rc=lib~stationary_suppress_f32(inputPath~string,outPath~string,sampleRate,fftSize,hop,percentile,over,floorGain,loHz,hiHz)
  if rc<>0 then raise syntax 88.900 array('native stationary suppression failed',lib~last_error,rc)
  return outPath
/* Adaptive speech enhancer: minimum-statistics noise tracking, decision-directed a priori SNR, MMSE-LSA gain.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026. */
::method enhance
  expose lib
  use strict arg inputPath,outPath,sampleRate=8000,fftSize=256,hop=64,noiseWinS=1.5,alphaDD=0.98,over=1.0,gMin=0.1,loHz=200,hiHz=3600
  rc=lib~enhance_f32(inputPath~string,outPath~string,sampleRate,fftSize,hop,noiseWinS,alphaDD,over,gMin,loHz,hiHz)
  if rc<>0 then raise syntax 88.900 array('native enhance failed',lib~last_error,rc)
  return outPath
/* Score a processed signal against a clean reference: directory SNR_DB, SEGSNR_DB, LSD_DB, ACTIVE, GAIN */
::method compare
  expose lib
  use strict arg refPath,testPath,sampleRate=8000,frame=256,loHz=200,hiHz=3600
  text=lib~compare_tsv(refPath~string,testPath~string,sampleRate,frame,loHz,hiHz)
  if text==.nil then raise syntax 88.900 array('native compare failed',lib~last_error)
  r=.directory~new; lines=text~makeArray('0a'x)
  do i=2 to lines~items; l=lines[i]; if l='' then iterate; parse var l k '09'x v; r[k]=v; end
  return r
/* Aggressive speech AGC + look-ahead limiter.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026. */
::method speechAgc
  expose lib
  use strict arg inputPath,outPath,sampleRate=8000,targetDb=(-20),maxGainDb=36,attackMs=10,releaseMs=400,gateDb=6,limitDb=(-1)
  rc=lib~speech_agc_f32(inputPath~string,outPath~string,sampleRate,targetDb,maxGainDb,attackMs,releaseMs,gateDb,limitDb)
  if rc<>0 then raise syntax 88.900 array('native speech agc failed',lib~last_error,rc)
  return outPath
/* Pitch shift keeping duration (WSOLA + resample); semitones<0 lowers.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5). */
::method pitchShift
  expose lib
  use strict arg inputPath,outPath,sampleRate=8000,semitones=(-4),toleranceMs=2.5
  rc=lib~pitch_f32(inputPath~string,outPath~string,sampleRate,semitones,toleranceMs)
  if rc<>0 then raise syntax 88.900 array('native pitch shift failed',lib~last_error,rc)
  return outPath
/* Reflection (rake) combiner: taps TSV of advance_samples<TAB>weight.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5). */
::method rake
  expose lib
  use strict arg inputPath,outPath,tapsTsv
  rc=lib~rake_f32(inputPath~string,outPath~string,tapsTsv~string)
  if rc<>0 then raise syntax 88.900 array('native rake failed',lib~last_error,rc)
  return outPath
/* YIN fundamental frequency per frame to TSV (time_s f0_hz aperiodicity rms_db).  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5). */
::method yinF0
  expose lib
  use strict arg inputPath,outTsv,sampleRate=8000,frame=320,hop=80,fMin=60,fMax=500,thresh=0.15
  rc=lib~yin_f0(inputPath~string,outTsv~string,sampleRate,frame,hop,fMin,fMax,thresh)
  if rc<>0 then raise syntax 88.900 array('native yin failed',lib~last_error,rc)
  return outTsv
/* Tonal burst (bird screech) suppression: returns number of bursts; events TSV start_s end_s length_ms peak_ratio_db dominant_hz.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026. */
::method suppressTonalBursts
  expose lib
  use strict arg inputPath,outPath,eventsTsv,sampleRate=8000,fftSize=512,hop=128,loHz=1900,hiHz=3950,ratioDb=6,flatMax=0.12,minMs=60,maxMs=600,guardMs=48,peakDb=6
  rc=lib~tonal_burst_suppress_f32(inputPath~string,outPath~string,eventsTsv~string,sampleRate,fftSize,hop,loHz,hiHz,ratioDb,flatMax,minMs,maxMs,guardMs,peakDb)
  if rc<0 then raise syntax 88.900 array('native tonal burst suppression failed',lib~last_error,rc)
  return rc
/* Per-frame voice features TSV (time f0 aperiodicity rms s1..sN); returns frame count.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5). */
::method voiceFeatures
  expose lib
  use strict arg inputPath,outTsv,sampleRate=8000,frame=320,hop=80,fMin=60,fMax=500,thresh=0.25,nBands=32
  rc=lib~voice_features(inputPath~string,outTsv~string,sampleRate,frame,hop,fMin,fMax,thresh,nBands)
  if rc<0 then raise syntax 88.900 array('native voice features failed',lib~last_error,rc)
  return rc
/* Per-voice-profile mask render.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026. */
::method voiceMask
  expose lib
  use strict arg inputPath,outPath,framesTsv,shapeTsv,sampleRate=8000,fftSize=512,hop=128,floorDb=(-20),widthHz=25,smoothMs=40,loHz=100,hiHz=3800,shapeMix=0.25
  rc=lib~voice_mask_f32(inputPath~string,outPath~string,framesTsv~string,shapeTsv~string,sampleRate,fftSize,hop,floorDb,widthHz,smoothMs,loHz,hiHz,shapeMix)
  if rc<>0 then raise syntax 88.900 array('native voice mask failed',lib~last_error,rc)
  return outPath
/* One voice's pitch inside a window by harmonic contrast (overlap-robust); TSV time f0 contrast.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5). */
::method harmonicF0
  expose lib
  use strict arg inputPath,outTsv,sampleRate=8000,fftSize=512,hop=80,loHz=90,hiHz=160,nHarm=20,fMaxHz=2000,minContrast=0.15
  rc=lib~harmonic_f0(inputPath~string,outTsv~string,sampleRate,fftSize,hop,loHz,hiHz,nHarm,fMaxHz,minContrast)
  if rc<0 then raise syntax 88.900 array('native harmonic f0 failed',lib~last_error,rc)
  return rc
/* Union of several voice-profile masks (list file of frames TSVs).  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5). */
::method voiceMaskUnion
  expose lib
  use strict arg inputPath,outPath,listTsv,sampleRate=8000,fftSize=512,hop=128,floorDb=(-14),widthHz=15,smoothMs=40,loHz=100,hiHz=3800
  rc=lib~voice_mask_union_f32(inputPath~string,outPath~string,listTsv~string,sampleRate,fftSize,hop,floorDb,widthHz,smoothMs,loHz,hiHz)
  if rc<>0 then raise syntax 88.900 array('native union mask failed',lib~last_error,rc)
  return outPath
/* spectral smoother for comprehension listening (Tom Dyer, 6 Nov 2026): fills one-frame drop-outs of a hard voice
   mask (held envelope, 20 dB fall over releaseMs), widens comb teeth (+-freqBins at -3 dB/bin), raises bins by at
   most maxFillDb; bweDb < 0 rebuilds 4 kHz..0.9 Nyquist from 2.0-3.6 kHz (needs sampleRate >= 16000). Claude (Opus 5.5) */
::method spectralSmooth
  expose lib
  use strict arg inputPath,outPath,sampleRate=16000,fftSize=512,hop=128,releaseMs=60,freqBins=2,maxFillDb=12,bweDb=0
  rc=lib~spectral_smooth_f32(inputPath~string,outPath~string,sampleRate,fftSize,hop,releaseMs,freqBins,maxFillDb,bweDb)
  if rc<0 then raise syntax 88.900 array('native spectral smooth failed',lib~last_error,rc)
  return rc
/* several simultaneous pitches per frame (overlapping speakers): iterative estimation and cancellation; TSV t_s then
   f0/strength pairs, strongest first.  Tom Dyer (architecture) 6 Nov 2026; Claude (Opus 5.5) */
::method multiF0
  expose lib
  use strict arg inputPath,outTsv,sampleRate=8000,fftSize=1024,hop=80,fMin=75,fMax=500,nHarm=15,maxVoices=4,minRatio=2.0,relFloor=0.25
  rc=lib~multi_f0_f32(inputPath~string,outTsv~string,sampleRate,fftSize,hop,fMin,fMax,nHarm,maxVoices,minRatio,relFloor)
  if rc<0 then raise syntax 88.900 array('native multi f0 failed',lib~last_error,rc)
  return rc
/* SPASH fingerprint blocks: returns array of directories START, RMS, BANDS (array of mean powers) */
::method bandBlocks
  expose lib
  use strict arg inputPath,sampleRate=8000,frame=256,hop=128,blockFrames=10,nBands=22,fMin=80,fMax=3800
  text=lib~band_blocks_tsv(inputPath~string,sampleRate,frame,hop,blockFrames,nBands,fMin,fMax)
  if text==.nil then raise syntax 88.900 array('native band blocks failed',lib~last_error)
  out=.array~new; lines=text~makeArray('0a'x)
  do i=2 to lines~items
    l=lines[i]; if l='' then iterate
    f=l~makeArray('09'x); d=.directory~new; d['START']=f[2]+0; d['RMS']=f[3]+0
    b=.array~new; do k=4 to f~items; b~append(f[k]+0); end
    d['BANDS']=b; out~append(d)
  end
  return out

::requires "foreign.cls"
