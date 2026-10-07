/* ooRexx Photo Survey World v0.1-dev1
   Coarse, movable/resizable scene objects for multi-photo world fitting.
   Geometry is deliberately semantic, not a rendering model.
*/

::class SurveyPose public
::method init
  expose _position _yaw _pitch _roll _context
  use strict arg position=.nil,yaw=0,pitch=0,roll=0,context=.nil
  if context==.nil then context=.Maths~defaultContext
  if position==.nil then position=.MathVector3~new(0,0,0,context)
  _position=position; _yaw=yaw; _pitch=pitch; _roll=roll; _context=context
::method position; expose _position; return _position
::method 'position='; expose _position; use strict arg v; _position=v
::method yaw; expose _yaw; return _yaw
::method 'yaw='; expose _yaw; use strict arg v; _yaw=v
::method pitch; expose _pitch; return _pitch
::method 'pitch='; expose _pitch; use strict arg v; _pitch=v
::method roll; expose _roll; return _roll
::method 'roll='; expose _roll; use strict arg v; _roll=v
::method context; expose _context; return _context
::method moveBy
  expose _position
  use strict arg dx,dy,dz=0
  _position=_position + .MathVector3~new(dx,dy,dz,self~context)
  return self
::method moveTo
  expose _position
  use strict arg x,y,z
  _position=.MathVector3~new(x,y,z,self~context)
  return self

::class SurveySize3D public
::method init
  expose _width _depth _height
  use strict arg width,depth,height
  self~set(width,depth,height)
::method set
  expose _width _depth _height
  use strict arg width,depth,height
  if width<=0 | depth<=0 | height<=0 then raise syntax 88.900 array('positive survey dimensions',width'/'depth'/'height)
  _width=width; _depth=depth; _height=height
  return self
::method width; expose _width; return _width
::method depth; expose _depth; return _depth
::method height; expose _height; return _height

::class SurveyObject public
::method init
  expose _id _kind _pose _size _confidence _semantic _transient
  use strict arg id,kind,width,depth,height,pose=.nil,confidence='0.5',semantic='',transient=.false
  _id=id; _kind=kind~upper; _size=.SurveySize3D~new(width,depth,height)
  if pose==.nil then pose=.SurveyPose~new
  _pose=pose; _confidence=confidence; _semantic=semantic; _transient=transient
::method id; expose _id; return _id
::method kind; expose _kind; return _kind
::method pose; expose _pose; return _pose
::method size; expose _size; return _size
::method confidence; expose _confidence; return _confidence
::method 'confidence='; expose _confidence; use strict arg v; _confidence=v
::method semantic; expose _semantic; return _semantic
::method transient; expose _transient; return _transient
::method moveBy; use strict arg dx,dy,dz=0; self~pose~moveBy(dx,dy,dz); return self
::method moveTo; use strict arg x,y,z; self~pose~moveTo(x,y,z); return self
::method resize
  use strict arg width,depth,height
  self~size~set(width,depth,height); return self
::method scaleBy
  use strict arg sx,sy=.nil,sz=.nil
  if sy==.nil then sy=sx
  if sz==.nil then sz=sx
  return self~resize(self~size~width*sx,self~size~depth*sy,self~size~height*sz)
::method centre; return self~pose~position
::method bottomZ; return self~pose~position~z-self~size~height/2
::method topZ; return self~pose~position~z+self~size~height/2
::method placeOnGround
  use strict arg groundZ
  p=self~pose~position
  self~moveTo(p~x,p~y,groundZ+self~size~height/2)
  return self

::class SurveyBlock subclass SurveyObject public
::method init
  use strict arg id,width,depth,height,pose=.nil,confidence='0.5',semantic='building mass',transient=.false
  self~init:super(id,'BLOCK',width,depth,height,pose,confidence,semantic,transient)

::class SurveyColumn subclass SurveyObject public
::method init
  expose _radius
  use strict arg id,radius,height,pose=.nil,confidence='0.5',semantic='column'
  _radius=radius
  self~init:super(id,'COLUMN',2*radius,2*radius,height,pose,confidence,semantic,.false)
::method radius; expose _radius; return _radius
::method resizeCylinder
  expose _radius
  use strict arg radius,height
  _radius=radius; self~resize(2*radius,2*radius,height); return self

::class SurveyGroundPatch public
::method init
  expose _id _origin _width _depth _slopeX _slopeY _context
  use strict arg id,origin,width,depth,slopeX=0,slopeY=0,context=.nil
  if context==.nil then context=.Maths~defaultContext
  _id=id; _origin=origin; _width=width; _depth=depth; _slopeX=slopeX; _slopeY=slopeY; _context=context
