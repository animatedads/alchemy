/* ooRexx Photo Survey World observation model v0.1-dev3
   Separates physical camera/lens, stored image processing, and survey pose.
*/

::class SurveyImageProcessing public
::method init
  expose _distortionCorrected _cropped _cropLeft _cropTop _cropWidth _cropHeight _orientation _hdr _notes
  use strict arg distortionCorrected=.nil,cropped=.false,cropLeft=.nil,cropTop=.nil,cropWidth=.nil,cropHeight=.nil,orientation='UNKNOWN',hdr=.nil,notes=''
  _distortionCorrected=distortionCorrected; _cropped=cropped
  _cropLeft=cropLeft; _cropTop=cropTop; _cropWidth=cropWidth; _cropHeight=cropHeight
  _orientation=orientation~upper; _hdr=hdr; _notes=notes
::method distortionCorrected; expose _distortionCorrected; return _distortionCorrected
::method cropped; expose _cropped; return _cropped
::method cropLeft; expose _cropLeft; return _cropLeft
::method cropTop; expose _cropTop; return _cropTop
::method cropWidth; expose _cropWidth; return _cropWidth
::method cropHeight; expose _cropHeight; return _cropHeight
::method orientation; expose _orientation; return _orientation
::method hdr; expose _hdr; return _hdr
::method notes; expose _notes; return _notes
::method effectiveWidth
  use strict arg storedWidth
  if self~cropped then do
    if self~cropWidth<>.nil then return self~cropWidth
  end
  return storedWidth
::method effectiveHeight
  use strict arg storedHeight
  if self~cropped then do
    if self~cropHeight<>.nil then return self~cropHeight
  end
  return storedHeight

::class SurveyCameraUnit public
::method init
  expose _id _specification _label
  use strict arg id,specification,label=''
  _id=id; _specification=specification; _label=label
::method id; expose _id; return _id
::method specification; expose _specification; return _specification
::method label; expose _label; return _label

::class SurveyPhotoObservation public
::method init
  expose _id _width _height _camera _cameraUnit _processing _source _notes _lensConfidence
  use strict arg id,width,height,camera,cameraUnit=.nil,processing=.nil,source='',notes='',lensConfidence='0.5'
  if width<=0 | height<=0 then raise syntax 88.900 array('positive stored image dimensions',width'/'height)
  if processing==.nil then processing=.SurveyImageProcessing~new
  _id=id; _width=width; _height=height; _camera=camera; _cameraUnit=cameraUnit
  _processing=processing; _source=source; _notes=notes; _lensConfidence=lensConfidence
  self~syncCameraImagePlane
::method id; expose _id; return _id
::method width; expose _width; return _width
::method height; expose _height; return _height
::method camera; expose _camera; return _camera
::method cameraUnit; expose _cameraUnit; return _cameraUnit
::method processing; expose _processing; return _processing
::method source; expose _source; return _source
::method notes; expose _notes; return _notes
::method lensConfidence; expose _lensConfidence; return _lensConfidence
::method 'lensConfidence='; expose _lensConfidence; use strict arg v; _lensConfidence=v
::method effectiveWidth; expose _width; return self~processing~effectiveWidth(_width)
::method effectiveHeight; expose _height; return self~processing~effectiveHeight(_height)
::method aspectRatio; return self~effectiveWidth/self~effectiveHeight
::method syncCameraImagePlane
  self~camera~imageSize=(self~effectiveWidth self~effectiveHeight)
  return self
::method cameraHeightPrior
  return self~camera~heightAboveGround
::method lensSpecification
  return self~camera~lensSpecification
::method nominalFovX; return self~camera~calibratedFovX
::method nominalFovY; return self~camera~calibratedFovY

::class SurveyFeatureObservation public
::method init
  expose _id _photoId _kind _coordinates _sceneFeatureId _confidence _status _notes
  use strict arg id,photoId,kind,coordinates,sceneFeatureId='',confidence='0.5',status='VISIBLE',notes=''
  _id=id; _photoId=photoId; _kind=kind~upper; _coordinates=coordinates
  _sceneFeatureId=sceneFeatureId; _confidence=confidence; _status=status~upper; _notes=notes
::method id; expose _id; return _id
::method photoId; expose _photoId; return _photoId
::method kind; expose _kind; return _kind
::method coordinates; expose _coordinates; return _coordinates
::method sceneFeatureId; expose _sceneFeatureId; return _sceneFeatureId
::method confidence; expose _confidence; return _confidence
::method status; expose _status; return _status
::method notes; expose _notes; return _notes

::requires 'SurveyWorld.cls'

/* Rigid multi-camera handset rig.  Offsets are metres in handset coordinates:
   +X right, +Y up, +Z forward.  A station pose is the handset reference pose. */
::class SurveyCameraRig public
::method init
  expose _id _units _offsets _notes
  use strict arg id,notes=''
  _id=id; _units=.directory~new; _offsets=.directory~new; _notes=notes
::method id; expose _id; return _id
::method notes; expose _notes; return _notes
::method addUnit
  expose _units _offsets
  use strict arg unit,offsetX=0,offsetY=0,offsetZ=0
  _units[unit~id]=unit
  _offsets[unit~id]=offsetX offsetY offsetZ
  return unit
::method unit; expose _units; use strict arg id; return _units[id]
::method offset
  expose _offsets
  use strict arg id
  return _offsets[id]
::method baseline
  use strict arg firstId,secondId
  parse value self~offset(firstId) with ax ay az
  parse value self~offset(secondId) with bx by bz
  dx=bx-ax; dy=by-ay; dz=bz-az
  return .Maths~sqrt(dx*dx+dy*dy+dz*dz,.Maths~defaultContext)

::class SurveyRigStation public
::method init
  expose _id _rig _x _y _z _yaw _pitch _roll _notes
  use strict arg id,rig,x,y,z='1.60',yaw=0,pitch=0,roll=0,notes=''
  _id=id; _rig=rig; _x=x; _y=y; _z=z; _yaw=yaw; _pitch=pitch; _roll=roll; _notes=notes
::method id; expose _id; return _id
::method rig; expose _rig; return _rig
::method x; expose _x; return _x
::method y; expose _y; return _y
::method z; expose _z; return _z
::method yaw; expose _yaw; return _yaw
::method pitch; expose _pitch; return _pitch
::method roll; expose _roll; return _roll
::method notes; expose _notes; return _notes
::method cameraPosition
  expose _x _y _z
  /* For the present calibration pair the measured separation is vertical.
     Keep the transform explicit so non-vertical offsets can be added later. */
  use strict arg unitId
  parse value self~rig~offset(unitId) with ox oy oz
  return .MathVector3~new(_x+ox,_y+oz,_z+oy,.Maths~defaultContext)
::method placeCamera
  use strict arg camera,unitId
  p=self~cameraPosition(unitId)
  camera~moveTo(p~x,p~y,p~z)
  camera~setAngles(self~yaw,self~pitch,self~roll)
  return camera
