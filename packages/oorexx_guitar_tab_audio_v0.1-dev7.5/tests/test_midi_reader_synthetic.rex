p='/tmp/oorexx_guitar_midi_reader_fixture.mid'
hex='4D54686400000006000000010060' ||,
    '4D54726B00000019' ||,
    '00FF510307A120' ||,
    '00C01E' ||,
    '00904064' ||,
    '604000' ||,
    '00E00040' ||,
    '00FF2F00'
opened=stream(p,'c','open write replace')
call charout p,x2c(hex)
call stream p,'c','close'

s=.MidiFileReader~read(p)
if s~format<>0 | s~tracks<>1 | s~division<>96 then do; say 'FAIL MIDI synthetic header'; exit 1; end
if s~noteOnCount<>1 | s~notes~items<>1 | s~unclosedNoteOns<>0 then do; say 'FAIL MIDI synthetic note accounting'; exit 1; end
n=s~notes[1]
if n~program<>30 | n~note<>64 | n~velocity<>100 then do; say 'FAIL MIDI synthetic note fields'; exit 1; end
if abs(n~durationSeconds-.5)>.0000001 then do; say 'FAIL MIDI synthetic duration' n~durationSeconds; exit 1; end
bends=0
do c over s~controls
  if c~kind='PITCH_BEND' then do
    bends+=1
    if c~a<>8192 then do; say 'FAIL MIDI synthetic bend value' c~a; exit 1; end
  end
end
if bends<>1 then do; say 'FAIL MIDI synthetic bend count' bends; exit 1; end
v=.MidiGuitarVoicer~voiceSong(s)
if v['voices']~items<>1 then do; say 'FAIL MIDI synthetic guitar voicing'; exit 1; end
say 'PASS MIDI synthetic' n~startSeconds n~durationSeconds 'program' n~program 'string' v['voices'][1]~stringNumber 'fret' v['voices'][1]~fret
exit 0

::requires '../src/MidiReader.cls'
