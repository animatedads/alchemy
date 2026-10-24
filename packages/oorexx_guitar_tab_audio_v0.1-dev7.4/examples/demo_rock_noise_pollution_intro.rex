/* AC/DC tab-derived standard-tuning cross-package proof.
 * Tempo is a demo sequencing parameter, not a claim about the recording. */
parse arg outFile gaugeFile
if outFile='' then outFile='rock_noise_pollution_dev5_auto.wav'
if gaugeFile='' then gaugeFile='rock_noise_pollution_dev5_auto_gauges.csv'
lines=.array~of( -
'e|-------------||------------------|------------------|-------------------||', -
'B|--0---2---3--||---2---2---3------|-------0---2---3--|---2---2-----------||', -
'G|--1---2---4--||---2---2---4------|-------1---2---4--|---2---2------9\-||', -
'D|-------------||------------------|---2--------------|--------------9\-||', -
'A|-------------||---0---0---0------|---2--------------|---0---0------7\-||', -
'E|-------------||---------------3--|---0--------------|-----------3--0----||')
events=.AsciiTabParser~parse(lines)
config=.GuitarRenderConfig~new(8000,92,4,1.5,.GuitarTuning~standard,'BOTH','AUTO')
render=.GuitarTabRenderer~render(events,config,gaugeFile)
pressure=render['PRESSURE']
.Pcm16WavWriter~writeMono(outFile,pressure~samples,pressure~sampleRateHz)
sym=render['SYMPATHETIC_PICKUP']; peakSym=0
do v over sym; if abs(v)>peakSym then peakSym=abs(v); end
say 'TAB EVENTS:' events~items
say 'PRESSURE SAMPLES:' pressure~sampleCount
say 'RMS PRESSURE PA:' pressure~rmsPressure
say 'PEAK PRESSURE PA:' pressure~peakAbsPressure
say 'PEAK SYMPATHETIC PICKUP V:' peakSym
say 'FINAL MECHANICAL ENERGY J:' render['INSTRUMENT']~totalMechanicalEnergy
say 'WAV:' outFile
say 'GAUGES:' gaugeFile
::requires 'AsciiTab.cls'
::requires 'GuitarPhysics.cls'
::requires 'WavWriter.cls'
