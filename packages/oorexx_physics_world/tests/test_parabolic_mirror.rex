ctx=.MathContext~decimal(40)
f=0.1
shape=.ParaboloidShape~new(f,0.30)
focus=.MathVector3~new(0,0,f,ctx)
target=.MathVector3~new(0.1,0,(0.1*0.1)/(4*f),ctx)
direction=(target-focus)~normalized
ray=.MathRay3D~new(focus,direction,ctx)
hit=shape~intersect(ray)
if hit==.nil then do; say 'FAIL paraboloid focus ray missed'; exit 1; end
reflected=.GeometricOptics~reflect(direction,hit~normal)
call assertNear reflected~x,0,0.0000001,'paraboloid reflected x'
call assertNear reflected~y,0,0.0000001,'paraboloid reflected y'
call assertNear reflected~z,1,0.0000001,'paraboloid reflected parallel axis'
say 'PHYSICS PARABOLIC MIRROR: OK'
exit 0
assertNear: procedure
  use strict arg actual,expected,tolerance,label
  if abs(actual-expected)>tolerance then do; say 'FAIL' label actual expected; exit 1; end
  return
::requires 'PhysicsWorld.cls'
