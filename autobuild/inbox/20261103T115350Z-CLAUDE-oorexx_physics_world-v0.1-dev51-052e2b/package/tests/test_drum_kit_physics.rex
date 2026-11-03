call loadMaths
world=.PhysicalWorld~new(.nil,.AcousticMedium~air)
kit=.DrumKitFactory~standardRockKit
call assertEq 9,kit~voices~items,'full standard kit voice count'
call assertTrue kit~voice('kick')<>.nil,'kick present'
call assertTrue kit~voice('snare')<>.nil,'snare present'
call assertTrue kit~voice('hihat')<>.nil,'hihat present'
call assertTrue kit~voice('ride20')<>.nil,'ride present'
call assertTrue kit~voice('snare')~modes~items>4,'snare wire modes present'

p=kit~attachToWorld(world,'stage-left-drums')
call assertEq 'instrument.drum-kit:stage-left-drums',p~checkpointIdentity,'world freeze participant identity'
e0=kit~totalMechanicalEnergy
kit~snare(.22,.25,0)
call assertTrue kit~totalMechanicalEnergy>e0,'snare strike injects modal energy'
kit~kick(.65)
kit~hiHat(.10,.5)
kit~voice('crash16')~strike(.12,.78,0)

do i=1 to 1500; kit~step(.0001); world~advanceSimulationTime(.0001); end
call assertTrue kit~time>0,'kit advances independently'
call assertTrue kit~history~items>2,'acoustic history retained'

cp=world~freeze
x=kit~voice('snare')~modes[1]~displacement
kit~snare(.15,.4,0)
do i=1 to 125;kit~step(.0001);world~advanceSimulationTime(.0001);end
world~restore(cp)
call assertNear x,kit~voice('snare')~modes[1]~displacement,.000000000001,'freeze restores drum mechanics'

before=kit~voice('floorTom16')~mechanicalEnergy
kit~applyUniformAcousticPressure(.8,.001)
call assertTrue kit~voice('floorTom16')~mechanicalEnergy>before,'room pressure sympathetically excites unstruck drum'

say 'PASS drum kit physics'
exit 0

assertEq: procedure
 use strict arg expected,actual,label
 if expected<>actual then do; say 'FAIL' label':' expected expected 'actual' actual; exit 1; end
 return
assertTrue: procedure
 use strict arg value,label
 if \value then do; say 'FAIL' label; exit 1; end
 return
assertNear: procedure
 use strict arg expected,actual,tol,label
 if abs(expected-actual)>tol then do; say 'FAIL' label':' expected expected 'actual' actual; exit 1; end
 return
loadMaths: procedure
 return

::requires 'DrumKitPhysics.cls'
