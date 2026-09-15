say 'AUDIO ML TENSOR BINDING START'
np=.ForeignPython~import('numpy')
buf=.foreign~buffer(64)
arr=np~frombuffer(buf,.ForeignPython~text('<f4'))
ignored=arr~fill(0.25)
if ignored~isa(.ForeignPythonObject) then ignored~close

spec=.AudioMLMaterialSpec~new('MAT-TENSOR-1','REC-1','PCM-1',0,1,16000,1,'f32','MONO','LITTLE',.Array~of('decode','canonicalize'))
material=.AudioMLMaterialBinding~new(spec,'ForeignBuffer',buf,0,64,.true)
tensor=arr~asTensor
tb=.AudioMLTensorBinding~fromForeignTensor(material,tensor,.true)

call eq 'dlpack',tb~descriptor~protocol,'tensor protocol'
call eq 'float32',tb~descriptor~dtype,'tensor dtype'
call eq 1,tb~descriptor~rank,'tensor rank'
call eq 16,tb~descriptor~shape[1],'tensor shape'
call eq 4,tb~descriptor~strides[1],'tensor byte stride'
call eq 'cpu',tb~descriptor~device,'tensor device'
call eq 1,tb~descriptor~deviceType,'tensor DLPack CPU device type'
call truth tb~nativeDescriptorCapable,'provider-neutral native descriptor available'
call truth tb~nativeHandle>0,'native tensor handle'
call truth pos('nativeHandle=',tb~canonicalText)=0,'process-local handle not persisted in canonical text'

frhome=value('FOREIGN_RUNTIME_HOME',,'ENVIRONMENT')
if frhome='' then raise syntax 88.900 array('FOREIGN_RUNTIME_HOME required for tensor native descriptor test')
probe=.foreign~load(frhome || '/tests/tensor-native.bridge.json')
call eq 1,probe~rank(tb~nativeHandle),'native consumer tensor rank'
call eq 16,probe~dim(tb~nativeHandle,0),'native consumer tensor dimension'
call eq 4,probe~stride(tb~nativeHandle,0),'native consumer byte stride'
call eq 32,probe~dtype_bits(tb~nativeHandle),'native consumer dtype width'
call eq 1,probe~device_type(tb~nativeHandle),'native consumer CPU device'

/* DLPack handoff remains provider-internal; mutate through Torch and observe
 * the same ForeignBuffer/NumPy storage.  No claim is made about later model
 * internal copies. */
if .ForeignPython~canImport('torch') then do
  torch=tensor~toDLPack('torch')
  ignored=torch~fill_(0.5)
  if ignored~isa(.ForeignPythonObject) then ignored~close
  vals=arr~tolist
  call eq 0.5,vals[1],'Torch DLPack mutation first sample'
  call eq 0.5,vals[16],'Torch DLPack mutation last sample'
  tt=torch~asTensor
  call eq 16,probe~dim(tt~nativeHandle,0),'native consumer sees Torch tensor'
  call eq 32,probe~dtype_bits(tt~nativeHandle),'Torch tensor dtype width'
  tt~close
  torch~close
end
else say 'AUDIO ML TENSOR TORCH: SKIPPED (torch not importable)'

probe~close
arr~close
/* tb owns tensor and closes it.  material owns neither buf nor tensor. */
tb~close
np~close
buf~close
say 'AUDIO ML TENSOR BINDING: OK'
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
