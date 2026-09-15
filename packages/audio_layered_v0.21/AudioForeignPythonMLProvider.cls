/* AudioForeignPythonMLProvider.cls - local in-process ML provider via Foreign Runtime v0.22.2 Python provider */

::class AudioForeignPythonMLTarget public
::attribute providerId get
::attribute moduleName
::attribute embeddingModel get
::attribute verificationModel get

::method init
  expose providerId moduleName py embeddingModel verificationModel
  use strict arg moduleName = 'audio_ml_foreign'
  providerId = 'python.audio.foreign'
  self~moduleName = moduleName
  py = .ForeignPython~import(moduleName)

  attrs = .Directory~new
  attrs['threading_mode'] = py~threadingMode
  attrs['provider_path'] = py~providerPath
  embeddingModel = .MLModelSpec~new('speechbrain-ecapa-embedding', 'speaker.embedding', 'SpeechBrain', 'ECAPA-TDNN', 'speechbrain/spkrec-ecapa-voxceleb', 'UNPINNED', 'ForeignPython', 'audio-file-path', 'embedding-vector', attrs)
  verificationModel = .MLModelSpec~new('speechbrain-ecapa-verify', 'speaker.verification', 'SpeechBrain', 'ECAPA-TDNN', 'speechbrain/spkrec-ecapa-voxceleb', 'UNPINNED', 'ForeignPython', 'audio-file-pair', 'score+decision', attrs)

::method close
  expose py
  if py \== .nil then do
    py~close
    py = .nil
  end

::method uninit
  expose py
  if symbol('py') = 'VAR' then if py \== .nil then self~close

::method runtimeImplementationInvoke
  expose providerId py
  use strict arg operationId, request, contract
  signal on syntax name providerFault
  if \request~isa(.Directory) then return .RuntimeProviderResult~failure('MALFORMED_REQUEST', 'request must be a Directory', providerId)

  select
    when operationId = .AudioRuntimeOperation~SPEAKER_EMBEDDING then return self~speakerEmbedding(request)
    when operationId = .AudioRuntimeOperation~SPEAKER_VERIFY then return self~speakerVerify(request)
    otherwise return .RuntimeProviderResult~failure('UNSUPPORTED', 'operation not implemented by ForeignPython audio ML provider', providerId, self~implementationId)
  end

providerFault:
  c = condition('O')
  detail = 'ForeignPython audio ML invocation failed'
  if c \== .nil then if c~hasIndex('DESCRIPTION') then detail = c['DESCRIPTION']
  return .RuntimeProviderResult~failure('REMOTE_FAULT', detail, providerId, self~implementationId)

::method implementationId
  expose py moduleName
  return 'foreign-python:' || moduleName || '@' || py~pythonVersion

::method speakerEmbedding private
  expose py providerId
  use strict arg request
  if \request~hasIndex('media_path') then return .RuntimeProviderResult~failure('MALFORMED_REQUEST', 'speaker embedding requires media_path', providerId, self~implementationId)
  path = request['media_path']~string
  source = self~requestText(request, 'model_source', 'speechbrain/spkrec-ecapa-voxceleb')
  modelDir = self~requestText(request, 'model_dir', 'pretrained_models/spkrec-ecapa-voxceleb')
  revision = self~requestText(request, 'model_revision', 'UNPINNED')
  raw = py~speaker_embedding(.ForeignPython~text(path), .ForeignPython~text(source), .ForeignPython~text(modelDir), .ForeignPython~text(revision))
  if \.ForeignPythonSequenceSupport~isSequence(raw) then return .RuntimeProviderResult~failure('MALFORMED_RESPONSE', 'Python ML adapter returned malformed embedding envelope', providerId, self~implementationId)
  if raw~items < 2 then do
    .ForeignPythonSequenceSupport~closeIfProxy(raw)
    return .RuntimeProviderResult~failure('MALFORMED_RESPONSE', 'Python ML adapter returned malformed embedding envelope', providerId, self~implementationId)
  end
  status = raw[1]~string~lower
  if status \= 'ok' then do
    failure = self~pythonFailure(status, raw[2]~string)
    .ForeignPythonSequenceSupport~closeIfProxy(raw)
    return failure
  end
  if raw~items < 11 then do
    .ForeignPythonSequenceSupport~closeIfProxy(raw)
    return .RuntimeProviderResult~failure('MALFORMED_RESPONSE', 'Python ML adapter embedding envelope is incomplete', providerId, self~implementationId)
  end

  d = .Directory~new
  d['schema'] = 'layered-audio.speaker-embedding.worker.v1'
  d['model_provider'] = raw[2]
  d['model_family'] = raw[3]
  d['model_source'] = raw[4]
  d['model_revision'] = raw[5]
  d['sample_rate_hz'] = raw[6]
  d['channel_policy'] = raw[7]
  embeddingSource = raw[8]
  embedding = .ForeignPythonSequenceSupport~toArray(embeddingSource)
  .ForeignPythonSequenceSupport~closeIfProxy(embeddingSource)
  d['embedding'] = embedding
  d['dimension'] = embedding~items
  self~addMLProvenance(d, 'speaker.embedding', raw[9], raw[10], raw[11])
  .ForeignPythonSequenceSupport~closeIfProxy(raw)
  return .RuntimeProviderResult~success(d, providerId, self~implementationId)

