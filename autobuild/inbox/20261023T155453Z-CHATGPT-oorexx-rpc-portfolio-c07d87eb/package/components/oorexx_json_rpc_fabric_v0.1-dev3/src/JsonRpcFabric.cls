/* JSON-RPC Fabric 0.1-dev3. Protocol only; ConnectSelector owns routing. */

/** RFC JSON-RPC 2.0 codec over the runtime-provided json.cls.
 * The caller owns transport framing and must impose its own framing limit.
 */
::class JsonRpcCodec public
::method init
  expose limit
  use strict arg maximum = 1048576
  if \datatype(maximum, 'W') | maximum < 1 then raise syntax 93.900 additional('positive frame limit required')
  limit = maximum
::method limit
  expose limit
  return limit
::method decode
  expose limit
  use strict arg bytes
  if bytes~length > limit then raise syntax 93.900 additional('RPC frame too large')
  return .JSON~fromJSON(bytes)
::method encode
  expose limit
  use strict arg obj
  bytes = .JSON~toJSON(obj)
  if bytes~length > limit then raise syntax 93.900 additional('RPC response too large')
  return bytes

/** Explicit published method registry. Never dispatch untrusted names with ~send. */
::class JsonRpcMethodRegistry public
::method init
  expose entries
  entries = .Directory~new
::method register
  expose entries
  use strict arg name, handler
  if \name~isA(.String) then raise syntax 93.900 additional('method name must be a string')
  if name == '' | name~left(4) == 'rpc.' then raise syntax 93.900 additional('reserved/empty method')
  if \handler~hasMethod('invoke') then raise syntax 93.900 additional('handler must implement invoke')
  entries[name] = handler
  return self
::method resolve
  expose entries
  use strict arg name
  return entries[name]

/** Typed, deliberate application error. Return this from a registered handler. */
::class JsonRpcFault public
::attribute code get
::attribute message get
::attribute data get
::method init
  expose code message data
  use strict arg code, message, data = .nil
  if \datatype(code,'W') then raise syntax 93.900 additional('fault code must be integer')

/** Protocol dispatcher: validates JSON-RPC 2.0, notifications and batches.
 * The handler boundary is invoke(method, params, context). Methods are allowlisted.
 * No ordinary exception detail is returned across the wire.
 */
::class JsonRpcDispatcher public
::method init
  expose registry codec
  use strict arg registry, codec = .nil
  if codec == .nil then codec = .JsonRpcCodec~new
::method codec
  expose codec
  return codec
::method handleText
  expose codec
  use strict arg bytes, context = .nil
  signal on syntax name malformed
  document = codec~decode(bytes)
  signal off syntax
  response = self~handleDocument(document, context)
  if response == .nil then return .nil
  signal on syntax name encodeFailure
  textResponse = codec~encode(response)
  signal off syntax
  return textResponse
malformed:
  signal off syntax
  return self~safeEncode(self~errorResponse(-32700, 'Parse error', .nil))
encodeFailure:
  signal off syntax
  return self~safeEncode(self~errorResponse(-32603, 'Internal error', .nil))
::method safeEncode private
  expose codec
  use strict arg response
  signal on syntax name cannotEncode
  return codec~encode(response)
cannotEncode:
  return '{"jsonrpc":"2.0","error":{"code":-32603,"message":"Internal error"},"id":null}'
::method handleDocument
  use strict arg doc, context = .nil
  if doc~isA(.Array) then do
    if doc~items == 0 then return self~errorResponse(-32600,'Invalid Request',.nil)
    responses = .Array~new
    do item over doc
      ans = self~handleOne(item, context)
      if ans \== .nil then responses~append(ans)
    end
    if responses~items == 0 then return .nil
    return responses
  end
  return self~handleOne(doc, context)