::method id; expose _id; return _id
::method origin; expose _origin; return _origin
::method elevationAt
  expose _origin _slopeX _slopeY
  use strict arg x,y
  return _origin~z + (x-_origin~x)*_slopeX + (y-_origin~y)*_slopeY
::method moveBy
  expose _origin
  use strict arg dx,dy,dz=0
  _origin=_origin + .MathVector3~new(dx,dy,dz,_origin~context); return self
::method resize
  expose _width _depth
  use strict arg width,depth
  if width<=0 | depth<=0 then raise syntax 88.900 array('positive ground dimensions',width'/'depth)
  _width=width; _depth=depth; return self

::class SurveyCamera public
::method init
  expose _id _pose _heightAboveGround _fovY _imageWidth _imageHeight _cameraSpecification _lensId
  use strict arg id,pose=.nil,heightAboveGround='1.60',fovY=60,imageWidth=1,imageHeight=1,cameraSpecification=.nil,lensId='MAIN'
  if pose==.nil then pose=.SurveyPose~new
  _id=id; _pose=pose; _heightAboveGround=heightAboveGround; _fovY=fovY; _imageWidth=imageWidth; _imageHeight=imageHeight
  _cameraSpecification=cameraSpecification; _lensId=lensId
::method id; expose _id; return _id
::method pose; expose _pose; return _pose
::method heightAboveGround; expose _heightAboveGround; return _heightAboveGround
::method 'heightAboveGround='; expose _heightAboveGround; use strict arg v; _heightAboveGround=v
::method fovY; expose _fovY; return _fovY
::method 'fovY='; expose _fovY; use strict arg v; _fovY=v
::method cameraSpecification; expose _cameraSpecification; return _cameraSpecification
::method lensId; expose _lensId; return _lensId
::method 'lensId='; expose _lensId; use strict arg v; _lensId=v~upper
::method imageWidth; expose _imageWidth; return _imageWidth
::method imageHeight; expose _imageHeight; return _imageHeight
::method imageSize
  expose _imageWidth _imageHeight
  return _imageWidth _imageHeight
::method 'imageSize='
  expose _imageWidth _imageHeight
  use strict arg value
  parse var value w h
  if w<=0 | h<=0 then raise syntax 88.900 array('positive image dimensions',w'/'h)
  _imageWidth=w; _imageHeight=h
::method lensSpecification
  expose _cameraSpecification _lensId
  if _cameraSpecification==.nil then return .nil
  return _cameraSpecification~lens(_lensId)
::method setAngles
  use strict arg yaw,pitch,roll=0
  self~pose~yaw=yaw; self~pose~pitch=pitch; self~pose~roll=roll; return self
::method calibratedFovY
  expose _imageWidth _imageHeight
  lens=self~lensSpecification
  if lens==.nil | \lens~hasFov then return self~fovY
  return lens~verticalFov(_imageWidth,_imageHeight,self~pose~context)
::method calibratedFovX
  expose _imageWidth _imageHeight
  lens=self~lensSpecification
  if lens==.nil | \lens~hasFov then return .nil
  return lens~horizontalFov(_imageWidth,_imageHeight,self~pose~context)
::method moveBy; use strict arg dx,dy,dz=0; self~pose~moveBy(dx,dy,dz); return self
::method moveTo; use strict arg x,y,z; self~pose~moveTo(x,y,z); return self
::method placeOnGround
  use strict arg ground
  p=self~pose~position
  z=ground~elevationAt(p~x,p~y)+self~heightAboveGround
  self~moveTo(p~x,p~y,z); return self

::class SurveyWorld public
::method init
  expose _objects _grounds _cameras _context
  use strict arg context=.nil
  if context==.nil then context=.Maths~defaultContext
  _context=context; _objects=.directory~new; _grounds=.directory~new; _cameras=.directory~new
::method context; expose _context; return _context
::method addObject; expose _objects; use strict arg object; _objects[object~id]=object; return object
::method addGround; expose _grounds; use strict arg ground; _grounds[ground~id]=ground; return ground
::method addCamera; expose _cameras; use strict arg camera; _cameras[camera~id]=camera; return camera
::method object; expose _objects; use strict arg id; return _objects[id]
::method ground; expose _grounds; use strict arg id; return _grounds[id]
::method camera; expose _cameras; use strict arg id; return _cameras[id]
::method objectIds; expose _objects; return _objects~allIndexes
::method cameraIds; expose _cameras; return _cameras~allIndexes

::requires 'MathsBootstrap.cls'
::requires 'CameraSpecifications.cls'
