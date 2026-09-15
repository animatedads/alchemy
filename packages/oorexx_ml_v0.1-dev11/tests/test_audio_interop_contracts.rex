model=.AudioLikeModel~new
m=.MLModelDefinition~fromObject(model)
call eq 'speaker-demo',m~id,'model id'
call eq 'embedding',m~task,'model task'
tensor=.AudioLikeTensor~new
t=.MLTensorContract~fromObject(tensor)
call eq 'float32',t~dtype,'tensor dtype'
call eq 'cpu',t~device,'tensor device'
say 'PASS test_audio_interop_contracts'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return

::class AudioLikeModel public
::attribute id
::attribute task
::attribute provider
::attribute family
::attribute source
::attribute revision
::attribute runtime
::attribute inputSchema
::attribute outputSchema
::attribute attributes
::method init
 self~id='speaker-demo'; self~task='embedding'; self~provider='foreign-python'; self~family='speech'; self~source='demo'; self~revision='1'; self~runtime='torch'; self~inputSchema=.nil; self~outputSchema=.nil; self~attributes=.nil

::class AudioLikeTensor public
::attribute protocol
::attribute dtype
::attribute shape
::attribute strides
::attribute deviceType
::attribute deviceId
::attribute device
::attribute readonly
::attribute attributes
::method init
 self~protocol='dlpack'; self~dtype='float32'; self~shape='1x16'; self~strides=.nil; self~deviceType='CPU'; self~deviceId='0'; self~device='cpu'; self~readonly=.true; self~attributes=.nil

::requires "OorexxML.cls"
