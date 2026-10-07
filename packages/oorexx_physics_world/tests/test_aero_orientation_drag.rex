numeric digits 30
ctx=.Maths~defaultContext; body=.PhysicalBody~new('ovoid',.SphereShape~new(.1),.PhysicalPose~identity(ctx)); rb=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(.41,.1),.MathVector3~new(30,0,0,ctx)); a=.AerodynamicBodyModel~new(rb,.MathVector3~new(0,1,0,ctx),.29,.19,1.2,.AxialAerodynamicCoefficientModel~new(.2,.8)); o=a~apply
if o~broadsideFraction<.999 | o~force~x>=0 then exit 1
say 'PHYSICS ORIENTATION DRAG: OK area=' o~projectedArea 'Fx=' o~force~x
::requires 'RigidBodyAerodynamics.cls'
