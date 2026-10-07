ctx=.Maths~defaultContext; b=.PhysicalBody~new('still',.SphereShape~new(.1),.PhysicalPose~identity(ctx)); rb=.RigidBodyState~new(b,.MechanicsMassProperties~solidSphere(.41,.1)); a=.AerodynamicBodyModel~new(rb,.MathVector3~new(0,1,0,ctx),.29,.19,1.2,.AxialAerodynamicCoefficientModel~new(.2,.8)); o=a~apply
if o~force~norm<>0 | o~torque~norm<>0 then exit 1
say 'PHYSICS AERODYNAMIC ZERO RELATIVE VELOCITY: OK'
::requires 'RigidBodyAerodynamics.cls'
