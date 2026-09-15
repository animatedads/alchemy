say 'AUDIO CAMERA INTEROP START'
rec=.AudioRecording~new('REC-CAM-A',60000)
attrs=.Directory~new; attrs['capture_family']='camera_behaviour_oorexx'
cap=.AudioCameraCaptureReference~new('CAM-A','CLIP-3605','CPI-TOKEN','/evidence/1000053605.mp4','MOUNT-PAIR-1','rear','180deg',attrs)
scene=.AudioScene~new('SCENE-CAM','paired opposite-facing camera capture')
binding=.AudioCameraSceneBridge~add(scene,rec,cap)
call assertEq 'REC-CAM-A',binding~recordingId,'recording binding'
call assertEq 'CAM-A',binding~capture~cameraId,'camera identity retained'
text=scene~canonicalText
call assertTrue text~pos('camera_id=CAM-A')>0,'camera id projected into scene member attributes'
call assertTrue text~pos('camera_clip_id=CLIP-3605')>0,'camera clip id projected'
call assertTrue text~pos('mount=MOUNT-PAIR-1')>0,'mount hypothesis belongs to audio scene'
call assertTrue cap~canonicalText~pos('producer=CPI-TOKEN')>0,'camera production token retained without ownership transfer'
say 'AUDIO CAMERA INTEROP: OK'
exit 0
::routine assertTrue
 use strict arg v,l
 if \v then raise syntax 88.900 array('FAILED '||l)
 return
::routine assertEq
 use strict arg e,a,l
 if e\=a then raise syntax 88.900 array('FAILED '||l||' expected='||e||' actual='||a)
 return
::requires '../AudioCameraInterop.cls'
