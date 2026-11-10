numeric digits 30
ctx=.Maths~defaultContext
water=.FluidMedium~water20C
field=.UniformFluidField~new(water,.MathVector3~new(1,0,0,ctx),0)
world=.PhysicalWorld~new(.OpticalMedium~air,.nil,water)
body=.PhysicalBody~new('test-sphere',.SphereShape~new('0.05'),.PhysicalPose~identity(ctx))
world~addBody(body)
rb=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(2,'0.05'))
profile=.FluidHydrodynamicProfile~sphere(.Units~q(5,.Units~centimetre),'0.47')
gravity=.MathVector3~new(0,'-9.80665',0,ctx)
coupling=.FullySubmergedFluidCoupling~new(field,rb,profile,gravity)
report=coupling~forceReport
call near report~buoyancyForce~y,'5.12550738284216','buoyancy y','0.000000001'
call near report~dragForce~x,'1.84236344975283','drag x','0.000000001'
call near report~dragForce~y,0,'drag y'
call near report~reynoldsNumber,'99620.7584830339','coupling Reynolds','0.000001'
if \report~buoyancyMagnitudeQuantity~dimension~compatible(.Units~newton~dimension) then do; say 'FAIL buoyancy force units'; exit 1; end
coupling~apply
call near rb~force~x,report~totalForce~x,'applied fluid force x','0.000000001'
call near rb~force~y,report~totalForce~y,'applied fluid force y','0.000000001'
say 'PHYSICS FLUID RIGID COUPLING: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Fluids.cls'
