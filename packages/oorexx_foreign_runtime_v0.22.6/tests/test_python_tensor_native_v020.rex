failures=0
np=.ForeignPython~import('numpy')
kw=.ForeignPython~keywords; kw~put('dtype','uint8')
arr=np~arange(8,kw)
t=arr~asTensor
probe=.foreign~load('tensor-native.bridge.json')
call check t~nativeHandle>0,'tensor has provider-neutral native handle'
call check probe~rank(t~nativeHandle)=1,'native descriptor rank'
call check probe~dim(t~nativeHandle,0)=8,'native descriptor shape'
call check probe~stride(t~nativeHandle,0)=1,'native descriptor byte stride'
call check probe~dtype_bits(t~nativeHandle)=8,'native descriptor dtype bits'
call check probe~device_type(t~nativeHandle)=1,'native descriptor CPU device'
call check probe~sum_u8(t~nativeHandle)=28,'native provider reads NumPy tensor storage'
call check probe~fill_u8(t~nativeHandle,7)=0,'native provider mutates tensor storage'
vals=arr~tolist
call check vals[1]=7 & vals[8]=7,'NumPy sees native tensor mutation'
arr~close
call check probe~sum_u8(t~nativeHandle)=56,'tensor descriptor retains Python storage after source proxy close'
-- A second provider path when the embedded provider can import Torch.
if .ForeignPython~canImport('torch') then do
  torchObj=t~toDLPack('torch')
  tt=torchObj~asTensor
  call check tt~nativeHandle>0,'Torch tensor has provider-neutral native handle'
  call check probe~rank(tt~nativeHandle)=1,'native descriptor reads Torch rank'
  call check probe~device_type(tt~nativeHandle)=1,'native descriptor reads Torch CPU device'
  call check probe~fill_u8(tt~nativeHandle,3)=0,'native provider mutates Torch tensor storage'
  call check probe~sum_u8(tt~nativeHandle)=24,'native provider reads mutated Torch tensor storage'
  tt~close; torchObj~close
end
else say 'OPTIONAL Torch native tensor descriptor SKIP reason=not-importable-by-embedded-python'
t~close; torchObj~close
t~close
probe~close
np~close
if failures=0 then do; say 'PASS native tensor descriptor core assertions; optional Torch when available'; exit 0; end
say 'FAIL native tensor descriptor failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
::requires '../rexx/python_foreign.cls'
