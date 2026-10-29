kit=.DrumKitFactory~standardRockKit
before=kit~voice('snare')~mechanicalEnergy
ok=.MidiDrumPerformer~dispatch(kit,38,127)
if \ok then do; say 'FAIL snare mapping rejected'; exit 1; end
if kit~voice('snare')~mechanicalEnergy<=before then do; say 'FAIL snare MIDI did not inject physical energy'; exit 1; end
floor0=kit~voice('floorTom16')~mechanicalEnergy
do i=1 to 6000; kit~step(.0001); end
if kit~voice('floorTom16')~mechanicalEnergy<=floor0 then do; say 'FAIL connected floor tom did not sympathetically respond'; exit 1; end
say 'PASS MIDI drum mapping and sympathetic kit response'
exit 0
::requires '../src/MidiDrumRenderer.cls'
