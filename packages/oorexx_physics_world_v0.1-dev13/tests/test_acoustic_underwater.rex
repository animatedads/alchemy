numeric digits 30
ctx=.Maths~defaultContext
sourcePose=.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx)
micPose=.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx)
source=.AcousticToneSource~new('speaker',1000,'0.001',sourcePose)
/* Same physical source power and geometry; only the world acoustic medium changes. */
airWorld=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
airMic=.AcousticMicrophone~new('air-mic',micPose)
airSolver=.AcousticSolver~new(airWorld); airSolver~addSource(source); airSolver~addMicrophone(airMic); airSolver~solveTone(1000)
airReading=airMic~readingAt(1000)
waterWorld=.PhysicalWorld~new(.OpticalMedium~water,.AcousticMedium~water)
waterMic=.AcousticMicrophone~new('hydrophone',micPose,'0.000001')
waterSolver=.AcousticSolver~new(waterWorld); waterSolver~addSource(source); waterSolver~addMicrophone(waterMic); waterSolver~solveTone(1000)
waterReading=waterMic~readingAt(1000)
expectedRatio=RxCalcSqrt(.AcousticMedium~water~impedance/.AcousticMedium~air~impedance)
call near waterReading~pressureRms/airReading~pressureRms,expectedRatio,'pressure ratio follows medium impedance','0.00001'
airDelay=airReading~contributions[1]~delay
waterDelay=waterReading~contributions[1]~delay
if waterDelay>=airDelay then do; say 'FAIL expected shorter 1m propagation delay in development water model'; exit 1; end
say 'PHYSICS ACOUSTICS WORLD UNDER WATER: OK airDelay='airDelay 'waterDelay='waterDelay
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Acoustics.cls'
