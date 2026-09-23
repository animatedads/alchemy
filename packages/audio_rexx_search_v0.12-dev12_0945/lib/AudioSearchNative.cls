/* AudioSearchNative.cls - ooRexx semantic wrapper over the native search kernel. */
::class AudioSearchNativeContext public
::method init
  expose lib ctx
  use strict arg bridgePath, sourcePath, companionPath, corpusPath
  lib=.foreign~load(bridgePath)
  ctx=lib~context_new_corpus(sourcePath,companionPath,corpusPath)
  if ctx==.nil then raise syntax 88.900 array('native audio search context could not be created')
::method sampleRate
  expose lib ctx
  return lib~context_sample_rate(ctx)
::method duration
  expose lib ctx
  return lib~context_duration(ctx)
::method alignment
  expose lib ctx
  st=lib~struct('as_alignment')
  rc=lib~context_alignment(ctx,st)
  if rc<>0 then do; st~close; raise syntax 88.900 array('native alignment failed',rc); end
  d=.directory~new
  do k over .array~of('offset_sec','drift_ppm','correlation','offset_min_sec','offset_max_sec','nominal_offset_sec'); d[k]=st~get(k); end
  st~close
  return d
::method evaluate
  expose lib ctx
  use strict arg config
  p=self~params(config); st=lib~struct('as_stats')
  rc=lib~evaluate(ctx,p,st)
  if rc<>0 then do; p~close; st~close; raise syntax 88.900 array('native candidate evaluation failed',rc); end
  d=.directory~new
  do k over .array~of('global_distance','window_median_distance','window_p25_distance','temporal_distance','silence_fraction','post_limiter_clip_fraction','pre_limiter_over_fraction','pre_filter_peak','pcm_hash64'); d[k]=st~get(k); end
  p~close; st~close
  score=.35*d['global_distance']+.40*d['window_median_distance']+.10*d['window_p25_distance']+.15*d['temporal_distance']+18*d['pre_limiter_over_fraction']+40*d['post_limiter_clip_fraction']
  if d['silence_fraction']<.002 then score=score+(.002-d['silence_fraction'])*30
  d['score']=score
  return d
::method render
  expose lib ctx
  use strict arg config, path
  p=self~params(config); rc=lib~render(ctx,p,path); p~close
  if rc<>0 then raise syntax 88.900 array('native candidate render failed',rc,path)
  return path
::method rmsDb
  expose lib ctx
  use strict arg config
  p=self~params(config); v=lib~output_rms_db(ctx,p); p~close
  return v
::method evaluateAdditiveMix
  expose lib ctx
  use strict arg primaryConfig, residualConfig, primaryGain=1, residualGain=1
  pa=self~params(primaryConfig); pb=self~params(residualConfig); st=lib~struct('as_stats')
  rc=lib~evaluate_additive_mix(ctx,pa,pb,primaryGain,residualGain,st)
  if rc<>0 then do; pa~close; pb~close; st~close; raise syntax 88.900 array('native additive voice mix evaluation failed',rc); end
  d=.directory~new
  do k over .array~of('global_distance','window_median_distance','window_p25_distance','temporal_distance','silence_fraction','post_limiter_clip_fraction','pre_limiter_over_fraction','pre_filter_peak','pcm_hash64'); d[k]=st~get(k); end
  pa~close; pb~close; st~close
  score=.35*d['global_distance']+.40*d['window_median_distance']+.10*d['window_p25_distance']+.15*d['temporal_distance']+18*d['pre_limiter_over_fraction']+40*d['post_limiter_clip_fraction']
  if d['silence_fraction']<.002 then score=score+(.002-d['silence_fraction'])*30
  d['score']=score
  return d
::method renderAdditiveMix
  expose lib ctx
  use strict arg primaryConfig, residualConfig, path, primaryGain=1, residualGain=1
  pa=self~params(primaryConfig); pb=self~params(residualConfig)
  rc=lib~render_additive_mix(ctx,pa,pb,primaryGain,residualGain,path)
  pa~close; pb~close
  if rc<>0 then raise syntax 88.900 array('native additive voice mix render failed',rc,path)
  return path
::method sharedDiagnostics
  expose lib ctx
  d=.directory~new
  do ms over .array~of(-20,-10,-5,0,5,10,20)
    x=.directory~new; x['alpha']=lib~shared_alpha(ctx,ms); x['correlation']=lib~shared_correlation(ctx,ms); d[ms~string]=x
  end
  return d
::method close
  expose lib ctx
  if ctx<>.nil then do; ctx~close; ctx=.nil; end
  if lib<>.nil then do; lib~close; lib=.nil; end
  return .true
::method params private
  expose lib
  use strict arg c
  p=lib~struct('as_params')
  p~set('gain_db',self~v(c,'gain_db',24)); p~set('highpass_hz',self~v(c,'highpass',50)); p~set('lowpass_hz',self~v(c,'lowpass',3000))
  if c~hasIndex('denoise_nf') then do; if c['denoise_nf']==.nil then p~set('denoise_floor_db',999); else p~set('denoise_floor_db',c['denoise_nf']); end; else p~set('denoise_floor_db',999)
  p~set('echo_delay_ms',self~v(c,'echo_delay_ms',0)); p~set('echo_gain',self~v(c,'echo_gain',0)); p~set('cancel_strength',self~v(c,'cancel_strength',0)); p~set('cancel_tweak_ms',self~v(c,'cancel_tweak_ms',0))
  p~set('compress',self~v(c,'compress',0)); p~set('compress_ratio',self~v(c,'compress_ratio',2)); p~set('compress_threshold_db',self~v(c,'compress_threshold_db',-18))
  p~set('reject_reserved',0)
  do i=1 to 6
    p~set('reject_band'||i||'_lo_hz',0); p~set('reject_band'||i||'_hi_hz',0)
  end
  count=0; bands=self~v(c,'reject_bands','')
  if bands<>'' then do token over bands~makeArray(';')
    token=token~strip
    if token='' then iterate
    parse var token lo '-' hi
    lo=lo~strip; hi=hi~strip
    if lo='' | hi='' then do; p~close; raise syntax 88.900 array('invalid reject band; expected LOW-HIGH Hz',token); end
    if count>=6 then do; p~close; raise syntax 88.900 array('at most six reject bands are supported',bands); end
    lo=lo+0; hi=hi+0
    if lo<0 | hi<=lo then do; p~close; raise syntax 88.900 array('invalid reject band bounds',token); end
    count=count+1
    p~set('reject_band'||count||'_lo_hz',lo); p~set('reject_band'||count||'_hi_hz',hi)
  end
  p~set('reject_band_count',count)
  return p
::method v private
  use strict arg d,k,default
  if d~hasIndex(k) then return d[k]
  return default
::requires 'foreign.cls'
