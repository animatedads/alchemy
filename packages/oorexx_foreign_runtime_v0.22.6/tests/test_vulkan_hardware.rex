/* Real headless Vulkan hardware smoke. Strictly rejects CPU/llvmpipe devices. */
failures=0
vendor=32902 /* 0x8086 Intel */
lib=.foreign~load('../examples/vulkan.bridge.json')
if lib~available(vendor)=0 then do
  say 'OPTIONAL Vulkan-hardware SKIP reason=no-matching-non-CPU-Intel-device'
  lib~close
  exit 77
end
call check lib~vendor_id=vendor,'selected Intel hardware vendor'
call check lib~device_type<>4,'selected device is not Vulkan CPU device'
name=lib~device_name
call check name<>'','selected Vulkan device has a name'
id=lib~fill_tensor(8,2,vendor)
call check id>0,'Vulkan queue fill returned tensor descriptor v2 handle'
do i=0 to 7
  call check lib~read_u32(id,i)=2,'GPU queue fill visible at element' i
end
call check lib~tensor_close(id)=0,'Vulkan tensor closes through Foreign Runtime lifetime'
say 'Vulkan device:' name
if failures=0 then do; say 'PASS real Vulkan hardware queue/fence tensor 13 assertions'; lib~close; exit 0; end
say 'FAIL Vulkan assertions='failures; lib~close; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
::requires '../rexx/foreign.cls'
