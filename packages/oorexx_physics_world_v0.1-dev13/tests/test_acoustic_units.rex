numeric digits 30
rho=.Units~q('1.2',.Units~kilogramPerCubicMetre)
c=.Units~q(340,.Units~metrePerSecond)
z=rho*c
impedanceUnit=.Units~pascal*.Units~second/.Units~metre
call near z~in(impedanceUnit),408,'density * sound speed = acoustic impedance','0.0000001'

microPascal=.Units~prefixed(.Units~pascal,'micro','u','0.000001')
p=.Units~q(20,microPascal)
call near p~in(.Units~pascal),'0.00002','20 uPa pressure reference','0.0000000001'

f=.Units~q(1,.Units~kilohertz)
if f~dimension~canonical<>.Units~hertz~dimension~canonical then do; say 'FAIL hertz dimension'; exit 1; end

/* Public acoustic boundaries accept shared UnitQuantity directly. */
medium=.AcousticMedium~new('typed-air',rho,c)
call near medium~density,'1.2','typed density accepted'
call near medium~soundSpeed,340,'typed sound speed accepted'
call near medium~impedanceQuantity~in(impedanceUnit),408,'typed impedance output'
call near medium~wavelengthQuantity(f)~in(.Units~metre),'0.34','typed wavelength output','0.0000001'

ctx=.Maths~defaultContext
src=.AcousticToneSource~new('typed-source',f,.Units~q('0.001',.Units~watt), -
  .PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx),.Units~q(0,.Units~radian))
mic=.AcousticMicrophone~new('typed-mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx),p)
world=.PhysicalWorld~new(.OpticalMedium~air,medium)
solver=.AcousticSolver~new(world); solver~addSource(src); solver~addMicrophone(mic); solver~solveTone(f)
r=mic~readingAt(1000)
if r==.nil then do; say 'FAIL typed solve produced no reading'; exit 1; end
if \r~pressureQuantity~dimension~compatible(.Units~pascal~dimension) then do; say 'FAIL pressure quantity dimension'; exit 1; end
if \r~contributions[1]~delayQuantity~dimension~compatible(.Units~second~dimension) then do; say 'FAIL delay quantity dimension'; exit 1; end

call expectBadFrequency ctx
say 'PHYSICS ACOUSTICS SHARED UNITS: OK'
exit 0

expectBadFrequency: procedure
  use strict arg ctx
  signal on syntax name expected
  bad=.AcousticToneSource~new('bad',.Units~q(5,.Units~metre),.Units~q(1,.Units~watt), -
    .PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
  say 'FAIL length accepted as frequency'; exit 1
expected:
  return

near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Acoustics.cls'
