numeric digits 30
notes=.array~of(28,33,38,43,40,45,47,52)
do midi over notes
  n=.MidiNoteEvent~new(1,8,26,midi,100,0,120,0,.5)
  v=.MidiBassVoicer~voiceNote(n,24,5)
  if v==.nil then do; say 'FAIL rejected midi='midi; exit 1; end
  opens=.MidiBassVoicer~standardOpenMidi
  if opens[v~stringNumber]+v~fret<>midi then do; say 'FAIL pitch mapping'; exit 1; end
end
n=.MidiNoteEvent~new(1,8,26,27,100,0,120,0,.5)
if .MidiBassVoicer~voiceNote(n,24,5)<>.nil then do; say 'FAIL low-range rejection'; exit 1; end
say 'MIDI BASS VOICER: OK'
::requires 'MidiReader.cls'
