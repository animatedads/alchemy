numeric digits 30
ctx=.Maths~defaultContext
water=.FluidMedium~water20C
flow=.UniformFluidField~new(water,.MathVector3~new(1,0,0,ctx),0)
body=.PhysicalBody~new('sphere',.SphereShape~new('0.05'),.PhysicalPose~identity(ctx))
rb=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(2,'0.05'))
profile=.FluidHydrodynamicProfile~sphere(.Units~q(5,.Units~centimetre),'0.47')
coupling=.FullySubmergedFluidCoupling~new(flow,rb,profile)
report=coupling~forceReport
say 'drag N:' report~dragMagnitudeQuantity~in(.Units~newton)
say 'buoyancy N:' report~buoyancyMagnitudeQuantity~in(.Units~newton)
say 'Re:' report~reynoldsNumber
exit 0
::requires 'Fluids.cls'
