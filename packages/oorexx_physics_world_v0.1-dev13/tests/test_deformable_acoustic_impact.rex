numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
mat=.MechanicalMaterial~mildSteel
body=.DeformableBody~new('panel')
v=.MathVector3~new(0,-1,0,ctx)
a=.DeformableNode~new(.MathVector3~new('-0.1','0.05',0,ctx),1/3,v)
b=.DeformableNode~new(.MathVector3~new('-0.1','0.05','0.1',ctx),1/3,v)
c=.DeformableNode~new(.MathVector3~new('0.1','0.05',0,ctx),1/3,v)
body~addNode(a); body~addNode(b); body~addNode(c)
area=.Units~q(1,.Units~millimetre~power(2))
body~addLink(.DeformableLink~new(a,b,area,mat))
body~addLink(.DeformableLink~new(b,c,area,mat))
body~addLink(.DeformableLink~new(c,a,area,mat))
plane=.DeformableContactPlane~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),0)
solver=.DeformableSolver~new(.MathVector3~new(0,0,0,ctx))
solver~addBody(body); solver~addPlane(plane)
solver~step(.Units~q(100,.Units~millisecond))
events=solver~contactEvents
if events~items<>3 then do; say 'FAIL deformable contact count' events~items; exit 1; end
totalImpulse=0; totalDissipated=0
do e over events
  totalImpulse=totalImpulse+e~impulseOnNode~y
  totalDissipated=totalDissipated+e~dissipatedEnergy
end
call near totalImpulse,1,'deformable patch total normal impulse','0.000000001'
call near totalDissipated,'0.5','deformable patch contact dissipation','0.000000001'

coupler=.StructuralAcousticCoupler~new
mode=.DeformablePatchVibrationMode~new('panel-mode',body,a,b,c,.Units~q(1,.Units~kilogram),.Units~q(800,.Units~hertz), -
  .Units~q('0.03',.Units~one),.Units~q(200,.Units~centimetre~power(2)))
coupler~addMode(mode)
made=coupler~consumeDeformableStep(solver)
if made~items<>3 then do; say 'FAIL deformable acoustic responses' made~items; exit 1; end
sumV=0
do response over made; sumV=sumV+response~initialVelocity; end
call near sumV,1,'deformable modal impulse sum / mass','0.000000001'
call near coupler~contactDissipatedEnergy,'0.5','deformable contact energy ledger','0.000000001'
call near coupler~modalMechanicalEnergy,1/6,'deformable modal energy ledger','0.000000001'
call near coupler~unallocatedDissipatedEnergy,1/3,'deformable unallocated energy','0.000000001'
call near mode~normal~y,1,'deformed patch geometric normal','0.000000001'

mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(0,1,0,ctx),.nil,ctx))
acoustic=.AcousticSolver~new(world)
buf=.MechanicalImpactAcousticRenderer~render(coupler,acoustic,mic,.Units~q(12,.Units~millisecond),.Units~q(48,.Units~kilohertz),solver~time)
if buf~sampleCount<>576 then do; say 'FAIL deformable audio sample count' buf~sampleCount; exit 1; end
if buf~peakAbsPressure<=0 then do; say 'FAIL deformable impact rendered silent'; exit 1; end
say 'PHYSICS DEFORMABLE -> ACOUSTIC IMPACT: OK impulse='totalImpulse 'N*s peakPa='buf~peakAbsPressure
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label 'actual='actual 'expected='expected; exit 1; end
return
::requires 'MechanicalAcoustics.cls'
