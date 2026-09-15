/* Optional convenience facade for the Vulkan provider. */
::class ForeignVulkan public
::method init
  expose _lib _vendor
  use strict arg schema='vulkan.bridge.json',vendor=32902
  _lib=.foreign~load(schema); _vendor=vendor
::method available unguarded; expose _lib _vendor; return _lib~available(_vendor)
::method deviceName unguarded; expose _lib; return _lib~device_name
::method fillU32 unguarded
  expose _lib _vendor
  use strict arg count,value
  id=_lib~fill_tensor(count,value,_vendor)
  if id=0 then raise syntax 93.900 array('Vulkan tensor allocation/queue submission failed')
  return .ForeignVulkanTensor~new(_lib,id,count)
::method close unguarded; expose _lib; _lib~close

::class ForeignVulkanTensor public
::method init; expose _lib _id _count _closed; use strict arg _lib,_id,_count; _closed=.false
::method nativeHandle unguarded; expose _id; return _id
::method count unguarded; expose _count; return _count
::method at unguarded; expose _lib _id; use strict arg index; return _lib~read_u32(_id,index-1)
::method close unguarded; expose _lib _id _closed; if \_closed then do; call _lib~tensor_close _id; _closed=.true; end
::method uninit; expose _lib _id _closed; if symbol('_closed')='VAR' then if \_closed then call _lib~tensor_close _id
::requires 'foreign.cls'
