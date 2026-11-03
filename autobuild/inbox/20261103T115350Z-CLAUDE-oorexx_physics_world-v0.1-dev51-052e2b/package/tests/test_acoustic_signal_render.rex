numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
source=.AcousticToneSource~new('speaker',.Units~q(1000,.Units~hertz),.Units~q('0.001',.Units~watt), -
  .PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
solver=.AcousticSolver~new(world); solver~addSource(source); solver~addMicrophone(mic); solver~solveTone(.Units~q(1,.Units~kilohertz))
reading=mic~readingAt(1000)
if reading==.nil then do; say 'FAIL no solved acoustic reading'; exit 1; end

/* Render exactly one 1 kHz period at 48 kHz.  The phasor stores RMS pressure,
   so the RMS of the reconstructed pressure samples must reproduce it. */
buf=.AcousticSignalRenderer~render(mic,.Units~q(1,.Units~millisecond),.Units~q(48000,.Units~hertz))
if buf~sampleCount<>48 then do; say 'FAIL sample count' buf~sampleCount; exit 1; end
call near buf~rmsPressure,reading~pressureRms,'phasor -> pressure-sample RMS','0.00000001'
if \buf~rmsPressureQuantity~dimension~compatible(.Units~pascal~dimension) then do; say 'FAIL sample buffer pressure dimension'; exit 1; end
if buf~metadata['schema']<>'oorexx.physics.acoustic-samples/0.1' then do; say 'FAIL signal metadata schema'; exit 1; end
say 'PHYSICS ACOUSTIC PRESSURE SIGNAL RENDER: OK samples='buf~sampleCount 'rmsPa='buf~rmsPressure
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label 'actual='actual 'expected='expected; exit 1; end
return
::requires 'Acoustics.cls'
