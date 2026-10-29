parse arg midiPath outWav outCsv startSeconds durationSeconds
if midiPath='' then do; say 'usage: demo_master_puppets_drums.rex input.mid output.wav [gauges.csv] [start=29.727243] [duration=2.0]'; exit 2; end
if outWav='' then outWav='master_of_puppets_drums_real_physics.wav'
if outCsv='' then outCsv='master_of_puppets_drums_real_physics_gauges.csv'
if startSeconds='' then startSeconds=29.727243
if durationSeconds='' then durationSeconds=2.0
song=.MidiFileReader~read(midiPath)
r=.MidiDrumRenderer~render(song,startSeconds,durationSeconds,6000)
written=.Pcm16WavWriter~writeMono(outWav,r~samples,r~sampleRate)
gauges=.MidiDrumRenderer~writeGaugesCsv(outCsv,r)
say 'MIDI_DRUM_EVENTS='r~events~items
say 'SAMPLES='r~samples~items
say 'START_S='r~startSeconds
say 'DURATION_S='r~durationSeconds
say 'WAV='outWav
say 'GAUGES='outCsv
exit 0

::requires '../src/MidiDrumRenderer.cls'
::requires '../src/WavWriter.cls'
