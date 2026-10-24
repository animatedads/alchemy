/* Native libnorm binding adapter.  Loading this file is the explicit point at
 * which the ooRexx process acquires the native NORM package dependency. */
::class NormNativeApi public
::method version
  return normNativeVersion()
::method senderOpen
  use strict arg group,port,nodeId,interface,source,ttl,loopback,txRate,bufferBytes,fecSpec
  return normNativeSenderOpen(group,port,nodeId,interface,source,ttl,loopback,txRate,bufferBytes,fecSpec)
::method senderSend
  use strict arg handle,bytes
  return normNativeSenderSend(handle,bytes)
::method senderDescriptor
  use strict arg handle
  return normNativeSenderDescriptor(handle)
::method senderSetLoss
  use strict arg handle,percent
  return normNativeSenderSetLoss(handle,percent)
::method senderWaitDrained
  use strict arg handle,timeoutMilliseconds
  return normNativeSenderWaitDrained(handle,timeoutMilliseconds)
::method senderClose
  use strict arg handle
  return normNativeSenderClose(handle)
::method listenerOpen
  use strict arg group,port,nodeId,interface,source,loopback,rxBuffer
  return normNativeListenerOpen(group,port,nodeId,interface,source,loopback,rxBuffer)
::method listenerReceive
  use strict arg handle
  return normNativeListenerReceive(handle)
::method listenerTryReceive
  use strict arg handle
  return normNativeListenerTryReceive(handle)
::method listenerWait
  use strict arg handle,timeoutMilliseconds
  return normNativeListenerWait(handle,timeoutMilliseconds)
::method listenerDescriptor
  use strict arg handle
  return normNativeListenerDescriptor(handle)
::method listenerClose
  use strict arg handle
  return normNativeListenerClose(handle)

::routine normNativeVersion external "library oorexx_norm_native normNativeVersion"
::routine normNativeSenderOpen external "library oorexx_norm_native normNativeSenderOpen"
::routine normNativeSenderSend external "library oorexx_norm_native normNativeSenderSend"
::routine normNativeSenderDescriptor external "library oorexx_norm_native normNativeSenderDescriptor"
::routine normNativeSenderSetLoss external "library oorexx_norm_native normNativeSenderSetLoss"
::routine normNativeSenderWaitDrained external "library oorexx_norm_native normNativeSenderWaitDrained"
::routine normNativeSenderClose external "library oorexx_norm_native normNativeSenderClose"
::routine normNativeListenerOpen external "library oorexx_norm_native normNativeListenerOpen"
::routine normNativeListenerReceive external "library oorexx_norm_native normNativeListenerReceive"
::routine normNativeListenerTryReceive external "library oorexx_norm_native normNativeListenerTryReceive"
::routine normNativeListenerWait external "library oorexx_norm_native normNativeListenerWait"
::routine normNativeListenerDescriptor external "library oorexx_norm_native normNativeListenerDescriptor"
::routine normNativeListenerClose external "library oorexx_norm_native normNativeListenerClose"

::requires "NormSocketProvider.cls"
