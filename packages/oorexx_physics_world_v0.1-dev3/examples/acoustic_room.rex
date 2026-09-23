/* One coherent tone, one finite rigid wall, one microphone. */
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
source=.AcousticToneSource~new('speaker',1000,'0.001', -
    .PhysicalPose~new(.MathVector3~new(0,0,1,ctx),.nil,ctx))
mic=.AcousticMicrophone~new('microphone', -
    .PhysicalPose~new(.MathVector3~new(1,0,1,ctx),.nil,ctx))
wallBody=.PhysicalBody~new('wall',.RectangleShape~new(2,2),.PhysicalPose~identity(ctx))
wall=.AcousticSurface~new(wallBody,.AcousticSurfaceMaterial~rigid)
solver=.AcousticSolver~new(world)
solver~addSource(source); solver~addMicrophone(mic); solver~addSurface(wall)
solver~solveTone(1000)
r=mic~readingAt(1000)
say 'pressure RMS:' r~pressureRms 'Pa'
say 'SPL:' r~splDb 'dB re 20 uPa'
do c over r~contributions
  say c~kind 'distance='c~distance 'm delay='c~delay 's pressure='c~phasor~magnitude 'Pa'
end
::requires 'Acoustics.cls'