::method speakerVerify private
  expose py providerId
  use strict arg request
  if \request~hasIndex('media_path_a') | \request~hasIndex('media_path_b') then return .RuntimeProviderResult~failure('MALFORMED_REQUEST', 'speaker verify requires media_path_a and media_path_b', providerId, self~implementationId)
  source = self~requestText(request, 'model_source', 'speechbrain/spkrec-ecapa-voxceleb')
  modelDir = self~requestText(request, 'model_dir', 'pretrained_models/spkrec-ecapa-voxceleb')
  revision = self~requestText(request, 'model_revision', 'UNPINNED')
  threshold = self~requestText(request, 'threshold', 'PROVIDER_DEFAULT')
  raw = py~speaker_verify(.ForeignPython~text(request['media_path_a']~string), .ForeignPython~text(request['media_path_b']~string), .ForeignPython~text(source), .ForeignPython~text(modelDir), .ForeignPython~text(revision), .ForeignPython~text(threshold))
  if \.ForeignPythonSequenceSupport~isSequence(raw) then return .RuntimeProviderResult~failure('MALFORMED_RESPONSE', 'Python ML adapter returned malformed verification envelope', providerId, self~implementationId)
  if raw~items < 2 then do
    .ForeignPythonSequenceSupport~closeIfProxy(raw)
    return .RuntimeProviderResult~failure('MALFORMED_RESPONSE', 'Python ML adapter returned malformed verification envelope', providerId, self~implementationId)
  end
  status = raw[1]~string~lower
  if status \= 'ok' then do
    failure = self~pythonFailure(status, raw[2]~string)
    .ForeignPythonSequenceSupport~closeIfProxy(raw)
    return failure
  end
  if raw~items < 10 then do
    .ForeignPythonSequenceSupport~closeIfProxy(raw)
    return .RuntimeProviderResult~failure('MALFORMED_RESPONSE', 'Python ML adapter verification envelope is incomplete', providerId, self~implementationId)
  end

  d = .Directory~new
  d['schema'] = 'layered-audio.speaker-verify.worker.v1'
  d['model_source'] = raw[2]
  d['model_revision'] = raw[3]
  d['score'] = raw[4]
  d['decision'] = raw[5]
  d['metric'] = raw[6]
  d['threshold'] = raw[7]
  self~addMLProvenance(d, 'speaker.verification', raw[8], raw[9], raw[10])
  .ForeignPythonSequenceSupport~closeIfProxy(raw)
  return .RuntimeProviderResult~success(d, providerId, self~implementationId)

::method addMLProvenance private
  expose py providerId
  use strict arg d, task, speechbrainVersion, torchVersion, torchaudioVersion
  d['ml_task'] = task
  d['ml_runtime'] = 'ForeignPython'
  d['ml_runtime_provider'] = py~provider
  d['ml_threading_mode'] = py~threadingMode
  d['python_version'] = py~pythonVersion
  d['speechbrain_version'] = speechbrainVersion
  d['torch_version'] = torchVersion
  d['torchaudio_version'] = torchaudioVersion
  d['runtime_provider_id'] = providerId
  return

::method requestText private
  use strict arg request, key, defaultValue
  if request~hasIndex(key) then return request[key]~string
  return defaultValue

::method pythonFailure private
  expose providerId
  use strict arg status, detail
  select
    when status = 'unsupported' then code = 'UNSUPPORTED'
    when status = 'unavailable' then code = 'PROVIDER_UNAVAILABLE'
    otherwise code = 'REMOTE_FAULT'
  end
  return .RuntimeProviderResult~failure(code, detail, providerId, self~implementationId)

::requires 'ForeignPythonSequenceSupport.cls'
::requires 'AudioRuntimeWorkers.cls'
::requires 'MLRuntime.cls'
::requires 'python_foreign.cls'
