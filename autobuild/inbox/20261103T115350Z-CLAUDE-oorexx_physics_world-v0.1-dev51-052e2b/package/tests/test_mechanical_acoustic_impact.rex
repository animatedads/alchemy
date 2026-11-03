numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
pose=.PhysicalPose~new(.MathVector3~new(0,'0.15',0,ctx),.nil,ctx)
body=.OpticalBody~new('struck-body',.SphereShape~new('0.1'),.nil,pose)
state=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(1,'0.1'),.MathVector3~new(0,-1,0,ctx),.nil,.false,0,'0.1')
plane=.CollisionPlane~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),0)
mechanics=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
mechanics~addBody(state); mechanics~addPlane(plane)
mechanics~step(.Units~q(100,.Units~millisecond))

coupler=.StructuralAcousticCoupler~new
patchAreaUnit=.Units~centimetre~power(2)
mode=.StructuralVibrationMode~new('normal-ring',state,.MathVector3~new(0,'-0.1',0,ctx),.MathVector3~new(0,1,0,ctx), -
  .Units~q(1,.Units~kilogram),.Units~q(1,.Units~kilohertz),.Units~q('0.02',.Units~one),.Units~q(100,patchAreaUnit))
/* Orthogonal structural mode must not be excited by the vertical impulse. */
modeX=.StructuralVibrationMode~new('orthogonal',state,.MathVector3~new(0,'-0.1',0,ctx),.MathVector3~new(1,0,0,ctx), -
  .Units~q(1,.Units~kilogram),.Units~q(1,.Units~kilohertz),.Units~q('0.02',.Units~one),.Units~q(100,patchAreaUnit))
coupler~addMode(mode); coupler~addMode(modeX)
made=coupler~consumeMechanicsStep(mechanics)
if made~items<>1 then do; say 'FAIL excited mode count' made~items; exit 1; end
response=made[1]
call near response~initialVelocity,1,'J/m modal velocity','0.000000001'
call near response~initialMechanicalEnergy,'0.5','modal energy','0.000000001'
call near coupler~contactDissipatedEnergy,'0.5','contact energy ledger','0.000000001'
call near coupler~modalMechanicalEnergy,'0.5','modal energy ledger','0.000000001'
call near coupler~unallocatedDissipatedEnergy,0,'unallocated contact energy','0.000000001'
if \response~initialMechanicalEnergyQuantity~dimension~compatible(.Units~joule~dimension) then do; say 'FAIL modal energy dimension'; exit 1; end

mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(0,1,0,ctx),.nil,ctx))
acoustic=.AcousticSolver~new(world); acoustic~addMicrophone(mic)
distance=(mic~position-response~sourcePosition)~norm
delay=distance/world~ambientAcoustic~soundSpeed
arrival=response~startTime+delay
before=.MechanicalImpactAcousticRenderer~pressureAt(response,acoustic,mic,arrival-'0.000000001')
atArrival=.MechanicalImpactAcousticRenderer~pressureAt(response,acoustic,mic,arrival)
call near before,0,'causal silence before arrival','0.000000000001'
if abs(atArrival)<'0.000001' then do; say 'FAIL impact pressure at arrival is zero'; exit 1; end
/* At tau=0: a = -2*zeta*omega*v0.  Compact-patch pressure follows rho*A*a/(4*pi*r). */
pi=4*RxCalcArcTan(1,30,'R')
expected=world~ambientAcoustic~density*mode~radiatingArea*(-2*mode~dampingRatio*response~omegaNatural*response~initialVelocity)/(4*pi*distance)
call near atArrival,expected,'retarded compact-patch pressure','0.000000001'

/* Same retarded state at twice the distance has half the pressure amplitude. */
mic2=.AcousticMicrophone~new('mic2',.PhysicalPose~new(.MathVector3~new(0,2,0,ctx),.nil,ctx))
distance2=(mic2~position-response~sourcePosition)~norm
arrival2=response~startTime+distance2/world~ambientAcoustic~soundSpeed
p2=.MechanicalImpactAcousticRenderer~pressureAt(response,acoustic,mic2,arrival2)
call near abs(atArrival/p2),distance2/distance,'inverse-distance impact pressure','0.000001'

buf=.MechanicalImpactAcousticRenderer~render(coupler,acoustic,mic,.Units~q(10,.Units~millisecond),.Units~q(48,.Units~kilohertz),response~startTime)
if buf~sampleCount<>480 then do; say 'FAIL impact sample count' buf~sampleCount; exit 1; end
if buf~peakAbsPressure<=0 then do; say 'FAIL rendered impact buffer is silent'; exit 1; end
/* First sample is before the propagation delay. */
call near buf~pressureAt(1),0,'render begins before acoustic arrival','0.000000000001'
say 'PHYSICS MECHANICAL -> ACOUSTIC IMPACT: OK delay='delay 's arrivalPa='atArrival 'peakPa='buf~peakAbsPressure
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label 'actual='actual 'expected='expected; exit 1; end
return
::requires 'MechanicalAcoustics.cls'
