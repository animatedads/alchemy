/* Full deliberately ridiculous qualification:
 * 1 kg rigid block contact sound + a 136 dB SPL, 1 kHz acoustic pressure at
 * the microphone -> physical pressure superposition -> electrical microphone
 * transducer -> Rexx-tronics virtual oscilloscope.
 *
 * 136 dB is defined at the microphone.  This is simulation qualification, not
 * a recommendation to produce that real-world sound level.
 */
numeric digits 40
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
pose=.PhysicalPose~new(.MathVector3~new(0,'0.20',0,ctx),.nil,ctx)
blockBody=.OpticalBody~new('1kg-steel-block',.BoxShape~new('0.1','0.1','0.1',ctx),.nil,pose)
hull=.RigidContactHull~box('0.1','0.1','0.1',ctx)
block=.HullRigidBodyState~new(blockBody,.MechanicsMassProperties~solidBox(1,'0.1','0.1','0.1'),hull,.MathVector3~new(0,'-2',0,ctx),.nil,.false,'0.1')
foot=.CollisionSurface~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),'0.1',.nil,'0.5')
mechanics=.GeneralContactMechanicsSolver~new(world,.MathVector3~new(0,'-9.80665',0,ctx))
mechanics~addBody(block); mechanics~addPlane(foot)
mechanics~step('0.1')
if mechanics~contactEvents~items<1 then do; say 'FAIL no block-foot contact'; exit 1; end

coupler=.StructuralAcousticCoupler~new
mode=.StructuralVibrationMode~new('qualification-block-ring',block,.MathVector3~new(0,'-0.05',0,ctx),.MathVector3~new(0,1,0,ctx), -
  .Units~q(1,.Units~kilogram),.Units~q(1,.Units~kilohertz),.Units~q('0.02',.Units~one),.Units~q(100,.Units~centimetre~power(2)))
coupler~addMode(mode); dummy=coupler~consumeMechanicsStep(mechanics)
physicsMic=.AcousticMicrophone~new('physics-mic',.PhysicalPose~new(.MathVector3~new(0,'0.5',0,ctx),.nil,ctx))
acoustics=.AcousticSolver~new(world)
impact=.MechanicalImpactAcousticRenderer~render(coupler,acoustics,physicsMic,'0.01',48000,mechanics~time)

/* Exact 136 dB RMS pressure at the microphone, 1 kHz. */
referencePa='0.00002'; yellDb=136; frequency=1000
pRms=referencePa*RxCalcExp((yellDb/20)*RxCalcLog(10,35),35)
root2=RxCalcSqrt(2,35); pi=4*RxCalcArcTan(1,35,'R')
combined=.array~new
do i=1 to impact~sampleCount
  t=(i-1)/impact~sampleRateHz
  yell=root2*pRms*RxCalcSin(2*pi*frequency*t,35,'R')
  combined~append(impact~pressureAt(i)+yell)
end
mixed=.AcousticSampleBuffer~new(combined,impact~sampleRateHz,impact~startTime)

sens=.Units~q('0.010',.Units~volt/.Units~pascal)
transducer=.LinearMicrophoneTransducer~new('MIC-COMBINED',sens,'2.5 V','0 V','5 V')
transducer~bindAcousticBuffer(mixed)
scope=.VirtualOscilloscope~new
startPs=(mixed~startTime*.SimTime~PS_PER_S)~round
durationPs=(((mixed~sampleCount-1)*.SimTime~PS_PER_S)/mixed~sampleRateHz)~round
trace=scope~acquireSignal(transducer,startPs,durationPs,mixed~sampleRateQuantity)
measured=trace~measuredFrequency('2.5 V')
if measured==.nil | measured<900 | measured>1100 then do; say 'FAIL combined scope fundamental vicinity' measured; exit 1; end
if trace~maxVoltage<=trace~minVoltage then do; say 'FAIL combined electrical waveform flat'; exit 1; end
say 'REXX-TRONICS BLOCK + 136 dB YELL -> MICROPHONE -> OSCILLOSCOPE: OK'
say 'yell pressure RMS Pa:' pRms
say 'impact peak Pa:' impact~peakAbsPressure
say 'combined SPL dB:' mixed~rmsSplDb(referencePa)
say 'scope frequency Hz:' measured
say 'scope min/max V:' trace~minVoltage trace~maxVoltage
exit 0

::requires 'RexxTronicsAcoustics.cls'
::requires 'MechanicalAcoustics.cls'
::requires 'ContactDynamics.cls'
