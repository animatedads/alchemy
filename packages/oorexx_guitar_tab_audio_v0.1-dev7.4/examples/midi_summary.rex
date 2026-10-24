parse arg midiPath
if midiPath='' then do; say 'usage: midi_summary.rex file.mid'; exit 2; end
::requires '../src/MidiReader.cls'
s=.MidiFileReader~read(midiPath)
say 'format='s~format 'tracks='s~tracks 'division='s~division
say 'note_ons='s~noteOnCount 'closed_notes='s~notes~items 'unclosed='s~unclosedNoteOns 'unmatched_offs='s~unmatchedNoteOffs
say 'controls='s~controls~items 'performance_s='s~performanceDurationSeconds 'file_duration_s='s~durationSeconds
say 'tempo_events='s~tempos~items
v=.MidiGuitarVoicer~voiceSong(s)
say 'guitar_voiceable='v['voices']~items 'rejected='v['rejected']~items
exit 0

::requires '../src/MidiReader.cls'
