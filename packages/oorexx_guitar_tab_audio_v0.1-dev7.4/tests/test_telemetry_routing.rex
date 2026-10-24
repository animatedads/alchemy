gauge='test_telemetry_routing.csv'
lines=.array~of('e|--------|','B|--------|','G|--4-----|','D|----2---|','A|--------|','E|--------|')
events=.AsciiTabParser~parse(lines)
config=.GuitarRenderConfig~new(8000,120,4,1.5,.GuitarTuning~standard,'BOTH')
r=.GuitarTabRenderer~render(events,config,gauge)
f=.stream~new(gauge); f~open('read')
header=f~linein
s3=0;s4=0
Do while f~lines>0
  row=f~linein
  if row='' then iterate
  vals=row~makearray(',')
  if abs(vals[10])>s3 then s3=abs(vals[10])
  if abs(vals[11])>s4 then s4=abs(vals[11])
end
f~close
call sysfiledelete gauge
if s3<=0 then do; say 'FAIL no direct_s3_v for fretted G string'; exit 1; end
if s4<=0 then do; say 'FAIL no direct_s4_v for fretted D string'; exit 1; end
say 'TELEMETRY ROUTING: OK direct_s3_peak='s3 'direct_s4_peak='s4
exit 0
::requires 'AsciiTab.cls'
::requires 'GuitarPhysics.cls'
