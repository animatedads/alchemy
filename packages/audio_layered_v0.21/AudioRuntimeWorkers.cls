/* AudioRuntimeWorkers.cls - Runtime Reference bridge for optional audio workers v0.12 */

::class AudioRuntimeOperation public
::constant SPEAKER_EMBEDDING 'audio.speaker.embedding.extract/1'
::constant SPEAKER_VERIFY 'audio.speaker.verify/1'
::constant MUSIC_FINGERPRINT 'audio.music.fingerprint/1'
::constant MUSIC_IDENTIFY 'audio.music.identify/1'
::constant PITCH_EXTRACT 'audio.pitch.extract/1'
::constant FFMPEG_DESCRIBE 'audio.ffmpeg.describe/1'
::constant SAMPLE_FORMAT_DESCRIBE 'audio.sample.format.describe/1'
::constant CONTAINER_OPEN_PROBE 'audio.container.open.probe/1'
::constant PCM_RESAMPLE 'audio.pcm.resample/1'
::constant PCM_TRANSFORM 'audio.pcm.transform/1'
::constant MEDIA_AUDIO_DECODE 'audio.media.audio.decode/1'

/* Mirrors CryptoLibraryBuild~referenceSwitch: the audio package owns the
 * semantic operation; deployment chooses whether/how an alternate provider
 * executes it.  .nil means no reference worker is enabled. */
::class AudioLibraryBuild public
::attribute referenceSwitch class
::method init class
  self~referenceSwitch = .nil

::class AudioRuntimeWorker public

::method trySpeakerEmbedding class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~SPEAKER_EMBEDDING, request, 'SPEAKER_EMBEDDING')

::method trySpeakerVerify class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~SPEAKER_VERIFY, request, 'SPEAKER_VERIFY')

::method tryMusicFingerprint class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~MUSIC_FINGERPRINT, request, 'MUSIC_FINGERPRINT')

::method tryMusicIdentify class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~MUSIC_IDENTIFY, request, 'MUSIC_IDENTIFY')

::method tryPitchExtract class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~PITCH_EXTRACT, request, 'PITCH_EXTRACT')

::method tryFFmpegDescribe class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~FFMPEG_DESCRIBE, request, 'FFMPEG_DESCRIBE')

::method trySampleFormatDescribe class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~SAMPLE_FORMAT_DESCRIBE, request, 'SAMPLE_FORMAT_DESCRIBE')

::method tryContainerOpenProbe class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~CONTAINER_OPEN_PROBE, request, 'CONTAINER_OPEN_PROBE')

::method tryPCMResample class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~PCM_RESAMPLE, request, 'PCM_RESAMPLE')

::method tryPCMTransform class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~PCM_TRANSFORM, request, 'PCM_TRANSFORM')

::method tryMediaAudioDecode class
  use strict arg request
  return self~_try(.AudioRuntimeOperation~MEDIA_AUDIO_DECODE, request, 'MEDIA_AUDIO_DECODE')

::method _try private class
  use strict arg operationId, request, validatorKind
  if \request~isa(.Directory) then raise syntax 88.900 array('audio worker request must be a Directory')
  switch = .AudioLibraryBuild~referenceSwitch
  if switch == .nil then return .nil
  attempt = switch~invokePure(operationId, request)
  if attempt~handled then do
    valid = self~_validate(validatorKind, attempt~value)
    if \valid then attempt = switch~rejectPureCompleted(attempt, 'RESULT_VALIDATION_FAILED', 'audio worker provider returned invalid ' || validatorKind || ' result')
  end
  return attempt

::method requireValue class
  use strict arg attempt, operationId = 'audio worker operation'
  if attempt == .nil then raise syntax 88.900 array(operationId || ' has no Runtime Reference worker configured')
  if attempt~handled then return attempt~value
  raise syntax 88.900 array(operationId || ' reference worker did not complete: ' || attempt~code)

