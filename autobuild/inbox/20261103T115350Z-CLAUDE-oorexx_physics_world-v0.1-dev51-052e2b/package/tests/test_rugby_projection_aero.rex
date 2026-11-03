numeric digits 30
ctx=.Maths~defaultContext; d=.directory~new; d['LENGTH']='290 mm'; d['MAX_CIRCUMFERENCE']='600 mm'; b=.PhysicalBody~new('rugby-ball',.SphereShape~new(.1),.PhysicalPose~identity(ctx)); rb=.RigidBodyState~new(b,.MechanicsMassProperties~solidSphere(.410,.1),.MathVector3~new(25,0,0,ctx)); a=.SportsBallAerodynamicProjection~createRugbyLeague(d,rb,1.2,.AxialAerodynamicCoefficientModel~new(.2,.8)); expected=.6/(4*RxCalcArcTan(1,30,'R'))
if abs(a~projectedArea-.29*expected)>.000001 then exit 1
say 'PHYSICS RUGBY PROJECTION AERO: OK broadsideArea=' a~projectedArea
::requires 'RigidBodyAerodynamics.cls'
::requires 'rxmath' LIBRARY
