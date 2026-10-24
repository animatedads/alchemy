parse arg midiPath outWav outCsv
if midiPath='' then midiPath='master.mid'
if outWav='' then outWav='/mnt/data/master_of_puppets_concurrent_trio_3s.wav'
if outCsv='' then outCsv='/mnt/data/master_of_puppets_concurrent_trio_3s.csv'
startSeconds=29.727243; durationSeconds=3.0; sr=6000
parse source . . scriptPath
say 'PARSING MIDI...'
t0=time('R')
song=.MidiFileReader~read(midiPath)
parseElapsed=time('E')
say 'MIDI_PARSE_S='parseElapsed
say 'STARTING 3 PEER ACTIVITIES...'
r=.ConcurrentBandRenderer~render(song,startSeconds,durationSeconds,sr)
written=.Pcm16WavWriter~writeMono(outWav,r['MIX'],sr)
call lineout outCsv,'metric,value'
call lineout outCsv,'start_s,'startSeconds
call lineout outCsv,'duration_s,'durationSeconds
call lineout outCsv,'sample_rate,'sr
call lineout outCsv,'midi_parse_s,'parseElapsed
call lineout outCsv,'band_elapsed_s,'r['ELAPSED']
call lineout outCsv,'guitar_notes,'r['GUITAR']~noteCount
call lineout outCsv,'bass_notes,'r['BASS']~noteCount
call lineout outCsv,'drum_events,'r['DRUMS']~noteCount
call lineout outCsv,'guitar_elapsed_s,'r['GUITAR']~elapsedSeconds
call lineout outCsv,'bass_elapsed_s,'r['BASS']~elapsedSeconds
call lineout outCsv,'drum_elapsed_s,'r['DRUMS']~elapsedSeconds
call lineout outCsv,'guitar_gain,'r['GUITAR_GAIN']
call lineout outCsv,'bass_gain,'r['BASS_GAIN']
call lineout outCsv,'drum_gain,'r['DRUM_GAIN']
call lineout outCsv
say 'GUITAR_NOTES='r['GUITAR']~noteCount 'TIME='r['GUITAR']~elapsedSeconds
say 'BASS_NOTES='r['BASS']~noteCount 'TIME='r['BASS']~elapsedSeconds
say 'DRUM_EVENTS='r['DRUMS']~noteCount 'TIME='r['DRUMS']~elapsedSeconds
say 'BAND_ELAPSED='r['ELAPSED']
say 'WAV='outWav
exit 0
::requires 'BandConcurrentRenderer.cls'
::requires 'WavWriter.cls'