::method _validate private class
  use strict arg kind, value
  if \value~isa(.Directory) then return .false
  select
    when kind = 'SPEAKER_EMBEDDING' then return self~_validateSpeakerEmbedding(value)
    when kind = 'SPEAKER_VERIFY' then return self~_validateSpeakerVerify(value)
    when kind = 'MUSIC_FINGERPRINT' then return self~_validateMusicFingerprint(value)
    when kind = 'MUSIC_IDENTIFY' then return self~_validateMusicIdentify(value)
    when kind = 'PITCH_EXTRACT' then return self~_validatePitchExtract(value)
    when kind = 'FFMPEG_DESCRIBE' then return self~_validateFFmpegDescribe(value)
    when kind = 'SAMPLE_FORMAT_DESCRIBE' then return self~_validateSampleFormatDescribe(value)
    when kind = 'CONTAINER_OPEN_PROBE' then return self~_validateContainerOpenProbe(value)
    when kind = 'PCM_RESAMPLE' then return self~_validatePCMResample(value)
    when kind = 'PCM_TRANSFORM' then return self~_validatePCMTransform(value)
    when kind = 'MEDIA_AUDIO_DECODE' then return self~_validateMediaAudioDecode(value)
    otherwise return .false
  end

::method _has private class
  use strict arg d, key
  return d~hasIndex(key)

::method _validateSpeakerEmbedding private class
  use strict arg v
  if \self~_has(v, 'embedding') | \self~_has(v, 'dimension') then return .false
  emb = v['embedding']
  if \emb~isa(.Array) then return .false
  dim = v['dimension']
  if \datatype(dim, 'N') then return .false
  if dim < 1 | emb~items \= dim then return .false
  do x over emb
    if \datatype(x, 'N') then return .false
  end
  return .true

::method _validateSpeakerVerify private class
  use strict arg v
  if \self~_has(v, 'score') | \self~_has(v, 'decision') then return .false
  if \datatype(v['score'], 'N') then return .false
  d = v['decision']
  if d~class~id = 'JSONBoolean' then return .true
  decision = d~string~lower
  if decision \= 'true' & decision \= 'false' & decision \= '1' & decision \= '0' then return .false
  return .true

::method _validateMusicFingerprint private class
  use strict arg v
  if \self~_has(v, 'fingerprint') | \self~_has(v, 'duration_seconds') then return .false
  if v['fingerprint']~string == '' then return .false
  if \datatype(v['duration_seconds'], 'N') then return .false
  if v['duration_seconds'] < 0 then return .false
  return .true

::method _validateMusicIdentify private class
  use strict arg v
  if \self~_has(v, 'matches') then return .false
  if \v['matches']~isa(.Array) then return .false
  return .true

::method _validatePitchExtract private class
  use strict arg v
  if \self~_has(v, 'observations') then return .false
  observations = v['observations']
  if \observations~isa(.Array) then return .false
  do obs over observations
    if \obs~isa(.Directory) then return .false
    if \obs~hasIndex('time_ms') then return .false
    if \datatype(obs['time_ms'], 'N') then return .false
    if obs~hasIndex('hz') then do
      hz = obs['hz']
      if hz~string \= '' then if \datatype(hz, 'N') then return .false
    end
  end
  return .true


::method _validateFFmpegDescribe private class
  use strict arg v
  required = .Array~of('ffmpeg_version_info', 'avutil_version', 'avcodec_version', 'swresample_version')
  do key over required
    if \v~hasIndex(key) then return .false
    if v[key]~string = '' then return .false
  end
  if \datatype(v['avutil_version'], 'N') then return .false
  if \datatype(v['avcodec_version'], 'N') then return .false
  if \datatype(v['swresample_version'], 'N') then return .false
  return .true

::method _validateSampleFormatDescribe private class
  use strict arg v
  required = .Array~of('name', 'format_id', 'bytes_per_sample', 'planar')
  do key over required
    if \v~hasIndex(key) then return .false
  end
  if v['name']~string = '' then return .false
  if \datatype(v['format_id'], 'N') then return .false
  if \datatype(v['bytes_per_sample'], 'N') then return .false
  if v['bytes_per_sample'] < 1 then return .false
  return .true


