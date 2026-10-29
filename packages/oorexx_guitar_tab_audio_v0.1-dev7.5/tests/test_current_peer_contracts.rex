/* dev7.5 current Physics/Maths consumer contract.
 * This is deliberately independent of Rexx-tronics.
 */
numeric digits 30
ctx=.MathContext~decimal(30,'PURE')

string=.GuitarStringPhysicalModel~new(82.4068892,.648,.00045,75,.00008,2.8,.018,3)
renderer=.GuitarMathsModalRenderer~new(string,ctx)
samples=renderer~renderDisplacement(0,.82,8000,16,0,.18,.0008,'PICK',0)
if samples~size<>16 then do; say 'FAIL current peer modal render'; exit 1; end

models=.array~new
do f over .array~of(82.4068892,110,146.832384,195.997718,246.941651,329.627557)
  models~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,2))
end
body=.array~of(.GuitarBodyMode~new('body',180,.2,.03,.05,1))
instrument=.GuitarInstrumentFactory~standardSixString(models,.array~of(0,0,0,0,0,0),body,.GuitarBoundaryImpedance~new('bridge',900,.08),.nil,0,0,.18)
driver=.GuitarAcousticFeedbackDriver~new(instrument,.GuitarAcousticForceCoupling~new(.000002,.045,1,1,'dev7.5 current peer gate'))
driver~step(.00001,.GuitarAcousticPressureObservation~new(0,.1,'peer-gate','direct','dev7.5'))

kit=.DrumKitFactory~standardRockKit
before=kit~totalMechanicalEnergy
kit~snare(.05)
kit~step(.00001)
if kit~totalMechanicalEnergy<=before then do; say 'FAIL current peer drum strike'; exit 2; end

say 'PASS dev7.5 current Physics/Maths peer contract'
exit 0
::requires 'GuitarStringMagnetics.cls'
::requires 'GuitarInstrumentMechanics.cls'
::requires 'GuitarAcousticFeedback.cls'
::requires 'GuitarMathsAcceleration.cls'
::requires 'DrumKitPhysics.cls'
