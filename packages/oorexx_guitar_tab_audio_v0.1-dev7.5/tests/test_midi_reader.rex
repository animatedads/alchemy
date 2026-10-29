parse arg tePath queenPath
if tePath='' then do
  say 'usage: test_midi_reader.rex te_deum.mid bohemian_rhapsody.mid'
  exit 2
end
te=.MidiFileReader~read(tePath)
if te~format<>1 | te~tracks<>3 | te~division<>384 then do; say 'FAIL Te Deum header'; exit 1; end
if te~notes~items<100 then do; say 'FAIL Te Deum notes' te~notes~items; exit 1; end
if te~durationSeconds<15 | te~durationSeconds>16 then do; say 'FAIL Te Deum duration' te~durationSeconds; exit 1; end
if te~noteOnCount<>342 | te~unclosedNoteOns<>0 then do; say 'FAIL Te Deum note accounting' te~noteOnCount te~notes~items te~unclosedNoteOns; exit 1; end
g=.MidiEventSelector~notesForProgram(te,30)
if g~items<>114 then do; say 'FAIL Te Deum distortion-guitar note count' g~items; exit 1; end
v=.MidiGuitarVoicer~voiceSong(te)
if v['voices']~items=0 then do; say 'FAIL Te Deum guitar voicing'; exit 1; end
say 'PASS Te Deum' te~notes~items 'closed notes' te~durationSeconds 'file seconds' v['voices']~items 'guitar-voiceable'

if queenPath<>'' then do
  q=.MidiFileReader~read(queenPath)
  if q~format<>1 | q~tracks<>14 | q~division<>192 then do; say 'FAIL Queen header'; exit 1; end
  if q~noteOnCount<>5925 | q~notes~items<>5923 | q~unclosedNoteOns<>2 then do; say 'FAIL Queen note accounting' q~noteOnCount q~notes~items q~unclosedNoteOns; exit 1; end
  if q~durationSeconds<1006 | q~durationSeconds>1008 then do; say 'FAIL Queen file duration' q~durationSeconds; exit 1; end
  if q~performanceDurationSeconds<328 | q~performanceDurationSeconds>330 then do; say 'FAIL Queen performance duration' q~performanceDurationSeconds; exit 1; end
  qg=.MidiEventSelector~notesForProgram(q,30)
  if qg~items<>546 then do; say 'FAIL Queen distortion-guitar note count' qg~items; exit 1; end
  bends=0
  do c over q~controls
    if c~kind='PITCH_BEND' then do
      bends+=1
      if c~a<>8192 then do; say 'FAIL Queen pitch bends' bends; exit 1; end
    end
  end
  if bends<100 then do; say 'FAIL Queen pitch bends' bends; exit 1; end
  say 'PASS Queen' q~noteOnCount 'note-ons' q~notes~items 'closed' q~unclosedNoteOns 'unclosed' q~performanceDurationSeconds 'performance s' q~durationSeconds 'file s' bends 'pitch-bends'
end
exit 0

::requires '../src/MidiReader.cls'
