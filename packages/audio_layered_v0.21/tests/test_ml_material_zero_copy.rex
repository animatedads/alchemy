say 'AUDIO ML MATERIAL ZERO COPY START'
py=.ForeignPython~import('numpy')
buf=.foreign~buffer(64)
arr=py~frombuffer(buf,.ForeignPython~text('<f4'))
ignored=arr~fill(0.25)
if ignored~isa(.ForeignPythonObject) then ignored~close
spec=.AudioMLMaterialSpec~new('MAT-1','REC-1','PCM-1',0,1,16000,1,'f32','MONO','LITTLE',.Array~of('decode','canonicalize'))
binding=.AudioMLMaterialBinding~new(spec,'ForeignBuffer',buf,0,64,.true)
call eq 64,binding~byteLength,'binding byte length'
call truth binding~zeroCopyCapable,'zero-copy capability marked'
call eq 'numpy.ndarray',arr~typeName,'NumPy frombuffer returns resident ndarray'
call truth arr~tobytes==buf~bytes,'NumPy and ForeignBuffer expose same bytes'
ignored=arr~fill(0.5)
if ignored~isa(.ForeignPythonObject) then ignored~close
call truth arr~tobytes==buf~bytes,'mutation remains visible through same storage'
call eq 16000,spec~sampleRateHz,'canonical ML rate'
call eq 'f32',spec~sampleFormat,'canonical ML format'
arr~close; py~close; buf~close
say 'AUDIO ML MATERIAL ZERO COPY: OK'
exit 0

eq: procedure
 use strict arg expected,actual,label
 if expected \= actual then raise syntax 88.900 array('FAILED '||label||' expected='||expected||' actual='||actual)
 return
truth: procedure
 use strict arg actual,label
 if \actual then raise syntax 88.900 array('FAILED '||label)
 return

::requires '../AudioMLMaterial.cls'
::requires 'python_foreign.cls'
