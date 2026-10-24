/* Short articulation fixture in Drop D: hammer-ons, dead notes and two-string unison/octave weight. */
parse arg outFile
if outFile='' then outFile='guitar_demo.wav'
lines=.array~of( -
'e|--------------------------------|', -
'B|--------------------------------|', -
'G|--------------------------------|', -
'D|--------------3h4---------------|', -
'A|--0--3h5--x-x-----5--0--2h3--2--|', -
'D|--0-------x-x--------0--2h3--2--|')
events=.AsciiTabParser~parse(lines)
config=.GuitarRenderConfig~new(8000,92,4,2.6,.GuitarTuning~dropD)
render=.GuitarTabRenderer~render(events,config)
pressure=render~at('PRESSURE')
.Pcm16WavWriter~writeMono(outFile,pressure~samples,pressure~sampleRateHz)
say 'TAB EVENTS:' events~items
say 'PRESSURE SAMPLES:' pressure~sampleCount
say 'RMS PRESSURE PA:' pressure~rmsPressure
say 'PEAK PRESSURE PA:' pressure~peakAbsPressure
say 'WAV:' outFile
::requires 'AsciiTab.cls'
::requires 'GuitarPhysics.cls'
::requires 'WavWriter.cls'
