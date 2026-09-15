/* AudioForeignPythonProcessing.cls - in-process reference provider for Audio Processing Toolkit v0.21
 *
 * ForeignBuffer inputs cross to Python as memoryviews.  NumPy outputs remain resident
 * and are exposed as ForeignTensor objects for zero-copy chaining.
 */

::class AudioForeignPythonProcessingSession public
::attribute providerId get
::attribute runtimeInfo get

::method init
  expose py providerId runtimeInfo
  use strict arg moduleName='audio_processing_foreign'
  providerId='python.audio.processing.foreign'
  py=.ForeignPython~import(moduleName)
  runtimeInfo=.Directory~new
  runtimeInfo['provider_id']=providerId
  runtimeInfo['provider']='ForeignPython'
  runtimeInfo['python_version']=py~pythonVersion
  runtimeInfo['threading_mode']=py~threadingMode
  runtimeInfo['module']=moduleName
  info=py~runtime_info
  if .ForeignPythonSequenceSupport~isSequence(info) then do
    if info~items>=4 then do
      runtimeInfo['adapter_version']=info[1]
      runtimeInfo['numpy_version']=info[2]
      runtimeInfo['scipy_provider']=info[3]
      runtimeInfo['librosa_version']=info[4]
    end
    .ForeignPythonSequenceSupport~closeIfProxy(info)
  end

::method channelStatistics
  expose py providerId runtimeInfo
  use strict arg inputA, inputB=.nil
  if \self~runtimeMaterial(inputA) then raise syntax 88.900 array('channel statistics inputA must be ForeignBuffer/ForeignTensor')
  if inputB \== .nil then if \self~runtimeMaterial(inputB) then raise syntax 88.900 array('channel statistics inputB must be ForeignBuffer/ForeignTensor')
  if inputB==.nil then raw=py~channel_statistics(inputA)
  else raw=py~channel_statistics(inputA,inputB)
  if \.ForeignPythonSequenceSupport~isSequence(raw) then raise syntax 88.900 array('channel statistics provider returned malformed result')
  if raw~items<4 then raise syntax 88.900 array('channel statistics provider returned incomplete result')
  out=.Array~new
  n=raw[2]
  out~append(.AudioMeasurement~new('rms_a',raw[3],'linear',0,'rms'))
  out~append(.AudioMeasurement~new('peak_a',raw[4],'linear',0,'peak'))
  if raw~items>=7 then do
    corr=raw[7]
    ev=.AudioMathsEvidence~correlation(corr,n,runtimeInfo['numpy_version'])
    out~append(.AudioMeasurement~new('rms_b',raw[5],'linear',0,'rms'))
    out~append(.AudioMeasurement~new('peak_b',raw[6],'linear',0,'peak'))
    out~append(.AudioMeasurement~new('channel_correlation',corr,'pearson-r',0,'pearson-correlation',ev))
  end
  .ForeignPythonSequenceSupport~closeIfProxy(raw)
  return out

