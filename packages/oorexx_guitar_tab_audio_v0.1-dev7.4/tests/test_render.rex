lines=.array~of('e|--------|','B|--------|','G|--------|','D|--------|','A|--------|','E|0---3---|')
events=.AsciiTabParser~parse(lines)
config=.GuitarRenderConfig~new(8000,120,4,1.0,.GuitarTuning~standard)
r=.GuitarTabRenderer~render(events,config)
b=r~at('PRESSURE')
if b~sampleCount<>8000 then do; say 'FAIL sample count' b~sampleCount; exit 1; end
if b~rmsPressure<=0 then do; say 'FAIL zero pressure'; exit 1; end
say 'GUITAR PHYSICS RENDER: OK RMS_PA=' b~rmsPressure
exit 0
::requires 'AsciiTab.cls'
::requires 'GuitarPhysics.cls'