::method _validateContainerOpenProbe private class
  use strict arg v
  required = .Array~of('path', 'open_rc', 'stream_info_rc', 'opened', 'provider', 'avformat_version')
  do key over required
    if \v~hasIndex(key) then return .false
  end
  if v['path']~string = '' then return .false
  if \datatype(v['open_rc'], 'N') then return .false
  if \datatype(v['stream_info_rc'], 'N') then return .false
  if \datatype(v['avformat_version'], 'N') then return .false
  return .true



::method _validatePCMResample private class
  use strict arg v
  required = .Array~of('sample_format', 'channels', 'input_sample_rate', 'output_sample_rate', 'input_samples', 'output_samples', 'provider', 'swresample_version')
  do key over required
    if \v~hasIndex(key) then return .false
  end
  if v['sample_format']~string = '' then return .false
  do key over .Array~of('channels','input_sample_rate','output_sample_rate','input_samples','output_samples','swresample_version')
    if \datatype(v[key], 'N') then return .false
  end
  if v['channels'] < 1 | v['input_sample_rate'] < 1 | v['output_sample_rate'] < 1 then return .false
  if v['input_samples'] < 0 | v['output_samples'] < 0 then return .false
  hasPacked = v~hasIndex('pcm_bytes')
  hasPlanar = v~hasIndex('pcm_planes')
  if hasPacked = hasPlanar then return .false
  if hasPlanar then do
    planes = v['pcm_planes']
    if \planes~isa(.Array) then return .false
    if planes~items \= v['channels'] then return .false
  end
  return .true


::method _validatePCMTransform private class
  use strict arg v
  required = .Array~of('input_sample_format','output_sample_format','input_channels','output_channels','input_sample_rate','output_sample_rate','input_samples','output_samples','output_planar','bytes_per_output_sample','provider','swresample_version')
  do key over required
    if \v~hasIndex(key) then return .false
  end
  if v['input_sample_format']~string = '' | v['output_sample_format']~string = '' then return .false
  do key over .Array~of('input_channels','output_channels','input_sample_rate','output_sample_rate','input_samples','output_samples','bytes_per_output_sample','swresample_version')
    if \datatype(v[key], 'N') then return .false
  end
  if v['input_channels'] < 1 | v['output_channels'] < 1 | v['input_sample_rate'] < 1 | v['output_sample_rate'] < 1 then return .false
  if v['input_samples'] < 0 | v['output_samples'] < 0 | v['bytes_per_output_sample'] < 1 then return .false
  hasPacked = v~hasIndex('pcm_bytes')
  hasPlanar = v~hasIndex('pcm_planes')
  if hasPacked = hasPlanar then return .false
  if v['output_planar'] then do
    if \hasPlanar then return .false
    if \v['pcm_planes']~isa(.Array) then return .false
    if v['pcm_planes']~items \= v['output_channels'] then return .false
  end
  else if \hasPacked then return .false
  return .true



::method _validateMediaAudioDecode private class
  use strict arg v
  required = .Array~of('path','selected_stream','sample_format','sample_rate','channels','frame_count','sample_count','provider','avcodec_version','avutil_version','source_planar')
  do key over required
    if \v~hasIndex(key) then return .false
  end
  if v['path']~string = '' | v['sample_format']~string = '' then return .false
  do key over .Array~of('selected_stream','sample_rate','channels','frame_count','sample_count','avcodec_version','avutil_version')
    if \datatype(v[key],'N') then return .false
  end
  if v['selected_stream'] < 0 | v['sample_rate'] < 1 | v['channels'] < 1 | v['frame_count'] < 1 | v['sample_count'] < 1 then return .false
  hasPacked = v~hasIndex('pcm_bytes')
  hasPlanar = v~hasIndex('pcm_planes')
  if hasPacked = hasPlanar then return .false
  if hasPlanar then do
    if \v['pcm_planes']~isa(.Array) then return .false
    if v['pcm_planes']~items \= v['channels'] then return .false
  end
  return .true
::requires 'RuntimeImplementationReference.cls'