::method execute
  expose py providerId runtimeInfo
  use strict arg requestId, spec, config, inputA, sampleRateHz, inputB=.nil
  if \self~runtimeMaterial(inputA) then raise syntax 88.900 array('Audio processing inputA must be ForeignBuffer/ForeignTensor float32 material')
  if inputB \== .nil then if \self~runtimeMaterial(inputB) then raise syntax 88.900 array('Audio processing inputB must be ForeignBuffer/ForeignTensor float32 material')
  id=spec~id
  p=config~parameters
  outputs=.Array~new
  measurements=.Array~new
  warnings=.Array~new

  select
    when id='alignment.gcc_phat' then do
      self~requireB(inputB,id)
      raw=py~gcc_phat(inputA,inputB,.ForeignPython~integer(sampleRateHz),.ForeignPython~float(self~num(p,'max_lag_sec',0.2)))
      result=self~alignmentResult(requestId,spec,config,raw,sampleRateHz,'GCC_PHAT','peak_to_median')
      return result
    end
    when id='alignment.envelope_lag' then do
      self~requireB(inputB,id)
      raw=py~envelope_lag(inputA,inputB,.ForeignPython~integer(sampleRateHz),.ForeignPython~float(self~num(p,'max_lag_sec',0.2)),.ForeignPython~float(self~num(p,'smoothing_sec',0.015)))
      result=self~alignmentResult(requestId,spec,config,raw,sampleRateHz,'ENVELOPE_LAG','normalized_correlation')
      return result
    end
    when id='alignment.cross_ambiguity' then do
      self~requireB(inputB,id)
      raw=py~cross_ambiguity_lag(inputA,inputB,.ForeignPython~integer(sampleRateHz),.ForeignPython~float(self~num(p,'max_delay_sec',0.2)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<4 then raise syntax 88.900 array('cross ambiguity provider returned malformed result')
      lag=raw[2]; score=raw[4]
      shift=.AudioTimeShift~new(lag,sampleRateHz,0,'positive lag follows scipy correlate A,B convention','cross_ambiguity','provider:'||providerId)
      outputs~append(.AudioProcessingOutput~new('shift',.AudioProcessingConstant~OUTPUT_TIME_SHIFT,'',shift))
      measurements~append(.AudioMeasurement~new('cross_ambiguity_peak',score,'correlation',0,'cross_ambiguity'))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    when id='transform.adaptive_spectral_denoise' then do
      raw=py~adaptive_spectral_denoise(inputA,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'noise_percentile',20)),.ForeignPython~float(self~num(p,'floor_scale',1.2)),.ForeignPython~float(self~num(p,'minimum_gain',0.08)))
      outputs~append(self~audioOutput('clean',raw,sampleRateHz))
    end
    when id='mask.phase_coherence_wiener' then do
      self~requireB(inputB,id)
      raw=py~phase_coherence_wiener(inputA,inputB,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~integer(self~num(p,'smoothing_frames',5)),.ForeignPython~float(self~num(p,'floor_gain',0.06)),.ForeignPython~float(self~num(p,'noise_ratio',8)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<3 then raise syntax 88.900 array('phase coherence provider returned malformed result')
      a=raw[1]; b=raw[2]; mask=raw[3]
      outputs~append(self~audioOutput('A_clean',a,sampleRateHz))
      outputs~append(self~audioOutput('B_clean',b,sampleRateHz))
      outputs~append(self~maskOutput('coherence_mask',mask,'TIME_FREQUENCY','phase_coherence_wiener'))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    when id='transform.mvdr.dual' then do
      self~requireB(inputB,id)
      raw=py~mvdr_dual(inputA,inputB,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'diagonal_loading',0.0001)))
      outputs~append(self~audioOutput('beamformed',raw,sampleRateHz))
    end
    when id='transform.clean_spectral_lines' then do
      raw=py~clean_spectral_lines(inputA,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~integer(self~num(p,'iterations',8)),.ForeignPython~float(self~num(p,'gain',0.5)),.ForeignPython~float(self~num(p,'beam_width_bins',2.5)),.ForeignPython~float(self~num(p,'minimum_gain',0.05)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<2 then raise syntax 88.900 array('clean spectral provider returned malformed result')
      audio=raw[1]; mask=raw[2]
      outputs~append(self~audioOutput('clean',audio,sampleRateHz))
      outputs~append(self~maskOutput('spectral_suppression',mask,'FREQUENCY','clean_spectral_lines'))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    when id='mask.echo_persistence' then do
      raw=py~echo_persistence(inputA,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'delay_min_ms',10)),.ForeignPython~float(self~num(p,'delay_max_ms',120)),.ForeignPython~float(self~num(p,'delay_step_ms',10)),.ForeignPython~float(self~num(p,'normalization_sec',2.0)),.ForeignPython~float(self~num(p,'threshold',0.4)),.ForeignPython~float(self~num(p,'slope',8)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<2 then raise syntax 88.900 array('echo persistence provider returned malformed result')
      audio=raw[1]; mask=raw[2]
      outputs~append(self~audioOutput('echo_weighted',audio,sampleRateHz))
      outputs~append(self~maskOutput('echo_persistence_mask',mask,'TIME_FREQUENCY','echo_persistence'))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    when id='transform.eigen_noise_projection' then do
      self~requireB(inputB,id)
      raw=py~eigen_noise_projection(inputA,inputB,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'regularization',0.0000001)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<2 then raise syntax 88.900 array('eigen projection provider returned malformed result')
      a=raw[1]; b=raw[2]
      outputs~append(self~audioOutput('A_projected',a,sampleRateHz))
      outputs~append(self~audioOutput('B_projected',b,sampleRateHz))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    when id='mask.syllabic_modulation' then do
      raw=py~syllabic_modulation_score(inputA,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'low_hz',2)),.ForeignPython~float(self~num(p,'high_hz',8)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<2 then raise syntax 88.900 array('syllabic modulation provider returned malformed result')
      score=raw[1]; weights=raw[2]
      measurements~append(.AudioMeasurement~new('syllabic_modulation_strength',score,'normalized',0,'syllabic_modulation'))
      outputs~append(self~maskOutput('syllabic_weights',weights,'TIME','syllabic_modulation'))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end

    when id='measurement.room_profile' then do
      raw=py~room_profile(inputA,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'min_delay_ms',10)),.ForeignPython~float(self~num(p,'max_delay_ms',150)),.ForeignPython~integer(self~num(p,'max_reflections',6)),.ForeignPython~float(self~num(p,'prominence_ratio',0.05)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<3 then raise syntax 88.900 array('room profile provider returned malformed result')
      delays=self~vectorToArray(raw[1]); strengths=self~vectorToArray(raw[2]); confidence=raw[3]
      profile=.AudioRoomReflectionProfile~new(delays,strengths,confidence,'blind_onset_autocorrelation','provider:'||providerId)
      outputs~append(.AudioProcessingOutput~new('room_profile',.AudioProcessingConstant~OUTPUT_MEASUREMENT,'',profile))
      checks=.Directory~new; checks['reflection_count']=delays~items; checks['confidence']=confidence
      maths=.AudioMathsEvidence~measurement('audio.room.reflection.profile',confidence,'normalized','onset-autocorrelation',runtimeInfo['numpy_version'],'Reflection delays are acoustic evidence; they are not literal room dimensions.',checks,'audio-room-profile')
      measurements~append(.AudioMeasurement~new('room_profile_confidence',confidence,'normalized',confidence,'room_profile',maths))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    when id='measurement.harmonic_product' then do
      raw=py~harmonic_product_measurement(inputA,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~integer(self~num(p,'harmonics',3)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<2 then raise syntax 88.900 array('harmonic product provider returned malformed result')
      score=raw[1]; fmap=raw[2]
      maths=.AudioMathsEvidence~measurement('audio.harmonic_product.concentration',score,'ratio','harmonic-product-spectrum',runtimeInfo['numpy_version'],'Harmonic concentration is supporting evidence, not a speech/speaker proof.')
      measurements~append(.AudioMeasurement~new('harmonic_product_concentration',score,'ratio',0,'harmonic_product',maths))
      outputs~append(self~featureMapOutput('harmonic_product',fmap,'TIME_FREQUENCY','HARMONIC_PRODUCT','harmonic_product'))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    when id='measurement.spectral_tilt' then do
      raw=py~spectral_tilt_measurement(inputA,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'low_hz',100)),.ForeignPython~float(self~num(p,'high_hz',6000)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<2 then raise syntax 88.900 array('spectral tilt provider returned malformed result')
      slope=raw[1]; fit=raw[2]
      maths=.AudioMathsEvidence~measurement('audio.spectral_tilt',slope,'dB/octave','log-spectrum-linear-fit',runtimeInfo['numpy_version'],'Spectral slope is a numerical descriptor; it does not classify speech by itself.')
      attrs=.Directory~new; attrs['fit_r2']=fit
      measurements~append(.AudioMeasurement~new('spectral_tilt',slope,'dB/octave',fit,'spectral_tilt',maths,attrs))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    when id='mask.coherence.multi_domain' then do
      self~requireB(inputB,id)
      raw=py~multi_domain_coherence(inputA,inputB,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'delay_min_ms',10)),.ForeignPython~float(self~num(p,'delay_max_ms',120)),.ForeignPython~float(self~num(p,'delay_step_ms',10)),.ForeignPython~float(self~num(p,'spatial_weight',0.45)),.ForeignPython~float(self~num(p,'wavefront_weight',0.25)),.ForeignPython~float(self~num(p,'echo_weight',0.30)),.ForeignPython~float(self~num(p,'threshold',0.35)),.ForeignPython~float(self~num(p,'slope',12)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<2 then raise syntax 88.900 array('multi-domain coherence provider returned malformed result')
      audio=raw[1]; mask=raw[2]
      outputs~append(self~audioOutput('fused_clean',audio,sampleRateHz))
      outputs~append(self~maskOutput('multi_domain_mask',mask,'TIME_FREQUENCY','multi_domain_coherence'))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    when id='transform.log_likelihood_fusion' then do
      self~requireB(inputB,id)
      raw=py~log_likelihood_fusion(inputA,inputB,.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~integer(self~num(p,'harmonics',3)))
      if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<2 then raise syntax 88.900 array('log likelihood fusion provider returned malformed result')
      audio=raw[1]; mask=raw[2]
      outputs~append(self~audioOutput('fused',audio,sampleRateHz))
      outputs~append(self~maskOutput('feed_weight',mask,'TIME_FREQUENCY','log_likelihood_fusion'))
      .ForeignPythonSequenceSupport~closeIfProxy(raw)
    end
    otherwise raise syntax 88.900 array('ForeignPython audio processing provider does not implement ' || id)
  end

  return .AudioProcessingResult~new(requestId,id,config~id,'COMPLETED',outputs,measurements,runtimeInfo,warnings)

::method alignmentResult private
  expose providerId runtimeInfo
  use strict arg requestId,spec,config,raw,sampleRateHz,method,confidenceKind
  if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<5 then raise syntax 88.900 array(method || ' provider returned malformed result')
  lag=raw[2]; confidence=raw[5]
  shift=.AudioTimeShift~new(lag,sampleRateHz,confidence,'positive lag means B appears later than A',method,'provider:'||providerId)
  outputs=.Array~of(.AudioProcessingOutput~new('shift',.AudioProcessingConstant~OUTPUT_TIME_SHIFT,'',shift))
  attrs=.Directory~new; attrs['confidence_kind']=confidenceKind
  maths=.AudioMathsEvidence~alignment(method,lag,sampleRateHz,confidence,confidenceKind,runtimeInfo['numpy_version'])
  measurements=.Array~of(.AudioMeasurement~new('alignment_confidence',confidence,'ratio',confidence,method,maths,attrs))
  .ForeignPythonSequenceSupport~closeIfProxy(raw)
  return .AudioProcessingResult~new(requestId,spec~id,config~id,'COMPLETED',outputs,measurements,runtimeInfo)

::method audioOutput private
  use strict arg role, proxy, sampleRateHz
  if \proxy~isa(.ForeignPythonObject) then raise syntax 88.900 array('audio processor did not return resident Python array')
  tensor=proxy~asTensor
  attrs=.Directory~new
  attrs['sample_rate_hz']=sampleRateHz
  attrs['sample_format']='f32le'
  attrs['channels']=1
  attrs['runtime_storage']='ForeignTensor'
  attrs['zero_copy_runtime_binding']=.true
  proxy~close
  return .AudioProcessingOutput~new(role,.AudioProcessingConstant~OUTPUT_AUDIO,'',tensor,attrs)

::method maskOutput private
  use strict arg role, proxy, domain, derivation
  if \proxy~isa(.ForeignPythonObject) then raise syntax 88.900 array('mask processor did not return resident Python array')
  tensor=proxy~asTensor
  attrs=.Directory~new
  attrs['runtime_storage']='ForeignTensor'
  attrs['zero_copy_runtime_binding']=.true
  mask=.AudioMaskDescriptor~new(role,domain,0,(0-1),0,0,derivation,0,'',attrs)
  proxy~close
  outAttrs=.Directory~new
  outAttrs['tensor']=tensor
  return .AudioProcessingOutput~new(role,.AudioProcessingConstant~OUTPUT_MASK,'',mask,outAttrs)


::method featureMapOutput private
  use strict arg role, proxy, domain, featureKind, derivation
  if \proxy~isa(.ForeignPythonObject) then raise syntax 88.900 array('feature-map processor did not return resident Python array')
  tensor=proxy~asTensor
  attrs=.Directory~new
  attrs['runtime_storage']='ForeignTensor'
  attrs['zero_copy_runtime_binding']=.true
  attrs['rank']=tensor~shape~items
  map=.AudioFeatureMapDescriptor~new(role,domain,featureKind,derivation,0,'',attrs)
  proxy~close
  outAttrs=.Directory~new; outAttrs['tensor']=tensor
  return .AudioProcessingOutput~new(role,.AudioProcessingConstant~OUTPUT_FEATURE_MAP,'',map,outAttrs)

::method vectorToArray private
  use strict arg proxy
  if proxy~isa(.Array) then return proxy
  if \proxy~isa(.ForeignPythonObject) then raise syntax 88.900 array('provider vector is not a Python sequence/ndarray proxy')
  seq=proxy~tolist
  out=.Array~new
  do i=1 to seq~items; out~append(seq[i]); end
  if seq~isa(.ForeignPythonObject) then seq~close
  proxy~close
  return out

::method runtimeMaterial private
  use strict arg x
  if x==.nil then return .false
  if x~isa(.ForeignBuffer) then return .true
  if x~isa(.ForeignTensor) then return .true
  return .false

::method requireB private
  use strict arg b,id
  if b==.nil then raise syntax 88.900 array(id || ' requires second input')

::method num private
  use strict arg d,key,defaultValue
  if d~hasIndex(key) then return d[key]
  return defaultValue

::method openStream
  expose py providerId runtimeInfo
  use strict arg sessionId, spec, config, sampleRateHz
  if \spec~streaming~streamingCapable then raise syntax 88.900 array('processor is not streaming-capable: ' || spec~id)
  p=config~parameters
  select
    when spec~id='transform.adaptive_spectral_denoise' then do
      worker=py~make_adaptive_spectral_denoise_stream(.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'noise_percentile',20)),.ForeignPython~float(self~num(p,'floor_scale',1.2)),.ForeignPython~float(self~num(p,'minimum_gain',0.08)),.ForeignPython~float(self~num(p,'state_alpha',0.85)))
    end
    when spec~id='mask.echo_persistence' then do
      worker=py~make_echo_persistence_stream(.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'n_fft',2048)),.ForeignPython~integer(self~num(p,'hop',512)),.ForeignPython~float(self~num(p,'delay_min_ms',10)),.ForeignPython~float(self~num(p,'delay_max_ms',120)),.ForeignPython~float(self~num(p,'delay_step_ms',10)),.ForeignPython~float(self~num(p,'normalization_sec',2.0)),.ForeignPython~float(self~num(p,'threshold',0.4)),.ForeignPython~float(self~num(p,'slope',8)))
    end
    when spec~id='transform.dynamic_filters' then do
      worker=py~make_dynamic_filter_stream(.ForeignPython~integer(sampleRateHz),.ForeignPython~integer(self~num(p,'max_filters_per_block',4)))
    end
    otherwise raise syntax 88.900 array('streaming reference provider not implemented for ' || spec~id)
  end
  return .AudioForeignPythonProcessingStreamSession~new(sessionId,spec,config,sampleRateHz,worker,providerId,runtimeInfo)

