say 'AUDIO CAMERA ASR PREPARATION START'
bridgeDir='../foreign'
.RuntimeImplementationSwitch~reset
.AudioLibraryBuild~referenceSwitch=.nil

target=.AudioFFmpegForeignTarget~new(bridgeDir)
provider=.RuntimeObjectImplementationProvider~new('native.ffmpeg.foreign',target)
broker=.RuntimeImplementationBroker~new
broker~register(.AudioRuntimeOperation~MEDIA_AUDIO_DECODE,.RuntimeImplementationReference~new(provider,200,.true,1,1))
.RuntimeImplementationSwitch~installBroker(broker)
.AudioLibraryBuild~referenceSwitch=.RuntimeImplementationSwitch

req=.Directory~new
req['path']=value('AUDIO_CAMERA_FIXTURE',,'ENVIRONMENT')
req['channels']=1
req['sample_rate']=16000
req['maximum_frames']=128
attempt=.AudioRuntimeWorker~tryMediaAudioDecode(req)
call truth attempt \== .nil & attempt~handled,'camera decode handled'
v=attempt~value
call eq 'fltp',v['sample_format'],'camera ASR fixture expected planar float32'
call eq 16000,v['sample_rate'],'camera ASR sample rate'
call eq 1,v['channels'],'camera ASR mono'
raw=v['pcm_planes'][1]
call eq v['sample_count']*4,raw~length,'full decoded float32 byte length'

libc=.foreign~load('../foreign/libc-memory.bridge.json')
buf=.foreign~buffer(raw~length)
ignored=libc~memcpy_call(buf,raw,raw~length)
np=.ForeignPython~import('numpy')
prep=.ForeignPython~import('audio_asr_foreign')
arr=np~frombuffer(buf,.ForeignPython~text('<f4'))
npTensor=arr~asTensor
torchObj=npTensor~toDLPack('torch')
sig=torchObj~asTensor
signal=sig~reshape(.ForeignPython~integer(1),.ForeignPython~integer(-1))
diag=prep~diagnostics(signal,.ForeignPython~integer(16000))
regions=prep~speech_regions(signal,.ForeignPython~integer(16000))
call eq v['sample_count'],diag['samples'],'ASR diagnostics sample count'
call truth regions~items > 0,'camera ASR preparation finds candidate speech regions'
do r over regions
  call truth r['start_sample'] >= 0 & r['end_sample'] > r['start_sample'] & r['end_sample'] <= v['sample_count'],'ASR region bounds'
end
say '  duration_s='diag['duration_seconds'] 'rms_dbfs='diag['rms_dbfs'] 'regions='regions~items

signal~close
sig~close
torchObj~close
npTensor~close
arr~close
prep~close
np~close
buf~close
libc~close
target~close
.AudioLibraryBuild~referenceSwitch=.nil
.RuntimeImplementationSwitch~reset
say 'AUDIO CAMERA ASR PREPARATION: OK regions='regions~items
exit 0

eq: procedure
 use strict arg expected,actual,label
 if expected \= actual then raise syntax 88.900 array('FAILED '||label||' expected='||expected||' actual='||actual)
 return
truth: procedure
 use strict arg actual,label
 if \actual then raise syntax 88.900 array('FAILED '||label)
 return

::requires '../AudioFFmpegForeignProvider.cls'
::requires 'python_foreign.cls'
