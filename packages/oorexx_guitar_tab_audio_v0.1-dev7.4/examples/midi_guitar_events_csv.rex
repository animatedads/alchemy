/* Export a selected General MIDI program as physical guitar string/fret events.
 * GM program numbers here use the SMF wire value (0..127); Distortion Guitar is 30.
 */
parse arg midiPath outPath program
if midiPath='' | outPath='' then do
  say 'usage: midi_guitar_events_csv.rex input.mid output.csv [program=30]'
  exit 2
end
if program='' then program=30
opened=stream(outPath,'c','open write replace')
call stream outPath,'c','close'
song=.MidiFileReader~read(midiPath)
selected=.MidiEventSelector~notesForProgram(song,program)
voiced=.MidiEventSelector~voiceNotes(selected)
call lineout outPath,'start_s,duration_s,midi_note,frequency_hz,velocity,channel,program,string,fret'
do v over voiced['voices']
  n=v~noteEvent
  call lineout outPath,n~startSeconds','n~durationSeconds','n~note','n~frequencyHz','n~velocity','n~channel','n~program','v~stringNumber','v~fret
end
call lineout outPath
say 'program='program 'selected='selected~items 'voiced='voiced['voices']~items 'rejected='voiced['rejected']~items 'output='outPath
exit 0

::requires '../src/MidiReader.cls'