::method close
  expose py
  if py \== .nil then do; py~close; py=.nil; end

::method uninit
  expose py
  if symbol('py')='VAR' then if py \== .nil then self~close



::class AudioForeignPythonProcessingStreamSession public
::attribute semanticSession get
::attribute providerId get
::attribute processorId get
::attribute sampleRateHz get

::method init
  expose worker spec config sampleRateHz providerId runtimeInfo semanticSession closed processorId
  use strict arg sessionId, spec, config, sampleRateHz, worker, providerId, runtimeInfo
  processorId=spec~id
  semanticSession=.AudioProcessingStreamSession~new(sessionId,config,spec~streaming,spec~id)
  closed=.false

::method processBlock
  expose worker spec config sampleRateHz providerId runtimeInfo semanticSession closed
  use strict arg block, inputA, inputB=.nil
  if closed then raise syntax 88.900 array('processing stream session is closed')
  if inputB \== .nil then raise syntax 88.900 array('v0.21 stateful reference stream processors accept one runtime material input')
  if \self~runtimeMaterial(inputA) then raise syntax 88.900 array('stream input must be ForeignBuffer/ForeignTensor float32 material')
  semanticSession~acceptBlock(block)
  outputs=.Array~new
  measurements=.Array~new
  warnings=.Array~new
  if spec~id='transform.adaptive_spectral_denoise' then do
    raw=worker~process(inputA)
    outputs~append(self~audioOutput('clean',raw,sampleRateHz,block))
  end
  else if spec~id='mask.echo_persistence' then do
    raw=worker~process(inputA)
    if \.ForeignPythonSequenceSupport~isSequence(raw) | raw~items<2 then raise syntax 88.900 array('stream echo persistence returned malformed result')
    audio=raw[1]; mask=raw[2]
    outputs~append(self~audioOutput('echo_weighted',audio,sampleRateHz,block))
    outputs~append(self~maskOutput('echo_persistence_mask',mask,'TIME_FREQUENCY','echo_persistence',block))
    .ForeignPythonSequenceSupport~closeIfProxy(raw)
  end
  else if spec~id='transform.dynamic_filters' then do
    rules=self~activePythonFilterRules(config,block)
    raw=worker~process(inputA,rules)
    outputs~append(self~audioOutput('filtered',raw,sampleRateHz,block))
  end
  else raise syntax 88.900 array('unsupported stateful stream processor ' || spec~id)
  stateSummary=self~stateSummary
  result=.AudioProcessingResult~new(semanticSession~id || ':' || block~sequence,spec~id,config~id,'COMPLETED',outputs,measurements,runtimeInfo,warnings)
  return .AudioProcessingStreamBlockResult~new(block,result,semanticSession~checkpoint('FOREIGNPYTHON',stateSummary))

