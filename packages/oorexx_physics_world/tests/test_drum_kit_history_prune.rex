call loadMaths
kit=.DrumKitFactory~standardRockKit
/* Tiny history forces repeated pruning quickly. */
voices=kit~voices
short=.DrumKitPhysics~new(voices,0,.003,kit~structuralLinks)
short~snare(.12)
do i=1 to 200; short~step(.0001); end
call assertTrue short~history~items>1,'history retained after repeated FIFO pruning'
h=short~history
call assertTrue h[1]<>.nil,'history head remains compact after pruning'
call assertTrue h[h~items]<>.nil,'history tail remains addressable'
/* Interpolation across retained compact queue must not NOMETHOD on .nil. */
t=(h[1]~time+h[h~items]~time)/2
a=short~sampleVoiceAccelerationAt('snare',t)
say 'PASS drum kit history pruning' short~history~items a
exit 0
assertTrue: procedure
 use strict arg value,label
 if \value then do; say 'FAIL' label; exit 1; end
 return
loadMaths: procedure
 return
::requires 'DrumKitPhysics.cls'