::method handleOne private
  expose registry
  use strict arg entry, context
  if \entry~isA(.Directory) then return self~errorResponse(-32600,'Invalid Request',.nil)
  id = .nil
  hasId = entry~hasIndex('id')
  if hasId then do
    candidate = entry['id']
    if candidate == .nil | candidate~isA(.JsonString) then id = candidate
    else if candidate~isA(.String) & \candidate~isA(.JsonBoolean) then do
      if datatype(candidate,'N') then id = candidate
    end
  end
  if \entry~hasIndex('jsonrpc') | \entry~hasIndex('method') then return self~errorResponse(-32600,'Invalid Request',.nil)
  version = entry['jsonrpc']
  methodName = entry['method']
  if \version~isA(.JsonString) then return self~errorResponse(-32600,'Invalid Request',.nil)
  if version \== '2.0' then return self~errorResponse(-32600,'Invalid Request',.nil)
  if \methodName~isA(.JsonString) then return self~errorResponse(-32600,'Invalid Request',.nil)
  if methodName == '' then return self~errorResponse(-32600,'Invalid Request',.nil)
  if hasId then do
    if id == .nil & entry['id'] \== .nil then return self~errorResponse(-32600,'Invalid Request',.nil)
  end
  params = .nil
  if entry~hasIndex('params') then do
    params = entry['params']
    if \params~isA(.Directory) & \params~isA(.Array) then return self~errorResponse(-32600,'Invalid Request',.nil)
  end
  handler = .nil
  if methodName~left(4) \== 'rpc.' then handler = registry~resolve(methodName)
  if handler == .nil then do
    if \hasId then return .nil
    return self~errorResponse(-32601,'Method not found',id)
  end
  signal on syntax name handlerFailure
  value = handler~invoke(methodName, params, context)
  signal off syntax
  if \hasId then return .nil
  if value~isA(.JsonRpcFault) then return self~errorResponse(value~code,value~message,id,value~data)
  response = self~baseResponse(id)
  response['result'] = value
  return response
handlerFailure:
  signal off syntax
  if \hasId then return .nil
  return self~errorResponse(-32603,'Internal error',id)
::method baseResponse private
  use strict arg id
  response = .Directory~new
  response['jsonrpc'] = .JsonString~new('2.0')
  response['id'] = id
  return response
::method errorResponse
  use strict arg code, message, id, data = .nil
  response = self~baseResponse(id)
  err = .Directory~new
  err['code'] = code
  err['message'] = .JsonString~new(message)
  if data \== .nil then err['data'] = data
  response['error'] = err
  return response

/** Per-client result object; exceptions are not the remote error channel. */
::class JsonRpcCallResult public
::attribute ok get
::attribute result get
::attribute fault get
::attribute id get
::method init
  expose ok result fault id
  use strict arg ok, result, fault, id

/** Transport contract: exchange(jsonText) -> jsonText or .nil.
 * Implementations supply HTTP, WebSocket, Unix socket, TCP/TLS, or stdio.
 * send(jsonText) emits one notification WITHOUT waiting for a response.
 * This class never retries calls: retries require explicit idempotency policy.
 */
::class JsonRpcClient public
::method init
  expose transport codec counter
  use strict arg transport, codec = .nil
  if codec == .nil then codec = .JsonRpcCodec~new
  counter = 0
::method request
  expose transport codec counter
  use strict arg methodName, params = .nil
  counter += 1
  id = .JsonString~new('r' || counter)
  envelope = self~makeRequest(methodName, params, id, .true)
  signal on syntax name transportError
  replyText = transport~exchange(codec~encode(envelope))
  if replyText == .nil then return .JsonRpcCallResult~new(.false,.nil,.JsonRpcFault~new(-32000,'No response'),id)
  reply = codec~decode(replyText)
  if \reply~isA(.Directory) then return self~badResponse(id)
  if \reply~hasIndex('jsonrpc') | \reply~hasIndex('id') then return self~badResponse(id)
  if \reply['jsonrpc']~isA(.JsonString) then return self~badResponse(id)
  if reply['jsonrpc'] \== '2.0' then return self~badResponse(id)
  if \reply['id']~isA(.JsonString) then return self~badResponse(id)
  if reply['id'] \== id then return self~badResponse(id)
  if reply~hasIndex('result') = reply~hasIndex('error') then return self~badResponse(id)
  if reply~hasIndex('error') then do
    err=reply['error']
    if \err~isA(.Directory) then return self~badResponse(id)
    if \err~hasIndex('code') | \err~hasIndex('message') then return self~badResponse(id)
    if err['code']~isA(.JsonString) then return self~badResponse(id)
    if \datatype(err['code'],'W') then return self~badResponse(id)
    if \err['message']~isA(.JsonString) then return self~badResponse(id)
    data=.nil
    if err~hasIndex('data') then data=err['data']
    return .JsonRpcCallResult~new(.false,.nil,.JsonRpcFault~new(err['code'],err['message'],data),id)
  end
  return .JsonRpcCallResult~new(.true,reply['result'],.nil,id)