::method flush
  expose worker spec config sampleRateHz providerId runtimeInfo semanticSession closed
  if closed then return .AudioProcessingStreamBlockResult~new(.nil,.AudioProcessingResult~new(semanticSession~id || ':flush',spec~id,config~id,'COMPLETED'),semanticSession~checkpoint('FOREIGNPYTHON',self~stateSummary))
  raw=worker~flush
  outputs=.Array~new
  if raw~isa(.ForeignPythonObject) then do
    tensor=raw~asTensor
    if tensor~shape~items=1 & tensor~shape[1]>0 then outputs~append(self~audioOutput('flush',raw,sampleRateHz,.nil))
    else do
      tensor~close
      raw~close
    end
  end
  semanticSession~flush
  result=.AudioProcessingResult~new(semanticSession~id || ':flush',spec~id,config~id,'COMPLETED',outputs,.Array~new,runtimeInfo)
  return .AudioProcessingStreamBlockResult~new(.nil,result,semanticSession~checkpoint('FOREIGNPYTHON',self~stateSummary))

::method stateSummary
  expose worker spec
  raw=worker~state_summary
  d=.Directory~new
  if .ForeignPythonSequenceSupport~isSequence(raw) then do
    if raw~items>=1 then d['provider_blocks']=raw[1]
    if raw~items>=2 then d['provider_samples']=raw[2]
    select
      when spec~id='transform.adaptive_spectral_denoise' then do
        if raw~items>=3 then d['history_samples']=raw[3]
        if raw~items>=4 then d['noise_floor_mean']=raw[4]
        if raw~items>=5 then d['noise_floor_peak']=raw[5]
      end
      when spec~id='mask.echo_persistence' then do
        if raw~items>=3 then d['history_samples']=raw[3]
        if raw~items>=4 then d['maximum_delay_ms']=raw[4]
      end
      when spec~id='transform.dynamic_filters' then do
        if raw~items>=3 then d['active_filter_states']=raw[3]
        if raw~items>=4 then d['filters_applied_last_block']=raw[4]
      end
      otherwise do
        if raw~items>=3 then d['state_metric_1']=raw[3]
        if raw~items>=4 then d['state_metric_2']=raw[4]
      end
    end
  end
  .ForeignPythonSequenceSupport~closeIfProxy(raw)
  return d

