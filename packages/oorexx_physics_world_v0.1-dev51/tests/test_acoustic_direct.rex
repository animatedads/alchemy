numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
source=.AcousticToneSource~new('speaker',1000,'0.001',.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
solver=.AcousticSolver~new(world)
solver~addSource(source); solver~addMicrophone(mic)
solver~solveTone(1000)
r=mic~readingAt(1000)
if r==.nil then do; say 'FAIL no microphone reading'; exit 1; end
pi=4*RxCalcArcTan(1,30,'R')
expected=RxCalcSqrt('0.001'*.AcousticMedium~air~impedance/(4*pi))
call near r~pressureRms,expected,'1m pressure from isotropic acoustic power','0.000000001'
c=r~contributions
if c~items<>1 then do; say 'FAIL expected one direct path' c~items; exit 1; end
call near c[1]~delay,1/.AcousticMedium~air~soundSpeed,'propagation delay','0.000000001'
if r~splDb==.nil then do; say 'FAIL expected finite SPL'; exit 1; end
say 'PHYSICS ACOUSTICS DIRECT PROPAGATION: OK pressure='r~pressureRms 'Pa SPL='r~splDb 'dB'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label 'actual='actual 'expected='expected; exit 1; end
return
::requires 'Acoustics.cls'
