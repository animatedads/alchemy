/* MasRpcServiceBinding.cls
 * PRE24 publication helper for protocol-neutral RPC Service Core.
 *
 * MAS publishes an explicit allowlist of service operations.  Invocation
 * adaptation belongs to current ConnectSelector's ConnectRpcDispatchAdapter;
 * this package does not duplicate that adapter, choose a protocol, or expose
 * target methods by reflection.
 */

::class MasRpcServicePublisher public
::method init public
  expose registry
  use strict arg registryArg
  if registryArg==.nil | \registryArg~hasMethod('registerObject') then -
    raise syntax 88.900 array('MAS_RPC_REGISTRY_REQUIRED')
  registry=registryArg

::method publishObject public
  expose registry
  use strict arg service, target, mapping
  registry~registerObject(service,target,mapping)
  return self

::method publishCallback public
  expose registry
  use strict arg service, operation, target, methodName
  registry~registerCallbackMethod(service,operation,target,methodName)
  return self

::method freeze public
  expose registry
  registry~freeze
  return self

::requires 'RpcServiceCore.cls'