::method audioOutput private
  use strict arg role, proxy, sampleRateHz, block=.nil
  if \proxy~isa(.ForeignPythonObject) then raise syntax 88.900 array('stream audio processor did not return resident Python array')
  tensor=proxy~asTensor
  attrs=.Directory~new
  attrs['sample_rate_hz']=sampleRateHz
  attrs['sample_format']='f32le'
  attrs['channels']=1
  attrs['runtime_storage']='ForeignTensor'
  attrs['zero_copy_runtime_binding']=.true
  if block \== .nil then do
    attrs['block_sequence']=block~sequence
    attrs['source_start_sample']=block~startSample
    attrs['source_sample_count']=block~sampleCount
  end
  proxy~close
  return .AudioProcessingOutput~new(role,.AudioProcessingConstant~OUTPUT_AUDIO,'',tensor,attrs)

::method maskOutput private
  use strict arg role, proxy, domain, derivation, block
  if \proxy~isa(.ForeignPythonObject) then raise syntax 88.900 array('stream mask processor did not return resident Python array')
  tensor=proxy~asTensor
  attrs=.Directory~new
  attrs['runtime_storage']='ForeignTensor'
  attrs['zero_copy_runtime_binding']=.true
  attrs['block_sequence']=block~sequence
  mask=.AudioMaskDescriptor~new(role,domain,0,(0-1),0,0,derivation,0,'',attrs)
  proxy~close
  outAttrs=.Directory~new; outAttrs['tensor']=tensor
  return .AudioProcessingOutput~new(role,.AudioProcessingConstant~OUTPUT_MASK,'',mask,outAttrs)

