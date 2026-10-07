ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
solver=.AcousticSolver~new(world)
solver~addSource(.AcousticToneSource~new('a',440,'0.001',.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx)))
solver~addSource(.AcousticToneSource~new('b',880,'0.001',.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx)))
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
solver~addMicrophone(mic)
solver~solve
if mic~readingAt(440)==.nil then do; say 'FAIL solve() missing 440 Hz'; exit 1; end
if mic~readingAt(880)==.nil then do; say 'FAIL solve() missing 880 Hz'; exit 1; end
say 'PHYSICS ACOUSTICS MULTI-FREQUENCY SOLVE: OK'
::requires 'Acoustics.cls'
