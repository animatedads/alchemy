/* RPC HTTPS JSON-RPC ingress v0.1-dev1.
 * Integration-only classes: existing HttpsServer owns TLS and HTTP parsing,
 * existing JsonRpcDispatcher owns JSON-RPC envelopes, existing RpcServiceCore
 * owns registered object/method dispatch. No transport or codec fork.
 *
 * Caller must ::requires HttpsServer, RpcServiceCore, JsonRpcFabric before
 * loading this file, and must supply a trusted platform authentication authority.
 */

/* Attestation is issued by the trusted authority after authenticating against
 * platform LDAP and the actual accepted HTTPS session. Never created by the
 * incoming wire payload, an x-forwarded-* header, or client-declared roles.
 */
::class RpcHttpsIdentityAttestation public
::attribute identityId get
::attribute requestId get
::attribute peerAddress get
::attribute tlsGeneration get
::method init
  expose identityId requestId peerAddress tlsGeneration
  use strict arg identityId, request
  if identityId == '' then raise syntax 93.900 additional('empty authenticated identity')
  if request~context == .nil then raise syntax 93.900 additional('missing authenticated exchange')
  requestId = request~context~requestId
  peerAddress = request~peerAddress
  tlsGeneration = request~tlsGeneration

::class RpcHttpsCallContext public
::attribute principal get
::attribute exchange get
::attribute peerAddress get
::attribute tlsProtocol get
::method init
  expose principal exchange peerAddress tlsProtocol
  use strict arg principal, request
  exchange = request~context
  peerAddress = request~peerAddress
  tlsProtocol = request~tlsProtocol

/* This is the adapter to the existing JSON-RPC dispatcher registry contract.
 * Its entries refer ONLY to operations already registered in RpcServiceCore.
 */
::class RpcHttpsPublishedRegistry public
::method init
  expose routes serviceRegistry dispatcher authority frozen
  use strict arg serviceRegistry, dispatcher, authority
  if \serviceRegistry~hasMethod('resolve') then raise syntax 93.900 additional('RPC service registry required')
  if \dispatcher~hasMethod('invoke') then raise syntax 93.900 additional('RPC dispatcher required')
  if \authority~hasMethod('authorizeOperation') then raise syntax 93.900 additional('trusted authority must implement authorizeOperation')
  routes = .Table~new
  frozen = .false
::method registerOperation
  expose routes serviceRegistry dispatcher authority frozen
  use strict arg publicName, service, operation
  if frozen then raise syntax 93.900 additional('RPC HTTPS publication sealed')
  if \publicName~isA(.String) | \service~isA(.String) | \operation~isA(.String) then raise syntax 93.900 additional('RPC names must be strings')
  if publicName == '' | service == '' | operation == '' then raise syntax 93.900 additional('RPC names may not be empty')
  if publicName~left(4) == 'rpc.' then raise syntax 93.900 additional('reserved JSON-RPC method namespace')
  if publicName~pos(d2c(0)) > 0 then raise syntax 93.900 additional('NUL in published name')
  if routes~hasIndex(publicName) then raise syntax 93.900 additional('duplicate RPC HTTPS publication')
  entry = serviceRegistry~resolve(service,operation)
  if entry == .nil then raise syntax 93.900 additional('unregistered RPC service operation')
  if entry~mode == 'CALLBACK' then raise syntax 93.900 additional('HTTP JSON-RPC does not support callback operations')
  routes[publicName] = .RpcHttpsBoundOperation~new(publicName,service,operation,dispatcher,authority)
  return self
::method freeze
  expose frozen
  frozen = .true
  return self
::attribute frozen get
::method resolve
  expose routes
  use strict arg name
  if \name~isA(.String) then return .nil
  return routes[name]

::class RpcHttpsBoundOperation
::method init
  expose publicName service operation dispatcher authority
  use strict arg publicName, service, operation, dispatcher, authority
::method invoke
  expose publicName service operation dispatcher authority
  use strict arg requestedName, arguments, context
  if requestedName \== publicName then return .JsonRpcFault~new(-32601,'Method not found')
  if context == .nil then return .JsonRpcFault~new(-32001,'Permission denied')
  if \context~isA(.RpcHttpsCallContext) then return .JsonRpcFault~new(-32001,'Permission denied')
  signal on syntax name denied
  approved = authority~authorizeOperation(context~principal,service,operation,context~exchange)
  if approved \== .true then return .JsonRpcFault~new(-32001,'Permission denied')
  signal off syntax
  callResult = dispatcher~invoke(service,operation,arguments,context)
  if callResult~ok then return callResult~value
  faultCode = callResult~fault~code
  select
    when faultCode == 'NOT_FOUND' then return .JsonRpcFault~new(-32601,'Method not found')
    when faultCode == 'INVALID_ARGUMENT' then return .JsonRpcFault~new(-32602,'Invalid params')
    otherwise return .JsonRpcFault~new(-32603,'Internal error')
  end
 denied:
  signal off syntax
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then
    say 'RPC HTTPS authorize failure' rc sigl condition('C') condition('D')
  return .JsonRpcFault~new(-32001,'Permission denied')

