say 'AUDIO CAMERA NATIVE DECODE START'
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
r=.AudioRuntimeWorker~tryMediaAudioDecode(req)
call assertTrue r \== .nil, 'decode attempt returned'
call assertTrue r~handled, 'native camera audio decode handled'
v=r~value
call assertEq 16000,v['sample_rate'],'sample rate retained from capture contract'
call assertEq 1,v['channels'],'mono capture contract'
call assertTrue v['frame_count'] >= 1,'decoded frames'
call assertTrue v['sample_count'] > 0,'decoded samples'
call assertTrue v['sample_format'] \= '','decoded sample format'
if v['source_planar'] then do
  call assertEq 1,v['pcm_planes']~items,'mono planar one plane'
  call assertTrue v['pcm_planes'][1]~length > 0,'decoded plane bytes'
end
else call assertTrue v['pcm_bytes']~length > 0,'decoded packed bytes'

say '  format='v['sample_format'] 'frames='v['frame_count'] 'samples='v['sample_count'] 'planar='v['source_planar']
target~close
.AudioLibraryBuild~referenceSwitch=.nil
.RuntimeImplementationSwitch~reset
say 'AUDIO CAMERA NATIVE DECODE: OK'
exit 0

::routine assertTrue
 use strict arg value,label
 if \value then raise syntax 88.900 array('FAILED '||label)
 return
::routine assertEq
 use strict arg expected,actual,label
 if expected \= actual then raise syntax 88.900 array('FAILED '||label||' expected='||expected||' actual='||actual)
 return
::requires '../AudioFFmpegForeignProvider.cls'
