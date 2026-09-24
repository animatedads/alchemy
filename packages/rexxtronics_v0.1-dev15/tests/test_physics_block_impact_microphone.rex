/* 1 kg rigid box contact -> structural mode -> acoustic pressure ->
 * Rexx-tronics microphone electrical waveform.
 * Structural mode properties are explicit qualification parameters, not
 * inferred universal properties of "steel".
 */
numeric digits 40
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)

/* 100 mm cube, 1 kg, represented by an eight-point rigid contact hull. */
pose=.PhysicalPose~new(.MathVector3~new(0,'0.20',0,ctx),.nil,ctx)
blockBody=.OpticalBody~new('1kg-steel-block',.BoxShape~new('0.1','0.1','0.1',ctx),.nil,pose)
hull=.RigidContactHull~box(.Units~q(10,.Units~centimetre),.Units~q(10,.Units~centimetre),.Units~q(10,.Units~centimetre),ctx)
block=.HullRigidBodyState~new(blockBody,.MechanicsMassProperties~solidBox(1,'0.1','0.1','0.1'),hull,.MathVector3~new(0,'-2',0,ctx),.nil,.false,'0.1')

/* A fixed plane is the qualification "foot surface" contact target. */
footSurface=.CollisionSurface~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),'0.1',.nil,'0.5')
mechanics=.GeneralContactMechanicsSolver~new(world,.MathVector3~new(0,'-9.80665',0,ctx))
mechanics~addBody(block); mechanics~addPlane(footSurface)
mechanics~step(.Units~q(100,.Units~millisecond))
if mechanics~contactEvents~items < 1 then do; say 'FAIL no block contact event'; exit 1; end

coupler=.StructuralAcousticCoupler~new
mode=.StructuralVibrationMode~new('qualification-block-ring',block,.MathVector3~new(0,'-0.05',0,ctx),.MathVector3~new(0,1,0,ctx), -
  .Units~q(1,.Units~kilogram),.Units~q(1,.Units~kilohertz),.Units~q('0.02',.Units~one),.Units~q(100,.Units~centimetre~power(2)))
coupler~addMode(mode)
responses=coupler~consumeMechanicsStep(mechanics)
if responses~items < 1 then do; say 'FAIL block impact did not excite structural mode'; exit 1; end

physicsMic=.AcousticMicrophone~new('physics-mic',.PhysicalPose~new(.MathVector3~new(0,'0.5',0,ctx),.nil,ctx))
acoustics=.AcousticSolver~new(world)
buffer=.MechanicalImpactAcousticRenderer~render(coupler,acoustics,physicsMic,.Units~q(10,.Units~millisecond),.Units~q(48,.Units~kilohertz),mechanics~time)
if buffer~peakAbsPressure <= 0 then do; say 'FAIL impact acoustic buffer silent'; exit 1; end

sensitivityUnit=.Units~volt/.Units~pascal
transducer=.LinearMicrophoneTransducer~new('MIC-BLOCK',.Units~q('0.010',sensitivityUnit),'2.5 V','0 V','5 V')
transducer~bindAcousticBuffer(buffer)
scope=.VirtualOscilloscope~new
startPs=(buffer~startTime*.SimTime~PS_PER_S)~round
lastDurationPs=(((buffer~sampleCount-1)*.SimTime~PS_PER_S)/buffer~sampleRateHz)~round
trace=scope~acquireSignal(transducer,startPs,lastDurationPs,buffer~sampleRateQuantity)
if trace~maxVoltage = trace~minVoltage then do; say 'FAIL electrical microphone waveform is flat'; exit 1; end
say 'REXX-TRONICS 1 kg BLOCK IMPACT -> PHYSICS -> MICROPHONE -> SCOPE: OK'
say 'contact events:' mechanics~contactEvents~items
say 'impact peak Pa:' buffer~peakAbsPressure
say 'scope min/max V:' trace~minVoltage trace~maxVoltage
exit 0

::requires 'RexxTronicsAcoustics.cls'
::requires 'MechanicalAcoustics.cls'
::requires 'ContactDynamics.cls'
