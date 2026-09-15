say 'AUDIO CAMERA TENSOR MATERIAL START'
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
req['maximum_frames']=8
attempt=.AudioRuntimeWorker~tryMediaAudioDecode(req)
call truth attempt \== .nil & attempt~handled,'camera decode handled'
v=attempt~value
call eq 'fltp',v['sample_format'],'camera fixture expected planar float32'
call truth v['source_planar'],'camera fixture planar source'
raw=v['pcm_planes'][1]
call eq v['sample_count']*4,raw~length,'decoded float32 plane byte length'

/* The Runtime Reference operation is value-in/value-out, so materializing its
 * returned PCM into a managed runtime buffer is one explicit copy.  From this
 * buffer into NumPy/ForeignTensor/native descriptor is then shared storage. */
libc=.foreign~load('../foreign/libc-memory.bridge.json')
buf=.foreign~buffer(raw~length)
ignored=libc~memcpy_call(buf,raw,raw~length)
np=.ForeignPython~import('numpy')
arr=np~frombuffer(buf,.ForeignPython~text('<f4'))
spec=.AudioMLMaterialSpec~new('CAM-MAT-1','CAM-REC-3605','AAC-DECODE-1',0,(v['sample_count']*1000)%16000,16000,1,'f32','MONO','LITTLE',.Array~of('native-aac-decode','materialize-runtime-buffer'))
material=.AudioMLMaterialBinding~new(spec,'ForeignBuffer',buf,0,buf~size,.true)
tensor=arr~asTensor
tb=.AudioMLTensorBinding~fromForeignTensor(material,tensor,.true)
call eq v['sample_count'],tb~descriptor~shape[1],'tensor sample dimension follows decoded material'
call eq 4,tb~descriptor~strides[1],'camera tensor float32 byte stride'
call eq 'float32',tb~descriptor~dtype,'camera tensor dtype'
call eq 'cpu',tb~descriptor~device,'camera tensor device'

frhome=value('FOREIGN_RUNTIME_HOME',,'ENVIRONMENT')
probe=.foreign~load(frhome || '/tests/tensor-native.bridge.json')
call eq v['sample_count'],probe~dim(tb~nativeHandle,0),'native tensor consumer sees camera sample count'
call eq 32,probe~dtype_bits(tb~nativeHandle),'native tensor consumer sees camera float width'
call eq 1,probe~device_type(tb~nativeHandle),'native tensor consumer sees host CPU device'

probe~close
arr~close
tb~close
np~close
buf~close
libc~close
target~close
.AudioLibraryBuild~referenceSwitch=.nil
.RuntimeImplementationSwitch~reset
say 'AUDIO CAMERA TENSOR MATERIAL: OK samples='v['sample_count']
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
::requires '../AudioMLMaterial.cls'
::requires 'python_foreign.cls'
