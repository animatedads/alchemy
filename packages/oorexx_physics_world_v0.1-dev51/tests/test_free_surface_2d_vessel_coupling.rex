numeric digits 30
ctx=.Maths~defaultContext
body=.PhysicalBody~new('2d-slosh-vessel',.BoxShape~new(.8,.5,.35,ctx),.PhysicalPose~identity(ctx))
state=.RigidBodyState~new(body,.MechanicsMassProperties~solidBox(8,.8,.5,.35))
tank=.RectangularTankGeometry2D~new(.6,.4,.25,10,8)
slosh=.RectangularTankSlosh2D~new(.FluidMedium~water20C,tank,.036,.05)
origin=.MathVector3~new(.10,.02,-.08,ctx)
coupling=.FreeSurfaceVesselCoupling2D~new(slosh,state,.nil,.nil,.nil,origin)
gravity=.MathVector3~new(0,-9.80665,0,ctx)
accel=.MathVector3~new(1.4,0,-.7,ctx)

do n=1 to 160
  coupling~advanceKinematics(.0015,accel,gravity)
end
com=slosh~centreOfMassLocal
if com~x>=0 then do; say 'FAIL 2D coupled x COM sign' com~x; exit 1; end
if com~z<=0 then do; say 'FAIL 2D coupled z COM sign' com~z; exit 1; end
call near coupling~centreOfMassWorld~x,origin~x+com~x,'2D identity-pose COM x projection','0.000000001'
call near coupling~centreOfMassWorld~z,origin~z+com~z,'2D identity-pose COM z projection','0.000000001'
report=coupling~applyCurrentLoad
if report~localForce~norm<=0 then do; say 'FAIL 2D coupled load zero'; exit 1; end
if state~force~norm<=0 then do; say 'FAIL 2D coupled force not submitted'; exit 1; end
if state~torque~norm<=0 then do; say 'FAIL 2D off-centre tank produced no torque'; exit 1; end
say 'PHYSICS FREE-SURFACE 2D VESSEL COUPLING: OK force='report~localForce~norm 'torque='state~torque~norm
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'FreeSurfaceFluids2D.cls'
