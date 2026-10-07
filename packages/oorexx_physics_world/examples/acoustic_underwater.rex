/* Same ideal radiated acoustic power and geometry; only the world medium changes. */
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~water,.AcousticMedium~water)
source=.AcousticToneSource~new('source',1000,'0.001', -
    .PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
hydrophone=.AcousticMicrophone~new('hydrophone', -
    .PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx),'0.000001')
solver=.AcousticSolver~new(world)
solver~addSource(source); solver~addMicrophone(hydrophone); solver~solveTone(1000)
r=hydrophone~readingAt(1000)
say 'medium:' world~ambientAcoustic~name
say 'pressure RMS:' r~pressureRms 'Pa'
say 'arrival delay:' r~contributions[1]~delay 's'
say 'SPL:' r~splDb 'dB re 1 uPa'
::requires 'Acoustics.cls'