transportError:
  signal off syntax
  return .JsonRpcCallResult~new(.false,.nil,.JsonRpcFault~new(-32000,'Transport or codec failure'),id)
::method notify
  expose transport codec
  use strict arg methodName, params = .nil
  /* A failed or ambiguous notification send is not a confirmed delivery.
   * Report failure without causing ConnectCallAdapter to throw; do not retry.
   */
  signal on syntax name notificationFailure
  envelope = self~makeRequest(methodName, params, .nil, .false)
  sent = transport~send(codec~encode(envelope))
  signal off syntax
  if sent == .false | sent == .nil then return .false
  return .true
notificationFailure:
  signal off syntax
  return .false
::method badResponse private
  use strict arg id
  return .JsonRpcCallResult~new(.false,.nil,.JsonRpcFault~new(-32000,'Invalid remote response'),id)
::method makeRequest private
  use strict arg methodName, params, id, withId
  if \methodName~isA(.String) then raise syntax 93.900 additional('method name must be a string')
  if methodName == '' then raise syntax 93.900 additional('method name required')
  obj = .Directory~new
  obj['jsonrpc']=.JsonString~new('2.0')
  obj['method']=.JsonString~new(methodName)
  if params \== .nil then do
    if \params~isA(.Array) & \params~isA(.Directory) then raise syntax 93.900 additional('params must be array/object')
    obj['params']=params
  end
  if withId then obj['id']=id
  return obj

/** Explicit in-process transport: uses the same JSON-RPC wire contract. */
::class JsonRpcLoopbackTransport public
::method init
  expose dispatcher context
  use strict arg dispatcher, context = .nil
::method exchange
  expose dispatcher context
  use strict arg text
  return dispatcher~handleText(text,context)
::method send
  expose dispatcher context
  use strict arg text
  reply = dispatcher~handleText(text,context)
  if reply \== .nil then raise syntax 93.900 additional('unexpected response to notification')
  return .true

/** Local handler compatibility adapter with *no JSON serialization*.
 * Connect Selector owns the decision to use DIRECT; applications may
 * inject this handler adapter into ConnectCallAdapter. It is not a selector.
 */
/** Local connector with *no JSON serialization*. It uses the identical
 * published handler contract and result type as the JSON-RPC connector.
 * Transport-level guarantees do not apply to local calls.
 */
::class JsonRpcDirectConnector public
::method init
  expose registry context
  use strict arg registry, context = .nil
::method request
  expose registry context
  use strict arg methodName, params = .nil
  handler=registry~resolve(methodName)
  if handler == .nil then return .JsonRpcCallResult~new(.false,.nil,.JsonRpcFault~new(-32601,'Method not found'),.nil)
  signal on syntax name localFailure
  value=handler~invoke(methodName,params,context)
  signal off syntax
  if value~isA(.JsonRpcFault) then return .JsonRpcCallResult~new(.false,.nil,value,.nil)
  return .JsonRpcCallResult~new(.true,value,.nil,.nil)
localFailure:
  signal off syntax
  return .JsonRpcCallResult~new(.false,.nil,.JsonRpcFault~new(-32603,'Internal error'),.nil)
::method notify
  expose registry context
  use strict arg methodName, params = .nil
  handler=registry~resolve(methodName)
  if handler == .nil then return .false
  signal on syntax name localFailure
  answer=handler~invoke(methodName,params,context)
  signal off syntax
  if answer~isA(.JsonRpcFault) then return .false
  return .true
localFailure:
  signal off syntax
  return .false

/* Communication selection belongs to ConnectSelector (oorexx.connect_selector/0.1).
 * Legacy named RPC connector routing is available only by an explicit
 * ::requires 'JsonRpcLegacyConnectorRegistry.cls' opt-in. Do not create
 * another selection layer here.
 */

::requires 'json.cls'
