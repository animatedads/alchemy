numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air)
sourcePose=.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx)
sensorPose=.PhysicalPose~new(.MathVector3~new(0,0,.02,ctx),.nil,ctx)
probe=.OpticalBeamProbe~new(world,sourcePose,sensorPose,.01,.01,555,1,'rexxtronics-dev8-sensor')
reading=probe~sample
if \reading~isA(.OpticalBeamReading) then do; say 'FAIL OpticalBeamReading public type'; exit 1; end
if \probe~sensor~isA(.OpticalSensor) then do; say 'FAIL OpticalSensor public type'; exit 1; end
call near reading~transmission,1,'clear Physics transmission','0.000000000001'
baseline=.Photometry~isotropicRectangleAverageIlluminance(20,.01,.01,.02)
call near baseline,'47086.0048','20 cd / 1 cm^2 / 2 cm rectangular-aperture baseline','0.0001'
accepted=baseline*reading~transmission
call near accepted,baseline,'Rexx-tronics adapter accepted illuminance','0.0000001'
call near probe~sensor~received,1,'sensor received optical weight','0.0000001'
say 'PHYSICS REXX-TRONICS DEV8 OPTICAL CONTRACT: OK baseline='baseline
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Coupling.cls'
