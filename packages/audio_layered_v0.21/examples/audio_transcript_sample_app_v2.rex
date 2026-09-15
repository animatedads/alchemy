/* Layered Audio v0.18 transcript sample - Foreign Runtime v0.22.2+
 *
 * Key changes from the early sample:
 * - decode once and validate actual sample format;
 * - create one resident ASR model and reuse it across files;
 * - detect speech-like regions before ASR;
 * - use utterance-sized 0.45..12s regions rather than blind 2s chunks;
 * - use bounded RMS gain instead of global peak-normalising camera ambience;
 * - preserve each region as its own transcript boundary and print it from Rexx.
 */
parse arg commandLine
if commandLine='' then do
  say 'usage: rexx examples/audio_transcript_sample_app_v2.rex file1.mp4 [file2.mp4 ...]'
  exit 2
end

bridgeDir=value('LAYERED_AUDIO_FOREIGN_DIR',,'ENVIRONMENT')
if bridgeDir='' then bridgeDir='foreign'

.RuntimeImplementationSwitch~reset
.AudioLibraryBuild~referenceSwitch=.nil
target=.AudioFFmpegForeignTarget~new(bridgeDir)
provider=.RuntimeObjectImplementationProvider~new('native.ffmpeg.foreign',target)
broker=.RuntimeImplementationBroker~new
do op over .Array~of(.AudioRuntimeOperation~MEDIA_AUDIO_DECODE,.AudioRuntimeOperation~PCM_TRANSFORM)
  broker~register(op,.RuntimeImplementationReference~new(provider,200,.true,1,1))
end
.RuntimeImplementationSwitch~installBroker(broker)
.AudioLibraryBuild~referenceSwitch=.RuntimeImplementationSwitch

asrSource=value('LAYERED_AUDIO_ASR_MODEL',,'ENVIRONMENT')
if asrSource='' then asrSource='speechbrain/asr-crdnn-rnnlm-librispeech'
asrDir=value('LAYERED_AUDIO_ASR_DIR',,'ENVIRONMENT')
if asrDir='' then asrDir='pretrained_models/asr-crdnn-rnnlm-librispeech'

say 'ASR RUNTIME ForeignPython v0.22.2+ direct SpeechBrain/Torch'
say 'ASR MODEL' asrSource
minSpeechScore=value('LAYERED_AUDIO_ASR_MIN_SPEECH_SCORE',,'ENVIRONMENT')
if minSpeechScore='' then minSpeechScore=0.08
say 'ASR MIN SPEECH OCCUPANCY' minSpeechScore
asr=.AudioASRForeignPythonSession~new(asrSource,asrDir)
np=.ForeignPython~import('numpy')
libc=.foreign~load(bridgeDir||'/libc-memory.bridge.json')

do i=1 to words(commandLine)
  path=word(commandLine,i)
  say 'TRANSCRIBE' path
  req=.Directory~new
  req['path']=path
  req['channels']=1
  req['sample_rate']=16000
  req['maximum_frames']=0
  attempt=.AudioRuntimeWorker~tryMediaAudioDecode(req)
  if attempt==.nil | \attempt~handled then do
    if attempt==.nil then say '  decode failed: no provider'; else say '  decode failed:' attempt~code attempt~detail
    iterate
  end
  dv=attempt~value

  -- Canonical ASR material is mono 16k float32.  Current camera AAC normally
  -- decodes as fltp; fail closed rather than interpreting another format as f32.
  if dv['sample_rate'] \=16000 | dv['channels'] \=1 then do
    say '  unsupported decode geometry rate='dv['sample_rate'] 'channels='dv['channels']
    iterate
  end
  if dv['sample_format'] \='fltp' & dv['sample_format'] \='flt' then do
    say '  unsupported decode sample_format='dv['sample_format'] 'expected float32'
    iterate
  end
  if dv['source_planar'] then rawPcm=dv['pcm_planes'][1]; else rawPcm=dv['pcm_bytes']
  expected=dv['sample_count']*4
  if rawPcm~length < expected then do
    say '  malformed PCM bytes='rawPcm~length 'expected-at-least='expected
    iterate
  end

  pcm=.foreign~buffer(expected)
  ignored=libc~memcpy_call(pcm,rawPcm,expected)
  samples=np~frombuffer(pcm,.ForeignPython~text('<f4'))
  npTensor=samples~asTensor
  torchObj=npTensor~toDLPack('torch')
  tensor=torchObj~asTensor
  signal=tensor~reshape(.ForeignPython~integer(1),.ForeignPython~integer(-1))

  diag=asr~diagnose(signal,16000)
  say '  audio samples='diag['samples'] 'duration_s='diag['duration_seconds'] 'peak='diag['peak'] 'rms_dbfs='diag['rms_dbfs']
  regions=asr~regions(signal,16000)
  say '  candidate_speech_regions='regions~items

  recording=.AudioRecording~new('REC-'||i,(dv['sample_count']*1000)%16000)
  raw=recording~addRawFeed('RAW-'||i,recording~durationMs,path,'camera source audio',.directory~new)
  view=recording~createTranscriptView('TRANSCRIPT-ASR-'||i,'SpeechBrain ASR segmented','energy-gated utterance-sized ASR','CAMERA-'||i,'',1,'automatic candidates; human review required',.directory~new)

  rno=0
  do region over regions
    rno=rno+1
    startSample=region['start_sample']
    endSample=region['end_sample']
    startMs=(startSample*1000)%16000
    endMs=(endSample*1000)%16000
    if region['speech_score'] < minSpeechScore then do
      say '  ['right(startMs,6)'..'right(endMs,6)' ms occupancy='format(region['speech_score'],1,3)'] SKIP low-speech region'
      iterate
    end
    text=asr~transcribeRegion(signal,startSample,endSample,16000)
    say '  ['right(startMs,6)'..'right(endMs,6)' ms occupancy='format(region['speech_score'],1,3)']' text
    if text \='' then do
      attrs=.Directory~new
      attrs['model_source']=asrSource
      attrs['segmentation']='frame-rms adaptive noise floor; utterance-sized'
      attrs['speech_score']=region['speech_score']
      attrs['noise_floor_db']=region['noise_floor_db']
      attrs['threshold_db']=region['threshold_db']
      attrs['preparation']='DC-remove; highpass 80Hz; RMS target -20dBFS; max boost 12dB; peak limit .95'
      recording~addTranscriptBoundary(view~id,'ASR-'||i||'-'||rno,startMs,endMs,text,0.0,'SpeechBrain-ASR',.Array~of(raw~id),'','',attrs,'automatic hypothesis; lexical confidence unavailable')
    end
  end

  signal~close
  tensor~close
  torchObj~close
  npTensor~close
  samples~close
  pcm~close
  say '  transcript_view='view~id 'boundaries='view~boundaries~items
end

asr~close
np~close
libc~close
target~close
.AudioLibraryBuild~referenceSwitch=.nil
.RuntimeImplementationSwitch~reset
say 'AUDIO TRANSCRIPT SAMPLE V2: COMPLETE'
exit 0

::requires 'AudioFFmpegForeignProvider.cls'
::requires 'AudioRuntimeWorkers.cls'
::requires 'AudioASRForeignPython.cls'
::requires 'AudioCore.cls'
::requires 'python_foreign.cls'
