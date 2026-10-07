ctx=.Maths~defaultContext; b=.PhysicalBody~new('spin',.SphereShape~new(.1),.PhysicalPose~identity(ctx)); rb=.RigidBodyState~new(b,.MechanicsMassProperties~solidSphere(.41,.1),.MathVector3~new(20,0,0,ctx),.MathVector3~new(0,0,50,ctx)); a=.AerodynamicBodyModel~new(rb,.MathVector3~new(0,1,0,ctx),.29,.19,1.2,.AxialAerodynamicCoefficientModel~new(.2,.8,.1)); f=a~force
if f~y<=0 then exit 1
say 'PHYSICS SPIN LIFT DIRECTION: OK Fy=' f~y
::requires 'RigidBodyAerodynamics.cls'
