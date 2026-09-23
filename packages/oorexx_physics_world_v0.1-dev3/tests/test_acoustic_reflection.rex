numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
source=.AcousticToneSource~new('speaker',800,'0.001',.PhysicalPose~new(.MathVector3~new(0,0,1,ctx),.nil,ctx))
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(1,0,1,ctx),.nil,ctx))
wallBody=.PhysicalBody~new('finite-wall',.RectangleShape~new(2,2),.PhysicalPose~identity(ctx))
wall=.AcousticSurface~new(wallBody,.AcousticSurfaceMaterial~rigid)
solver=.AcousticSolver~new(world); solver~addSource(source); solver~addMicrophone(mic); solver~addSurface(wall); solver~solveTone(800)
r=mic~readingAt(800)
if r~contributions~items<>2 then do; say 'FAIL expected direct + finite-wall reflection' r~contributions~items; exit 1; end
found=.false
do c over r~contributions
  if c~kind='REFLECTION' then do
    found=.true
    q=c~interactionPoint
    call near q~x,'0.5','reflection point x','0.00000001'
    call near q~z,0,'reflection point z','0.00000001'
  end
end
if \found then do; say 'FAIL reflected contribution absent'; exit 1; end
/* Same infinite plane orientation, but a tiny finite surface: the geometric reflection point is outside it. */
mic~reset
smallBody=.PhysicalBody~new('tiny-wall',.RectangleShape~new('0.2','0.2'),.PhysicalPose~identity(ctx))
small=.AcousticSurface~new(smallBody,.AcousticSurfaceMaterial~rigid)
solver2=.AcousticSolver~new(world); solver2~addSource(source); solver2~addMicrophone(mic); solver2~addSurface(small); solver2~solveTone(800)
if mic~readingAt(800)~contributions~items<>1 then do; say 'FAIL tiny wall should not receive specular reflection point'; exit 1; end
say 'PHYSICS ACOUSTICS FINITE REFLECTION: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Acoustics.cls'
