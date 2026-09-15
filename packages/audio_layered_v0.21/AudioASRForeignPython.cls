/* AudioASRForeignPython.cls - domain-specific ASR session over ForeignPython v0.22.2+
 *
 * Transcript semantics remain in AudioCore.  This class owns only local,
 * process-resident model execution and conservative audio preparation.
 */

::class AudioASRForeignPythonSession public
::attribute modelSource get
::attribute modelDir get
::attribute runtimeInfo get

::method init
  expose prep torch speechbrain model modelSource modelDir runtimeInfo
  use strict arg modelSource='speechbrain/asr-crdnn-rnnlm-librispeech', modelDir='pretrained_models/asr-crdnn-rnnlm-librispeech'
  prep = .ForeignPython~import('audio_asr_foreign')
  torch = .ForeignPython~import('torch')
  speechbrain = .ForeignPython~import('speechbrain.inference')
  modelClass = speechbrain~get('EncoderDecoderASR')
  if modelClass == .nil then raise syntax 88.900 array('SpeechBrain EncoderDecoderASR is unavailable')
  kw = .ForeignPython~keywords
  kw~put('source', modelSource)
  kw~put('savedir', modelDir)
  model = modelClass~invokeKw('from_hparams', .Array~new, kw)
  runtimeInfo = .Directory~new
  runtimeInfo['python_version'] = prep~pythonVersion
  runtimeInfo['threading_mode'] = prep~threadingMode
  runtimeInfo['model_source'] = modelSource
  runtimeInfo['model_dir'] = modelDir

::method diagnose
  expose prep
  use strict arg signalTensor, sampleRate=16000
  return prep~diagnostics(signalTensor, .ForeignPython~integer(sampleRate))

::method regions
  expose prep
  use strict arg signalTensor, sampleRate=16000
  return prep~speech_regions(signalTensor, .ForeignPython~integer(sampleRate))

::method transcribeRegion
  expose prep torch model
  use strict arg signalTensor, startSample, endSample, sampleRate=16000
  prepared = prep~prepare_region(signalTensor, .ForeignPython~integer(startSample), .ForeignPython~integer(endSample), .ForeignPython~integer(sampleRate))
  if \prepared~isA(.ForeignPythonObject) then raise syntax 88.900 array('ASR preparation did not return a resident Python tensor')
  shape = prepared~get('shape')
  if shape~items < 2 | shape[2] < 1 then do
    prepared~close
    return ''
  end
  lengths = torch~tensor(.Array~of(1.0))
  result = model~transcribe_batch(prepared, lengths)
  prepared~close
  lengths~close
  if \.ForeignPythonSequenceSupport~isSequence(result) then return ''
  if result~items < 1 then do
    .ForeignPythonSequenceSupport~closeIfProxy(result)
    return ''
  end
  words = result[1]
  if .ForeignPythonSequenceSupport~isSequence(words) then do
    if words~items < 1 then do
      .ForeignPythonSequenceSupport~closeIfProxy(words)
      .ForeignPythonSequenceSupport~closeIfProxy(result)
      return ''
    end
    firstWord = words[1]
    answer = firstWord~string
    .ForeignPythonSequenceSupport~closeIfProxy(firstWord)
    .ForeignPythonSequenceSupport~closeIfProxy(words)
    .ForeignPythonSequenceSupport~closeIfProxy(result)
    return answer
  end
  answer = words~string
  .ForeignPythonSequenceSupport~closeIfProxy(words)
  .ForeignPythonSequenceSupport~closeIfProxy(result)
  return answer

::method close
  expose prep torch speechbrain model
  if model \== .nil then do; model~close; model=.nil; end
  if speechbrain \== .nil then do; speechbrain~close; speechbrain=.nil; end
  if torch \== .nil then do; torch~close; torch=.nil; end
  if prep \== .nil then do; prep~close; prep=.nil; end

::method uninit
  expose prep
  if symbol('prep')='VAR' then if prep \== .nil then self~close

::requires 'ForeignPythonSequenceSupport.cls'
::requires 'python_foreign.cls'
