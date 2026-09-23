/* Wire3DMathsAdapter.cls -- the sole Wire3D <-> ooRexx Maths v0.8 conversion seam.
   Wire3D owns spatial semantics. Maths owns numerical 3D algebra and conventions. */
::class Wire3DMathsAdapter public
::method context class
  expose _context
  if \var('_context') then _context=.MathContext~decimal(50)
  return _context
::method convention class
  return .Math3DConvention~openGL
::method vector3 class
  use strict arg value
  return .Maths~vector3(value~x,value~y,value~z,self~context)
::method quaternion class
  use strict arg value
  /* Wire3D's public order is x,y,z,w; Maths deliberately constructs w,x,y,z. */
  return .Maths~quaternion(value~w,value~x,value~y,value~z,self~context)
::method transform class
  use strict arg value
  ctx=self~context; conv=self~convention
  p=value~position; s=value~scale
  t=.MathTransform3D~translation(p~x,p~y,p~z,ctx,conv)
  r=.MathTransform3D~rotation(self~quaternion(value~rotation),ctx,conv)
  z=.MathTransform3D~scale(s~x,s~y,s~z,ctx,conv)
  /* Maths v0.8 column-vector contract: T*R*S applies scale, then rotation, then translation. */
  return t*r*z
::method columnMajor class
  use strict arg transform
  return transform~toColumnMajorArray

/* Semantic camera. It owns camera intent; ooRexx Maths owns the matrix algebra. */
::class Wire3DSpatialCamera public
::attribute eye get
::attribute target get
::attribute up get
::attribute fovY get
::attribute near get
::attribute far get
::method init
  expose eye target up fovY near far
  use strict arg eye=.nil,target=.nil,up=.nil,fovY=60,near='0.1',far=100
  if eye==.nil then eye=.Wire3DVector3~new(0,4,12)
  if target==.nil then target=.Wire3DVector3~new(0,0,0)
  if up==.nil then up=.Wire3DVector3~new(0,1,0)
::method lookAt
  expose eye target up
  use strict arg newEye,newTarget,newUp=.nil
  eye=newEye; target=newTarget; if newUp\==.nil then up=newUp
  return self
::method viewTransform
  expose eye target up
  a=.Wire3DMathsAdapter
  return .MathTransform3D~lookAt(a~vector3(eye),a~vector3(target),a~vector3(up),a~context,a~convention)
::method projectionFor
  expose fovY near far
  use strict arg width,height
  if width<=0 | height<=0 then raise syntax 88.900 array('positive viewport dimensions',width' x 'height)
  a=.Wire3DMathsAdapter; ctx=a~context
  /* Establish working precision before evaluating aspect at this caller boundary. */
  numeric digits ctx~workingDigits
  angle=.Maths~angleDegrees(fovY,ctx)
  aspect=width/height
  return .Maths~perspective(angle,aspect,near,far,ctx,a~convention)
::method viewProjectionFor
  use strict arg width,height
  return self~projectionFor(width,height)*self~viewTransform
::method asDirectory
  expose eye target up fovY near far
  d=.directory~new; d['eye']=eye~asDirectory; d['target']=target~asDirectory; d['up']=up~asDirectory
  d['fovYDegrees']=fovY; d['near']=near; d['far']=far; d['convention']='OPENGL'
  return d

/* Package visibility is package-local in ooRexx; do not rely on Wire3DAll.cls
   requiring these on behalf of this sibling package. */
::requires 'MathsBootstrap.cls'
::requires 'Wire3DCore.cls'
