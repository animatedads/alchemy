/* Wire3D / Maths v0.8 boundary qualification. */
numeric digits 9
ctx=.Wire3DMathsAdapter~context
call assert ctx~requestedDigits=50, 'Wire3D Maths context requests 50 digits'

wq=.Wire3DQuaternion~new(1,2,3,4)
mq=.Wire3DMathsAdapter~quaternion(wq)
call assert mq~w=4 & mq~x=1 & mq~y=2 & mq~z=3, 'x/y/z/w -> w/x/y/z quaternion boundary'

wt=.Wire3DTransform~new(.Wire3DVector3~new(3,4,5),.Wire3DQuaternion~new(0,0,0,1),.Wire3DVector3~new(2,2,2))
mt=.Wire3DMathsAdapter~transform(wt)
p=mt*.Maths~vector3(1,0,0,ctx)
call assert p~maxAbsDifference(.Maths~vector3(5,4,5,ctx)) < '1E-35', 'T*R*S transform semantics'

camera=.Wire3DSpatialCamera~new(.Wire3DVector3~new(0,4,12),.Wire3DVector3~new(0,0,0))
vp=camera~viewProjectionFor(1080,2400)
call assert vp~convention~handedness='RIGHT_HANDED', 'OpenGL right-handed convention'
call assert vp~convention~depthRange='NEGATIVE_ONE_TO_ONE', 'OpenGL NDC depth convention'
flat=vp~toColumnMajorArray
call assert flat~items=16, 'WebGL column-major matrix has 16 values'

/* Demo object centres must produce finite homogeneous clip coordinates with positive w. */
do spec over .array~of(.array~of(-3,0,0),.array~of(3,0,0),.array~of(0,0,-2))
  clip=vp~matrix*.Maths~vector4(spec[1],spec[2],spec[3],1,ctx)
  call assert clip~w>0, 'demo centre lies in front of camera'
  nx=clip~x/clip~w; ny=clip~y/clip~w; nz=clip~z/clip~w
  call assert nx>=-1 & nx<=1 & ny>=-1 & ny<=1 & nz>=-1 & nz<=1, 'demo centre lies inside OpenGL clip volume'
end
say 'PASS test_maths3d_integration'
exit 0
assert: procedure
  use strict arg ok, label
  if \ok then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return

::requires 'Wire3DAll.cls'
