numeric digits 30
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)
mat=.MechanicalMaterial~new('brittle-test',2500,1000,0,10,0,0)
gc=.Units~joule/.Units~squareMetre
law=.BrittleFractureLaw~new('strength-plus-energy',.Units~q(50,.Units~pascal),,.Units~q(10,gc))
a=.DeformableNode~new(zero,1,,.true)
b=.DeformableNode~new(.MathVector3~new(1.06,0,0,ctx),1)
link=.DeformableLink~new(a,b,.Units~q(1,.Units~squareMetre),mat,.Units~q(1,.Units~metre),law)
link~apply
if link~broken then call fail 'strength alone broke link before energy criterion was met'
b~position=.MathVector3~new(1.2,0,0,ctx)
link~apply
if \link~broken then call fail 'strength + energy criterion did not break link'
if link~fractureCriterion<>'TENSION_ENERGY' then call fail 'unexpected fracture criterion' link~fractureCriterion
call near link~fractureStress,200,'0.0000001','fracture stress'
call near link~fractureEnergy,20,'0.0000001','fracture elastic energy'
call near link~fractureSurfaceEnergy,10,'0.0000001','surface creation energy'
call near link~unresolvedFractureEnergy,10,'0.0000001','unresolved released energy'
call near link~fractureEnergyQuantity~in(.Units~joule),20,'0.0000001','typed fracture energy'
call near link~fractureStressQuantity~in(.Units~pascal),200,'0.0000001','typed fracture stress'
say 'PHYSICS FRACTURE STRENGTH + ENERGY: OK'
exit 0
near: procedure
  use arg actual,expected,tol,label
  if abs(actual-expected)>tol then do; say 'FAIL' label actual expected; exit 1; end
  return
fail: procedure
  use arg msg,detail
  say 'FAIL' msg detail; exit 1
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
