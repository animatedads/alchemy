ctx=.MathContext~decimal(40)
/* 30 degree incidence from air into water. */
theta=.MathAngle~degrees(30,ctx)
d=.MathVector3~new(theta~sin,0,theta~cos,ctx)
n=.MathVector3~new(0,0,-1,ctx)
/* outward normal points toward incident air; ray travels +z */
r=.GeometricOptics~interface(d,n,1,'1.333')
if r['tir'] then do; say 'FAIL unexpected TIR'; exit 1; end
t=r['transmitted']
/* sin(theta2)= transverse component for normalized vector */
expected=theta~sin/'1.333'
call assertNear abs(t~x), expected, 0.0000001, 'Snell air-water transverse component'

/* Dispersion exists in the development BK7 model. */
glass=.OpticalMedium~bk7Approx
nBlue=glass~refractiveIndex(450)
nRed=glass~refractiveIndex(650)
if nBlue<=nRed then do; say 'FAIL expected blue RI > red RI' nBlue nRed; exit 1; end

/* The same prism can be placed at an arbitrary pose and still intersect in world coordinates. */
axis=.MathVector3~new(0,1,0,ctx)
q=.MathQuaternion~fromAxisAngle(axis,.MathAngle~degrees(17,ctx),ctx)
pose=.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),q,ctx)
prism=.OpticalBody~new('odd-prism',.TriangularPrismShape~new(0.03,0.03,0.05,ctx),.PhysicsMaterials~bk7Approx,pose)
ray=.MathRay3D~new(.MathVector3~new(0,0,-0.10,ctx),.MathVector3~new(0,0,1,ctx),ctx)
hit=prism~intersect(ray)
if hit==.nil then do; say 'FAIL rotated prism not intersected'; exit 1; end
say 'PHYSICS REFRACTION + PRISM: OK'
exit 0

assertNear: procedure
  use strict arg actual,expected,tolerance,label
  if abs(actual-expected)>tolerance then do; say 'FAIL' label 'actual='actual 'expected='expected; exit 1; end
  return
::requires 'PhysicsWorld.cls'
