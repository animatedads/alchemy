numeric digits 30
ctx=.Maths~defaultContext
body=.PhysicalBody~new('slosh-vessel',.BoxShape~new(.6,.4,.3,ctx),.PhysicalPose~identity(ctx))
state=.RigidBodyState~new(body,.MechanicsMassProperties~solidBox(4,.6,.4,.3))
tank=.RectangularTankGeometry~new(.5,.2,.25,64)
slosh=.RectangularTankSlosh1D~new(.FluidMedium~water20C,tank,.015,.05)
coupling=.FreeSurfaceVesselCoupling~new(slosh,state)
gravity=.MathVector3~new(0,-9.80665,0,ctx)
acceleration=.MathVector3~new(2,0,0,ctx)

do n=1 to 300
  coupling~advanceKinematics(.001,acceleration,gravity)
end
if slosh~surfaceRange<=.0001 then do; say 'FAIL prescribed vessel acceleration produced no slosh'; exit 1; end
if abs(slosh~centreOfMassLocal~x)<=.00001 then do; say 'FAIL coupled liquid centre remained exactly centred'; exit 1; end
if coupling~freeSurfacePointsWorld~items<>tank~cellCount then do; say 'FAIL world free-surface projection point count'; exit 1; end
call near coupling~centreOfMassWorld~x,slosh~centreOfMassLocal~x,'identity-pose liquid COM projection','0.000000001'
report=coupling~applyCurrentLoad
if report~localForce~norm<=0 then do; say 'FAIL coupled free surface produced no vessel load'; exit 1; end
if state~force~norm<=0 then do; say 'FAIL free-surface load was not submitted to rigid body'; exit 1; end
say 'PHYSICS FREE-SURFACE VESSEL COUPLING: OK range='slosh~surfaceRange 'xCOM='slosh~centreOfMassLocal~x 'load='report~localForce~norm
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'FreeSurfaceFluids.cls'
