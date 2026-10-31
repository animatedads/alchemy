/* SPASH SLAM two observed microphone TDOA and virtual 3D path hypotheses.
 * Video timing is context; Audio V9 owns DSP/gain/filtering.
 * Architecture: Tom Dyer. Initial implementation: ChatGPT GPT-6.
 */
::requires 'SpashSpatial.cls'
::class SpashDualMic3D public
::method init
  expose _a _b _c
  use strict arg microphoneA,microphoneB,speed=343
  if \microphoneA~isA(.SpashPoint) | \microphoneB~isA(.SpashPoint) then raise syntax 88.900 array('two observed microphone poses required','SpashPoint')
  if \datatype(speed,'N') then raise syntax 88.900 array('positive sound speed',speed)
  if speed<=0 then raise syntax 88.900 array('positive sound speed',speed)
  if microphoneA~distanceTo(microphoneB)=0 then raise syntax 88.900 array('distinct physical microphones required',0)
  _a=microphoneA;_b=microphoneB;_c=speed
::method predictTdoaMs
  expose _a _b _c
  use strict arg sourceHypothesis
  if \sourceHypothesis~isA(.SpashPoint) then raise syntax 88.900 array('3D source hypothesis required',sourceHypothesis)
  return 1000*(sourceHypothesis~distanceTo(_b)-sourceHypothesis~distanceTo(_a))/_c
::method evaluate
  expose _a _b _c
  use strict arg sourceHypothesis,observedTdoaMs=.nil,toleranceMs=.nil,acousticCoherent=.false,vehiclePass=.nil
  prediction=self~predictTdoaMs(sourceHypothesis)
  row=.directory~new
  row~put(sourceHypothesis~id,'HYPOTHESIS_ID')
  row~put(prediction,'PREDICTED_TDOA_MS')
  row~put('TWO_OBSERVED_MICS','MEASUREMENT_CONFIGURATION')
  row~put('UNDERDETERMINED_WITH_TWO_MICS','GEOMETRY_STATUS')
  row~put('MODEL_PREDICTION_NOT_MEASUREMENT','PREDICTION_AUTHORITY')
  row~put('UNASSESSED','AUDIO_COMPATIBILITY')
  row~put('NOT_USED','VIDEO_CONTEXT')
  row~put('UNTESTED','RESULT')
  if observedTdoaMs == .nil then return row
  if \datatype(observedTdoaMs,'N') then raise syntax 88.900 array('numeric measured TDOA',observedTdoaMs)
  if toleranceMs == .nil then raise syntax 88.900 array('measured delay uncertainty required',toleranceMs)
  if \datatype(toleranceMs,'N') then raise syntax 88.900 array('numeric TDOA uncertainty',toleranceMs)
  if toleranceMs<0 then raise syntax 88.900 array('nonnegative uncertainty',toleranceMs)
  if acousticCoherent \== .true & acousticCoherent \== .false then raise syntax 88.900 array('explicit acoustic admission boolean',acousticCoherent)
  residual=observedTdoaMs-prediction
  row~put(observedTdoaMs,'OBSERVED_TDOA_MS')
  row~put(toleranceMs,'MEASURED_UNCERTAINTY_MS')
  row~put(residual,'RESIDUAL_MS')
  maxTdoa=1000*_a~distanceTo(_b)/_c
  row~put(maxTdoa,'PHYSICAL_TDOA_BOUND_MS')
  if acousticCoherent then row~put('COHERENT_MEASURED_AUDIO','AUDIO_COMPATIBILITY')
  else row~put('UNADMITTED_AUDIO','AUDIO_COMPATIBILITY')
  if vehiclePass \== .nil then do
    if \vehiclePass~isA(.directory) then raise syntax 88.900 array('vehicle camera context must be Directory',vehiclePass)
    row~put('CAMERA_MOTION_CONTEXT_NOT_AUDIO','VIDEO_CONTEXT')
    if vehiclePass~hasIndex('VIDEO_FRAME_TIME') then row~put(vehiclePass~at('VIDEO_FRAME_TIME'),'VIDEO_FRAME_TIME')
    if vehiclePass~hasIndex('CLOCK_MODEL_ID') then row~put(vehiclePass~at('CLOCK_MODEL_ID'),'VIDEO_CLOCK_MODEL_ID')
  end
  if \acousticCoherent then do
    row~put('AUDIO_NOT_ADMITTED','RESULT')
    return row
  end
  if abs(observedTdoaMs)>maxTdoa+toleranceMs then do
    row~put('OUTSIDE_TWO_MIC_PHYSICAL_BOUND','RESULT')
    return row
  end
  if abs(residual)<=toleranceMs then row~put('DELAY_COMPATIBLE_NOT_LOCALIZED','RESULT')
  else row~put('DELAY_INCOMPATIBLE','RESULT')
  return row
::method virtualMicrophones
  expose _c
  use strict arg sourceHypothesis,virtualPositions,emissionMs=0
  e=.SpashSpatialExperiment~new(_c)
  return e~predict(sourceHypothesis,virtualPositions,emissionMs)
::method processingPlan
  use strict arg keypointId,vehiclePass=.false,peakTransient=.false
  if keypointId=='' then raise syntax 88.900 array('keypoint ID required',keypointId)
  if vehiclePass \== .true & vehiclePass \== .false then raise syntax 88.900 array('vehiclePass boolean',vehiclePass)
  if peakTransient \== .true & peakTransient \== .false then raise syntax 88.900 array('peakTransient boolean',peakTransient)
  r=.directory~new
  r~put(keypointId,'KEYPOINT_ID')
  r~put('IMMUTABLE_SOURCE_AUDIO','EVIDENCE_STREAM')
  r~put('SPEECH_PRESERVE_NO_HARD_MUTE','VOICE_POLICY')
  r~put('AUDIO_V9_GAIN_AND_DYNAMIC_FILTER_PROVIDER','DSP_OWNER')
  r~put('NEVER_REWRITE_MEASURED_PATH_SCORES','EVIDENCE_POLICY')
  if vehiclePass | peakTransient then do
    r~put('HOLD_WHISPER_GAIN_REFERENCE','GAIN_POLICY')
    r~put('SEPARATE_MOVING_REFLECTOR_HYPOTHESIS','PATH_POLICY')
  end
  else do
    r~put('ELIGIBLE_FOR_BOUNDED_WHISPER_GAIN_REFERENCE','GAIN_POLICY')
    r~put('DIRECT_AND_STATIC_REFLECTION_HYPOTHESES','PATH_POLICY')
  end
  return r