::method activePythonFilterRules private
  use strict arg config, block
  if \config~parameters~hasIndex('filter_plan') then return .Array~new
  plan=config~parameters['filter_plan']
  if \plan~isa(.AudioDynamicFilterPlan) then raise syntax 88.900 array('dynamic filter stream requires AudioDynamicFilterPlan parameter')
  active=plan~activeRules(block~startSample,block~sampleCount)
  out=.Array~new
  do rule over active
    d=.ForeignPythonDict~new
    d~put('action',.ForeignPython~text(rule~action))
    d~put('frequency_hz',.ForeignPython~float(rule~frequencyHz))
    d~put('q',.ForeignPython~float(rule~q))
    d~put('order',.ForeignPython~integer(rule~order))
    out~append(d)
  end
  return out

::method runtimeMaterial private
  use strict arg x
  if x==.nil then return .false
  if x~isa(.ForeignBuffer) then return .true
  if x~isa(.ForeignTensor) then return .true
  return .false

::method close
  expose worker closed
  if closed then return
  closed=.true
  if worker \== .nil then do; worker~close; worker=.nil; end

::method uninit
  expose closed
  if symbol('closed')='VAR' then if \closed then self~close

::requires 'AudioProcessingToolkit.cls'
::requires 'AudioMathsEvidence.cls'
::requires 'ForeignPythonSequenceSupport.cls'
::requires 'python_foreign.cls'
