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

::requires "foreign.cls"
