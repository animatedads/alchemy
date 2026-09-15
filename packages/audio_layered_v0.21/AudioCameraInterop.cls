/* AudioCameraInterop.cls - adjacent Camera Behaviour capture provenance without ownership collapse */

::class AudioCameraCaptureReference public
::attribute cameraId get
::attribute clipId get
::attribute cameraProductionToken get
::attribute sourcePath get
::attribute mountId get
::attribute role get
::attribute orientation get
::attribute attributes get

::method init
  expose cameraId clipId cameraProductionToken sourcePath mountId role orientation attributes
  use strict arg cameraIdArg, clipIdArg = '', cameraProductionTokenArg = '', sourcePathArg = '', mountIdArg = '', roleArg = '', orientationArg = '', attributesArg = .nil
  if attributesArg == .nil then attributesArg=.Directory~new
  cameraId=cameraIdArg~string
  clipId=clipIdArg~string
  cameraProductionToken=cameraProductionTokenArg~string
  sourcePath=sourcePathArg~string
  mountId=mountIdArg~string
  role=roleArg~string
  orientation=orientationArg~string
  attributes=.AudioUtil~copyDirectory(attributesArg)

::method fromCamera class
  use strict arg camera, clipSummary = .nil, sourcePath = '', mountId = '', role = '', orientation = '', attributes = .nil
  if camera == .nil then raise syntax 88.900 array('AudioCameraCaptureReference requires a camera object')
  cameraId=camera~id
  clipId=''; token=''
  if clipSummary \== .nil then clipId=clipSummary~clipId
  /* Camera production identity belongs to Camera.  Audio records only its compact token when available. */
  signal on syntax name noProduction
  identity=camera~productionIdentity
  if identity \== .nil then token=identity~compactToken
noProduction:
  return self~new(cameraId,clipId,token,sourcePath,mountId,role,orientation,attributes)

::method canonicalText
  return 'CAMERA_CAPTURE=' || self~cameraId || '|clip=' || self~clipId || '|producer=' || self~cameraProductionToken || '|source=' || self~sourcePath || '|mount=' || self~mountId || '|role=' || self~role || '|orientation=' || self~orientation || '|attributes=' || .AudioUtil~canonicalDirectory(self~attributes)

::class AudioCameraSceneBinding public
::attribute recordingId get
::attribute capture get

::method init
  expose recordingId capture
  use strict arg recordingIdArg, captureArg
  if \captureArg~isa(.AudioCameraCaptureReference) then raise syntax 88.900 array('AudioCameraSceneBinding requires AudioCameraCaptureReference')
  recordingId=recordingIdArg~string
  capture=captureArg

::method canonicalText
  return 'CAMERA_SCENE_BINDING=' || self~recordingId || '|' || self~capture~canonicalText

::class AudioCameraSceneBridge public
::method add class
  use strict arg scene, recording, capture
  if \scene~isa(.AudioScene) then raise syntax 88.900 array('AudioCameraSceneBridge requires AudioScene')
  if \recording~isa(.AudioRecording) then raise syntax 88.900 array('AudioCameraSceneBridge requires AudioRecording')
  if \capture~isa(.AudioCameraCaptureReference) then raise syntax 88.900 array('AudioCameraSceneBridge requires AudioCameraCaptureReference')
  attrs=.AudioUtil~copyDirectory(capture~attributes)
  attrs['camera_id']=capture~cameraId
  attrs['camera_clip_id']=capture~clipId
  attrs['camera_production_token']=capture~cameraProductionToken
  attrs['camera_source_path']=capture~sourcePath
  member=scene~addRecording(recording,capture~mountId,capture~role,capture~orientation,attrs)
  return .AudioCameraSceneBinding~new(recording~id,capture)

::requires 'AudioScene.cls'

