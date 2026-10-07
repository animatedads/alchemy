/* Multi-photo geometric bundle for Photo Survey World v0.1-dev6.
   This is deliberately geometry-first: no pixel stitching and no CV inference. */

::class SurveyWorldPoint public
::method init
  expose _id _position _kind _confidence _notes
  use strict arg id,position,kind='POINT',confidence='0.5',notes=''
  _id=id; _position=position; _kind=kind~upper; _confidence=confidence; _notes=notes
::method id; expose _id; return _id
::method position; expose _position; return _position
::method 'position='; expose _position; use strict arg v; _position=v
::method kind; expose _kind; return _kind
::method confidence; expose _confidence; return _confidence
::method notes; expose _notes; return _notes

::class SurveyBundleObservation public
::method init
  expose _photoId _featureId _u _v _weight _kind _notes
  use strict arg photoId,featureId,u,v,weight='1.0',kind='POINT',notes=''
  _photoId=photoId; _featureId=featureId; _u=u; _v=v; _weight=weight; _kind=kind~upper; _notes=notes
::method photoId; expose _photoId; return _photoId
::method featureId; expose _featureId; return _featureId
::method u; expose _u; return _u
::method v; expose _v; return _v
::method weight; expose _weight; return _weight
::method kind; expose _kind; return _kind
::method notes; expose _notes; return _notes

::class SurveyBundle public
::method init
  expose _world _photos _features _observations
  use strict arg world
  _world=world; _photos=.directory~new; _features=.directory~new; _observations=.array~new
::method addPhoto
  expose _photos
  use strict arg photo
  _photos[photo~id]=photo; return photo
::method addFeature
  expose _features
  use strict arg feature
  _features[feature~id]=feature; return feature
::method addObservation
  expose _observations
  use strict arg observation
  _observations~append(observation); return observation
::method photo; expose _photos; use strict arg id; return _photos[id]
::method feature; expose _features; use strict arg id; return _features[id]
::method observations; expose _observations; return _observations~copy
::method observationCount; expose _observations; return _observations~items
::method reprojectionResidual
  use strict arg observation
  photo=self~photo(observation~photoId); feature=self~feature(observation~featureId)
  if photo==.nil | feature==.nil then return .nil
  p=self~project(photo~camera,feature~position)
  if p==.nil then return .nil
  parse var p pu pv
  du=pu-observation~u; dv=pv-observation~v
  return .Maths~sqrt(du*du+dv*dv,photo~camera~pose~context)
::method rmsReprojectionError
  expose _observations
  sum=0; weights=0
  do o over _observations
    r=self~reprojectionResidual(o)
    if r<>.nil then do
      w=o~weight; sum=sum+w*r*r; weights=weights+w
    end
  end
  if weights=0 then return .nil
  return .Maths~sqrt(sum/weights,.Maths~defaultContext)
::method project
  /* World frame: +X street direction, +Y to camera-left across street, +Z up.
     Camera yaw=0 looks +X; positive yaw rotates towards +Y.
     pitch positive looks upward; roll positive clockwise in image convention. */
  use strict arg camera,point
  cp=camera~pose~position
  dx=point~x-cp~x; dy=point~y-cp~y; dz=point~z-cp~z
  ctx=camera~pose~context
  yaw=.MathAngle~degrees(camera~pose~yaw,ctx)~radiansValue
  pitch=.MathAngle~degrees(camera~pose~pitch,ctx)~radiansValue
  roll=.MathAngle~degrees(camera~pose~roll,ctx)~radiansValue
  cy=.Maths~cos(yaw,ctx); sy=.Maths~sin(yaw,ctx)
  cpit=.Maths~cos(pitch,ctx); spit=.Maths~sin(pitch,ctx)
  cr=.Maths~cos(roll,ctx); sr=.Maths~sin(roll,ctx)
  /* inverse yaw */
  f= cy*dx + sy*dy
  r=-sy*dx + cy*dy
  u=dz
  /* inverse pitch about camera-right */
  f2=cpit*f + spit*u
  u2=-spit*f + cpit*u
  /* inverse roll */
  r2=cr*r + sr*u2
  u3=-sr*r + cr*u2
  if f2<=0 then return .nil
  fovX=.MathAngle~degrees(camera~calibratedFovX,ctx)~radiansValue
  fovY=.MathAngle~degrees(camera~calibratedFovY,ctx)~radiansValue
  fx=(camera~imageWidth/2)/.Maths~tan(fovX/2,ctx)
  fy=(camera~imageHeight/2)/.Maths~tan(fovY/2,ctx)
  px=camera~imageWidth/2 + fx*r2/f2
  py=camera~imageHeight/2 - fy*u3/f2
  return px py

::class SurveyStreetFrame public
::method init
  expose _name _axisBearing _notes
  use strict arg name='LOCAL_STREET',axisBearing=0,notes=''
  _name=name; _axisBearing=axisBearing; _notes=notes
::method name; expose _name; return _name
::method axisBearing; expose _axisBearing; return _axisBearing
::method notes; expose _notes; return _notes

::requires 'PhotoObservation.cls'

/* dev6 inverse camera geometry.  This is the algebraic inverse of project()
   for a pinhole ray.  It does not infer correspondences from image pixels. */
::class SurveyRay public
::method init
  expose _origin _direction
  use strict arg origin,direction
  _origin=origin; _direction=direction
::method origin; expose _origin; return _origin
::method direction; expose _direction; return _direction
::method pointAt
  use strict arg distance
  return self~origin + self~direction*distance

::class SurveyCameraGeometry public
::method pixelRay class
  use strict arg camera,px,py
  ctx=camera~pose~context
  fovX=.MathAngle~degrees(camera~calibratedFovX,ctx)~radiansValue
  fovY=.MathAngle~degrees(camera~calibratedFovY,ctx)~radiansValue
  fx=(camera~imageWidth/2)/.Maths~tan(fovX/2,ctx)
  fy=(camera~imageHeight/2)/.Maths~tan(fovY/2,ctx)
  /* Camera coordinates before roll/pitch/yaw: forward, right, up. */
  f2=1
  r2=(px-camera~imageWidth/2)/fx
  u3=-(py-camera~imageHeight/2)/fy
  yaw=.MathAngle~degrees(camera~pose~yaw,ctx)~radiansValue
  pitch=.MathAngle~degrees(camera~pose~pitch,ctx)~radiansValue
  roll=.MathAngle~degrees(camera~pose~roll,ctx)~radiansValue
  cy=.Maths~cos(yaw,ctx); sy=.Maths~sin(yaw,ctx)
  cpit=.Maths~cos(pitch,ctx); spit=.Maths~sin(pitch,ctx)
  cr=.Maths~cos(roll,ctx); sr=.Maths~sin(roll,ctx)
  /* Undo inverse roll used by SurveyBundle~project. */
  r=cr*r2-sr*u3
  u2=sr*r2+cr*u3
  /* Undo inverse pitch. */
  f=cpit*f2-spit*u2
  u=spit*f2+cpit*u2
  /* Undo inverse yaw. */
  dx=cy*f-sy*r
  dy=sy*f+cy*r
  dz=u
  mag=.Maths~sqrt(dx*dx+dy*dy+dz*dz,ctx)
  direction=.MathVector3~new(dx/mag,dy/mag,dz/mag,ctx)
  return .SurveyRay~new(camera~pose~position,direction)
::method intersectHorizontalPlane class
  use strict arg ray,z
  dz=ray~direction~z
  if abs(dz)<0.000000000001 then return .nil
  t=(z-ray~origin~z)/dz
  if t<=0 then return .nil
  return ray~pointAt(t)