/* Route this method using:
 * server~route('POST','/rpc',gateway,'handle')
 * gateway~registry~registerOperation('catalog.lookup','catalog','lookup')
 * gateway~registry~freeze
 *
 * Authority contract: authenticate(HttpRequest,HttpExchangeContext) returns
 * verified principal (or .nil on failure); authorizeOperation(principal,
 * service,operation,HttpExchangeContext) returns .true ONLY on approval.
 * A bearer string, role header, or claimed identity alone is NOT an attestation.
 */
::class RpcHttpsJsonGateway public
::method init
  expose authority registry protocol maximumBytes
  use strict arg serviceRegistry, dispatcher, authority, maximumBytes=262144
  if authority == .nil then raise syntax 93.900 additional('trusted authority required')
  if \authority~hasMethod('authenticate') then raise syntax 93.900 additional('trusted authority must implement authenticate')
  if \authority~hasMethod('authorizeOperation') then raise syntax 93.900 additional('trusted authority must implement authorizeOperation')
  if \datatype(maximumBytes,'W') | maximumBytes < 1 | maximumBytes > 1048576 then raise syntax 93.900 additional('invalid JSON-RPC HTTPS request limit')
  registry = .RpcHttpsPublishedRegistry~new(serviceRegistry,dispatcher,authority)
  protocol = .JsonRpcDispatcher~new(registry,.JsonRpcCodec~new(maximumBytes))
::attribute registry get
::method errorResponse
  use strict arg status, message
  response = .HttpResponse~text(message,status,'text/plain; charset=utf-8')
  response~header('Cache-Control','no-store')
  response~header('X-Content-Type-Options','nosniff')
  return response
::method handle
  expose authority registry protocol maximumBytes
  use strict arg request
  /* Reject application execution until all published routes are sealed. */
  if \registry~frozen then return self~errorResponse(503,'RPC service unavailable')
  if request~method \== 'POST' then return self~errorResponse(405,'Method not allowed')
  /* A real HttpsServer attaches the transport-originated exchange context. */
  if request~context == .nil then return self~errorResponse(403,'Secure request context required')
  select
    when request~tlsProtocol == 'TLSv1.2' then nop
    when request~tlsProtocol == 'TLSv1.3' then nop
    otherwise return self~errorResponse(403,'TLS required')
  end
  if request~body~length > maximumBytes then return self~errorResponse(413,'Request too large')
  contentType = request~header('content-type','')~lower~strip
  select
    when contentType == 'application/json' then nop
    when contentType == 'application/json; charset=utf-8' then nop
    when contentType == 'application/json-rpc' then nop
    otherwise return self~errorResponse(415,'Unsupported media type')
  end
  encoding = request~header('content-encoding','identity')~lower~strip
  select
    when encoding == 'identity' then nop
    when encoding == '' then nop
    otherwise return self~errorResponse(415,'Unsupported content encoding')
  end
  /* Identity is verified by an injected platform authority, not by headers. */
  signal on syntax name authenticationDenied
  principal = authority~authenticate(request,request~context)
  if principal == .nil then return self~errorResponse(401,'Authentication required')
  if \principal~isA(.RpcHttpsIdentityAttestation) then return self~errorResponse(401,'Authentication required')
  if principal~requestId \== request~context~requestId then return self~errorResponse(401,'Authentication required')
  if principal~peerAddress \== request~peerAddress then return self~errorResponse(401,'Authentication required')
  if principal~tlsGeneration \== request~tlsGeneration then return self~errorResponse(401,'Authentication required')
  signal off syntax
  invocationContext = .RpcHttpsCallContext~new(principal,request)
  wireReply = protocol~handleText(request~body,invocationContext)
  if wireReply == .nil then do
    response = .HttpResponse~empty(204)
  end
  else response = .HttpResponse~json(wireReply,200)
  response~header('Cache-Control','no-store')
  response~header('X-Content-Type-Options','nosniff')
  return response
 authenticationDenied:
  signal off syntax
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then
    say 'RPC HTTPS authentication failure' rc sigl condition('C') condition('D')
  return self~errorResponse(401,'Authentication required')
