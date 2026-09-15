failures=0
np=.ForeignPython~import('numpy')
kw=.ForeignPython~keywords
kw~put('dtype','uint8')
arr=np~arange(8,kw)

-- Keep an independent buffer export so we can verify storage after closing arr.
buf=arr~asBuffer
t=arr~asTensor
call check t~protocol='dlpack','tensor protocol is dlpack'
call check t~dtype='uint8','NumPy tensor dtype'
call check t~shape~items=1 & t~shape[1]=8,'NumPy tensor shape'
call check t~strides~items=1 & t~strides[1]=1,'NumPy tensor byte strides'
call check t~device='cpu','NumPy tensor device'
call check t~deviceType=1,'DLPack CPU device type'
call check t~deviceId=0,'DLPack CPU device id'
call check t~readonly=0,'NumPy writable state known'

-- Tensor view owns an independent Python reference.
arr~close
torch=t~toDLPack('torch')
call check torch~typeName<>'','DLPack target returned resident Torch object'
ignored=torch~fill_(9)
call check buf~hex='0909090909090909','Torch mutation visible in original NumPy storage after source proxy close'

-- Torch tensor introspection is normalized to byte strides.
t2=torch~asTensor
call check t2~device='cpu','Torch tensor DLPack device'
call check t2~deviceType=1,'Torch tensor device type'
call check t2~shape[1]=8,'Torch tensor shape'
call check t2~strides[1]=1,'Torch tensor byte strides'

-- Tensor view retains Torch independently; DLPack handoff remains valid after proxy close.
torch~close
np2=t2~toDLPack('numpy')
vals=np2~tolist
call check vals[1]=9 & vals[8]=9,'Torch to NumPy DLPack handoff preserves shared values'

np2~close
t2~close
t~close
buf~close
np~close
if failures=0 then do; say 'PASS Python DLPack tensor 15 assertions'; exit 0; end
say 'FAIL Python DLPack tensor failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
::requires '../rexx/python_foreign.cls'
