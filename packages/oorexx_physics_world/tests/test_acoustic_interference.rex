numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
pose=.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx)
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
/* First source alone. */
s1=.AcousticToneSource~new('s1',1000,'0.001',pose,0)
one=.AcousticSolver~new(world); one~addSource(s1); one~addMicrophone(mic); one~solveTone(1000)
p1=mic~readingAt(1000)~pressureRms
/* Two coherent sources in phase: pressure amplitude doubles, not acoustic power scalar addition at the sensor. */
mic~reset
s2=.AcousticToneSource~new('s2',1000,'0.001',pose,0)
two=.AcousticSolver~new(world); two~addSource(s1); two~addSource(s2); two~addMicrophone(mic); two~solveTone(1000)
p2=mic~readingAt(1000)~pressureRms
call near p2/p1,2,'coherent in-phase pressure ratio','0.00000001'
/* Same source strength, opposite phase: cancellation. */
mic~reset
pi=4*RxCalcArcTan(1,30,'R')
s3=.AcousticToneSource~new('s3',1000,'0.001',pose,pi)
cancel=.AcousticSolver~new(world); cancel~addSource(s1); cancel~addSource(s3); cancel~addMicrophone(mic); cancel~solveTone(1000)
pc=mic~readingAt(1000)~pressureRms
if pc>'0.0000001' then do; say 'FAIL coherent cancellation' pc; exit 1; end
say 'PHYSICS ACOUSTICS INTERFERENCE: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Acoustics.cls'
