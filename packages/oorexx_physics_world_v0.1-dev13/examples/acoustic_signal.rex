/* Solve a physical 1 kHz field and expose one millisecond of microphone
   pressure samples.  Audio/DSP consumers receive Pa + sample-rate evidence;
   Physics does not write a codec-specific WAV file. */
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
source=.AcousticToneSource~new('source',.Units~q(1,.Units~kilohertz),.Units~q('0.001',.Units~watt), -
  .PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
solver=.AcousticSolver~new(world); solver~addSource(source); solver~addMicrophone(mic); solver~solve
buffer=.AcousticSignalRenderer~render(mic,.Units~q(1,.Units~millisecond),.Units~q(48000,.Units~hertz))
say 'samples:' buffer~sampleCount
say 'rate:' buffer~sampleRateQuantity
say 'RMS pressure:' buffer~rmsPressureQuantity
say 'first sample:' buffer~pressureQuantityAt(1)
::requires 'Acoustics.cls'
