/* RpcServiceCore: protocol-neutral, explicitly published object/method registry.
 * This package owns service dispatch, NOT transports, SOAP/XML, JSON or protobuf.
 * The wire caller NEVER chooses an ooRexx receiver method directly.
 */

::class RpcServiceFault public
::attribute code get
::attribute message get
::method init
  expose code message
  use strict arg code, message

::class RpcServiceResult public
::attribute ok get
::attribute value get
::attribute fault get
::method init
  expose ok value fault
  use strict arg ok, value, fault = .nil

/* An immutable, individually allowlisted binding to a server-side object.
 * LEGACY: invoke(operation, arguments, context)
 * UNARY:  publicMethod(arguments, context)
 * CALLBACK: publicMethod(arguments, context, sink)
 * Callback methods are NOT automatically a gRPC stream; gRPC binding owns that.
 */
::class RpcServiceEntry public
::attribute service get
::attribute operation get
::attribute mode get
::attribute methodName get
::method init
  expose service operation target methodName mode
  use strict arg service, operation, target, methodName, mode
::method invoke
  expose target methodName mode operation
  use strict arg requestedOperation, arguments, context
  if requestedOperation \== operation then return .RpcServiceFault~new('NOT_FOUND','Operation not found')
  if mode == 'CALLBACK' then return .RpcServiceFault~new('INVALID_INVOCATION','Callback operation requires a callback sink')
  if mode == 'LEGACY' then params = .array~of(operation, arguments, context)
  else params = .array~of(arguments, context)
  message = .message~new(target,methodName,'a',params)
  return message~send
::method invokeCallback
  expose target methodName mode operation
  use strict arg requestedOperation, arguments, context, sink
  if requestedOperation \== operation then return .RpcServiceFault~new('NOT_FOUND','Operation not found')
  if mode \== 'CALLBACK' then return .RpcServiceFault~new('INVALID_INVOCATION','Operation does not support callbacks')
  params = .array~of(arguments,context,sink)
  message = .message~new(target,methodName,'a',params)
  return message~send

/* Exact service and operation names; no reflection or implied method exposure.
 * Table (not Directory) is used for exact string identity, including case.
 */
::class RpcServiceRegistry public
::method init
  expose bindings frozen
  bindings = .Table~new
  frozen = .false
::method checkName private
  use strict arg name
  if \name~isA(.String) then raise syntax 93.900 additional('RPC name must be a string')
  if name == '' then raise syntax 93.900 additional('RPC name must not be empty')
  if name~pos(d2c(0)) > 0 then raise syntax 93.900 additional('RPC name contains NUL')
  return .true
::method scopedTable private
  expose bindings
  use strict arg service, create = .false
  row = bindings[service]
  if row == .nil then if create then do
    row = .Table~new
    bindings[service] = row
  end
  return row
::method addBinding private
  expose frozen
  use strict arg service, operation, target, methodName, mode
  ignored = self~checkName(service)
  ignored = self~checkName(operation)
  ignored = self~checkName(methodName)
  if frozen then raise syntax 93.900 additional('RPC registry frozen')
  if target == .nil then raise syntax 93.900 additional('RPC target missing')
  if \target~hasMethod(methodName) then raise syntax 93.900 additional('RPC target method unavailable')
  row = self~scopedTable(service,.true)
  if row~hasIndex(operation) then raise syntax 93.900 additional('RPC operation already registered')
  row[operation] = .RpcServiceEntry~new(service,operation,target,methodName,mode)
  return self
/* Backwards-compatible old handler registration. */
::method register
  use strict arg service, operation, handler
  return self~addBinding(service,operation,handler,'invoke','LEGACY')
/* Explicit public-name to server receiver-method mapping, unary call. */
::method registerMethod
  use strict arg service, operation, target, methodName
  return self~addBinding(service,operation,target,methodName,'UNARY')
/* Only this form can accept a callback sink, in-process on the server side. */
::method registerCallbackMethod
  use strict arg service, operation, target, methodName
  return self~addBinding(service,operation,target,methodName,'CALLBACK')
/* Bulk registration of explicitly chosen methods, atomic on validation.
 * Public operation names map to target method names in a Directory or Table.
 */
::method registerObject
  expose frozen
  use strict arg service, target, mapping
  ignored = self~checkName(service)
  if frozen then raise syntax 93.900 additional('RPC registry frozen')
  if target == .nil then raise syntax 93.900 additional('RPC target missing')
  if \(mapping~isA(.Directory) | mapping~isA(.Table)) then raise syntax 93.900 additional('RPC mapping must be Directory or Table')
  old = self~scopedTable(service)
  keys = mapping~allIndexes
  do operation over keys
    methodName = mapping[operation]
    ignored = self~checkName(operation)
    ignored = self~checkName(methodName)
    if \target~hasMethod(methodName) then raise syntax 93.900 additional('RPC target method unavailable')
    if old \== .nil then do
      if old~hasIndex(operation) then raise syntax 93.900 additional('RPC operation already registered')
    end
  end
  /* All checks complete before anything becomes visible. */
  row = self~scopedTable(service,.true)
  do operation over keys
    row[operation] = .RpcServiceEntry~new(service,operation,target,mapping[operation],'UNARY')
  end
  return self
::method resolve
  use strict arg service, operation
  if \service~isA(.String) | \operation~isA(.String) then return .nil
  row = self~scopedTable(service)
  if row == .nil then return .nil
  return row[operation]
::method unregister
  expose frozen
  use strict arg service, operation
  if frozen then raise syntax 93.900 additional('RPC registry frozen')
  row = self~scopedTable(service)
  if row == .nil then return .false
  if \row~hasIndex(operation) then return .false
  row~remove(operation)
  return .true
::method freeze
  expose frozen
  frozen = .true
  return self
::attribute frozen get

::class RpcServiceDispatcher public
::method init
  expose registry
  use strict arg registry
  if \registry~hasMethod('resolve') then raise syntax 93.900 additional('RPC registry must resolve service and operation')
::method invoke
  expose registry
  use strict arg service, operation, arguments = .nil, context = .nil
  entry = registry~resolve(service,operation)
  if entry == .nil then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('NOT_FOUND','Operation not found'))
  signal on syntax name failed
  response = entry~invoke(operation,arguments,context)
  signal off syntax
  if response~isA(.RpcServiceFault) then return .RpcServiceResult~new(.false,.nil,response)
  return .RpcServiceResult~new(.true,response)
failed:
  signal off syntax
  /* Opt-in local diagnostics only; never leak implementation detail to RPC. */
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then
    say 'RPC dispatch failure' rc sigl condition("C") condition("D")
  return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('INTERNAL','Internal service error'))
::method invokeCallback
  expose registry
  use strict arg service, operation, arguments, context, sink
  entry = registry~resolve(service,operation)
  if entry == .nil then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('NOT_FOUND','Operation not found'))
  if sink == .nil then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('INVALID_ARGUMENT','Callback sink required'))
  do selector over .array~of('onNext','onComplete','onFault','isCancelled')
    if \sink~hasMethod(selector) then return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('INVALID_ARGUMENT','Callback sink contract not met'))
  end
  signal on syntax name failedCallback
  response = entry~invokeCallback(operation,arguments,context,sink)
  signal off syntax
  if response~isA(.RpcServiceFault) then return .RpcServiceResult~new(.false,.nil,response)
  return .RpcServiceResult~new(.true,response)
failedCallback:
  signal off syntax
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then
    say 'RPC callback dispatch failure' rc sigl condition("C") condition("D")
  return .RpcServiceResult~new(.false,.nil,.RpcServiceFault~new('INTERNAL','Internal service error'))
