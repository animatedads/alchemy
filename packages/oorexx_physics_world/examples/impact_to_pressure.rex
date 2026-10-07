/* Mechanics contact -> structural vibration -> sampled acoustic pressure. */
numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)

pose=.PhysicalPose~new(.MathVector3~new(0,'0.15',0,ctx),.nil,ctx)
body=.OpticalBody~new('steel-ball',.SphereShape~new('0.1'),.nil,pose)
state=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(1,'0.1'),.MathVector3~new(0,-1,0,ctx),.nil,.false,0,'0.1')
plane=.CollisionPlane~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),0)
mechanics=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
mechanics~addBody(state); mechanics~addPlane(plane)
mechanics~step(.Units~q(100,.Units~millisecond))

event=mechanics~contactEvents[1]
say 'contact impulse:' event~impulseMagnitude 'N*s'
say 'contact dissipated energy:' event~dissipatedEnergy 'J'

coupler=.StructuralAcousticCoupler~new
mode=.StructuralVibrationMode~new('ring-mode',state,.MathVector3~new(0,'-0.1',0,ctx),.MathVector3~new(0,1,0,ctx), -
  .Units~q(1,.Units~kilogram),.Units~q(1,.Units~kilohertz),.Units~q('0.02',.Units~one), -
  .Units~q(100,.Units~centimetre~power(2)))
coupler~addMode(mode)
responses=coupler~consumeMechanicsStep(mechanics)
say 'excited modes:' responses~items
say 'modal energy:' coupler~modalMechanicalEnergy 'J'
say 'unallocated dissipated energy:' coupler~unallocatedDissipatedEnergy 'J'

mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(0,1,0,ctx),.nil,ctx))
acoustics=.AcousticSolver~new(world)
buffer=.MechanicalImpactAcousticRenderer~render(coupler,acoustics,mic,.Units~q(10,.Units~millisecond),.Units~q(48,.Units~kilohertz),mechanics~time)
say 'samples:' buffer~sampleCount
say 'sample rate:' buffer~sampleRateHz 'Hz'
say 'peak pressure:' buffer~peakAbsPressure 'Pa'
say 'RMS pressure:' buffer~rmsPressure 'Pa'

::requires 'MechanicalAcoustics.cls'
