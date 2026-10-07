numeric digits 20
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
carrier=.PhysicalBody~new('carrier',.BoxShape~new(1,1,1,ctx),.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
mount=.PhysicalMount~new(carrier,.PhysicalPose~new(.MathVector3~new('0.25',0,0,ctx),.nil,ctx))
source=.AcousticToneSource~onMount('mounted-speaker',mount,600,'0.001')
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new('2.25',0,0,ctx),.nil,ctx))
solver=.AcousticSolver~new(world); solver~addSource(source); solver~addMicrophone(mic); solver~solveTone(600)
p1=mic~readingAt(600)~pressureRms
carrier~pose=.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx)
mic~reset; solver~solveTone(600)
p2=mic~readingAt(600)~pressureRms
/* Mount follows carrier: source-listener distance changes 2 m -> 1 m. */
if abs(p2/p1-2)>'0.000001' then do; say 'FAIL mounted acoustic source did not follow shared physical mount' p2/p1; exit 1; end
say 'PHYSICS ACOUSTICS PHYSICAL MOUNT: OK'
::requires 'Acoustics.cls'
