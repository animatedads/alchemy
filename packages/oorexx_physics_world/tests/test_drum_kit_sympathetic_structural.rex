call loadMaths
kit=.DrumKitFactory~standardRockKit
call assertTrue kit~structuralLinks~items>=8,'structural graph published'
receiver=kit~voice('floorTom16')
e0=receiver~mechanicalEnergy
kit~snare(.22,.25,0)
input0=kit~totalMechanicalEnergy
maxReceiver=e0
maxTotal=input0
/* Long enough for the weak reciprocal stand/floor link to transfer measurable energy. */
do i=1 to 6000
  kit~step(.0001)
  er=receiver~mechanicalEnergy
  if er>maxReceiver then maxReceiver=er
  et=kit~totalMechanicalEnergy
  if et>maxTotal then maxTotal=et
end
call assertTrue maxReceiver>e0+.000000000000001,'single snare strike sympathetically energizes connected floor tom'
/* Damped passive coupling may exchange stored spring energy, but must remain bounded. */
call assertTrue maxTotal<=input0*1.02,'symplectic energy excursion remains bounded'
call assertTrue kit~totalMechanicalEnergy<input0,'damping reduces total coupled mechanical energy'
say 'PASS drum kit sympathetic structural coupling' maxReceiver maxTotal input0
exit 0
assertTrue: procedure
 use strict arg value,label
 if \value then do; say 'FAIL' label; exit 1; end
 return
loadMaths: procedure
 return
::requires 'DrumKitPhysics.cls'
