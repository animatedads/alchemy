/* ooRexx gRPC binding v0.1-dev2 -- transport-neutral unary/server-stream RPC.
 * The RPC registry authorises object+method invocation. SerializationSelector
 * owns protobuf. ConnectSelector owns network/provider choice.
 * This layer does NOT implement HTTP/2, grpc-web, or compression.
 */

::class GrpcCallResult public
::attribute status get
::attribute message get
::attribute frames get
::method init
  expose status message frames
  use strict arg status, message = '', frames = .nil
  if frames == .nil then frames = .array~new
::method ok
  expose status
  return status == 0
::method wireTrailers
  expose status message
  trailers = .directory~new
  trailers['grpc-status'] = status~string
  if message \== '' then trailers['grpc-message'] = self~percentEncode(message)
  return trailers
::method percentEncode private
  use strict arg value
  safe = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~'
  encodedText = ''
  do i=1 to value~length
    char = value~substr(i,1)
    if safe~pos(char)>0 then encodedText = encodedText || char
    else encodedText = encodedText || '%' || char~c2x
  end
  return encodedText

/* Message framing is gRPC length-prefixing, NOT an arbitrary TCP protocol.
 * Each message: 1 byte compressed flag, 4 byte big-endian length, payload.
 * A transport must place these bytes in a gRPC HTTP/2 DATA stream.
 */
::class GrpcFrameCodec public
::method init
  expose maximum
  use strict arg maximum = 4194304
  if \datatype(maximum,'W') | maximum<1 | maximum>2147483647 then raise syntax 93.900 additional('Invalid gRPC maximum frame size')
::attribute maximum get
::method pack
  expose maximum
  use strict arg bytes
  if \bytes~isA(.String) then raise syntax 93.900 additional('gRPC payload must be a string')
  n = bytes~length
  if n>maximum then raise syntax 93.900 additional('gRPC payload exceeds configured maximum')
  header = d2c(0)
  do offset over .array~of(16777216,65536,256,1)
    byte = (n % offset) // 256
    header = header || x2c(d2x(byte,2))
  end
  return header || bytes
::method reader
  return .GrpcFrameReader~new(self)
::method unpackOne
  use strict arg framed
  reader = self~reader
  messages = reader~feed(framed)
  if \reader~finish then raise syntax 93.900 additional('Incomplete gRPC frame')
  if messages~items \== 1 then raise syntax 93.900 additional('Expected exactly one gRPC message')
  return messages[1]

::class GrpcFrameReader public
::method init
  expose codec pending
  use strict arg codec
  pending=''
::method feed
  expose codec pending
  use strict arg chunk
  if \chunk~isA(.String) then raise syntax 93.900 additional('gRPC chunk must be byte string')
  pending = pending || chunk
  messages = .array~new
  do while pending~length >= 5
    flag = x2d(pending~substr(1,1)~c2x)
    if flag \== 0 then raise syntax 93.900 additional('Compressed/invalid gRPC flag unsupported')
    n = 0
    do i=2 to 5
      n = n*256 + x2d(pending~substr(i,1)~c2x)
    end
    if n>codec~maximum then raise syntax 93.900 additional('gRPC message limit exceeded')
    if pending~length < 5+n then leave
    messages~append(pending~substr(6,n))
    pending = pending~substr(6+n)
  end
  return messages
::method finish
  expose pending
  return pending == ''

::class GrpcMethodDefinition public
::attribute path get
::attribute service get
::attribute operation get
::attribute requestCodec get
::attribute responseCodec get
::attribute mode get
::method init
  expose path service operation requestCodec responseCodec mode
  use strict arg path,service,operation,requestCodec,responseCodec,mode

/* Explicitly map external gRPC path to an already-published RPC operation.
 * Type schemas are server-side allowlisted; callers cannot choose serializers.
 */
::class GrpcMethodRegistry public
::method init
  expose definitions frozen
  definitions=.Table~new
  frozen=.false
::method validPath private
  use strict arg path
  if \path~isA(.String) then return .false
  if path~length<4 | path~substr(1,1) \== '/' then return .false
  divider=path~lastPos('/')
  if divider<3 | divider==path~length then return .false
  service=path~substr(2,divider-2)
  operation=path~substr(divider+1)
  svcchars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.'
  opchars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'
  if service~verify(svcchars) \== 0 | operation~verify(opchars) \== 0 then return .false
  if service~pos('..')>0 | service~substr(1,1)=='.' | service~right(1)=='.' then return .false
  return .true
::method add private
  expose definitions frozen
  use strict arg path,service,operation,requestCodec,responseCodec,mode
  if frozen then raise syntax 93.900 additional('gRPC method registry frozen')
  if \self~validPath(path) then raise syntax 93.900 additional('Invalid gRPC method path')
  if \service~isA(.String) | \operation~isA(.String) then raise syntax 93.900 additional('Invalid RPC name')
  if service == '' | operation == '' then raise syntax 93.900 additional('Empty RPC name')
  if \requestCodec~isA(.String) | \responseCodec~isA(.String) then raise syntax 93.900 additional('Invalid gRPC codec name')
  if \.SerializationSelector~registered(requestCodec) | \.SerializationSelector~registered(responseCodec) then raise syntax 93.900 additional('Schema codec not registered')
  if definitions~hasIndex(path) then raise syntax 93.900 additional('gRPC duplicate method path')
  definitions[path]=.GrpcMethodDefinition~new(path,service,operation,requestCodec,responseCodec,mode)
  return self
::method registerUnary
  use strict arg path,service,operation,requestCodec,responseCodec
  return self~add(path,service,operation,requestCodec,responseCodec,'UNARY')
::method registerServerStream
  use strict arg path,service,operation,requestCodec,responseCodec
  return self~add(path,service,operation,requestCodec,responseCodec,'SERVER_STREAM')
::method resolve
  expose definitions
  use strict arg path
  if \path~isA(.String) then return .nil
  return definitions[path]
::method freeze
  expose frozen
  frozen=.true
  return self
::attribute frozen get

/* Client/channel layer owns HTTP/2 flow-control and final stream close.
 * The callback sink reports encoded frames to an injected frame writer.
 */
::class GrpcCallbackSink public
::method init
  expose codec frameCodec writer ended cancelled outcome emitted maxMessages
  use strict arg codec,frameCodec,writer,maxMessages=10000
  if \writer~hasMethod('write') then raise syntax 93.900 additional('gRPC writer requires write(frame)')
  ended=.false
  cancelled=.false
  outcome=.GrpcCallResult~new(0)
  emitted=0
::method onNext
  expose codec frameCodec writer ended cancelled emitted outcome maxMessages
  use strict arg value
  if ended then return .false
  if self~isCancelled then do
    cancelled=.true
    ended=.true
    outcome=.GrpcCallResult~new(1,'RPC cancelled')
    return .false
  end
  if emitted>=maxMessages then do
    self~onFault(.RpcServiceFault~new('RESOURCE_EXHAUSTED','Maximum streaming messages reached'))
    return .false
  end
  signal on syntax name encodingFailed
  bytes=codec~encode(value)
  framed=frameCodec~pack(bytes)
  signal off syntax
  signal on syntax name writerFailed
  sent=writer~write(framed)
  signal off syntax
  if \sent then do
    cancelled=.true
    outcome=.GrpcCallResult~new(14,'Stream writer failed')
    ended=.true
    return .false
  end
  emitted+=1
  return .true
writerFailed:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'gRPC internal diagnostic' rc sigl condition("C") condition("D")
  signal off syntax
  cancelled=.true
  ended=.true
  outcome=.GrpcCallResult~new(14,'Stream writer failed')
  return .false
encodingFailed:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'gRPC internal diagnostic' rc sigl condition("C") condition("D")
  signal off syntax
  self~onFault(.RpcServiceFault~new('INTERNAL','Response serialization failed'))
  return .false
::method onComplete
  expose ended outcome
  use strict arg status=.nil
  if ended then return .false
  ended=.true
  if self~isCancelled then outcome=.GrpcCallResult~new(1,'RPC cancelled')
  else outcome=.GrpcCallResult~new(0)
  return .true
::method onFault
  expose ended outcome
  use strict arg fault
  if ended then return .false
  ended=.true
  outcome=.GrpcStatusMap~fromFault(fault)
  return .true
::method isCancelled
  expose writer cancelled
  if cancelled then return .true
  if writer~hasMethod('isCancelled') then return writer~isCancelled
  return .false
::method cancel
  expose cancelled
  cancelled=.true
  return .true
::attribute ended get
::attribute outcome get
::attribute emitted get

::class GrpcStatusMap public
::method fromFault class
  use strict arg fault
  code='INTERNAL'
  if fault \== .nil then do
    if fault~hasMethod('code') then code=fault~code~string~translate
  end
  select
    when code=='NOT_FOUND' then status=12
    when code=='INVALID_ARGUMENT' then status=3
    when code=='INVALID_INVOCATION' then status=9
    when code=='CANCELLED' then status=1
    when code=='DEADLINE_EXCEEDED' then status=4
    when code=='RESOURCE_EXHAUSTED' then status=8
    when code=='UNAVAILABLE' then status=14
    when code=='PERMISSION_DENIED' then status=7
    otherwise status=13
  end
  /* No internal exception details exposed to remote clients. */
  return .GrpcCallResult~new(status,self~safeMessage(status))
::method safeMessage class private
  use strict arg status
  select
    when status==12 then return 'RPC method unavailable'
    when status==3 then return 'Invalid RPC argument'
    when status==9 then return 'RPC invocation mode unsupported'
    when status==1 then return 'RPC cancelled'
    when status==4 then return 'RPC deadline exceeded'
    when status==8 then return 'RPC resource exhausted'
    when status==14 then return 'RPC transport unavailable'
    when status==7 then return 'RPC permission denied'
    otherwise return 'Internal RPC error'
  end

::class GrpcRpcBinding public
::method init
  expose definitions dispatcher frameCodec
  use strict arg definitions,dispatcher,frameCodec=.nil
  if frameCodec==.nil then frameCodec=.GrpcFrameCodec~new
::method resolveRequest private
  expose definitions
  use strict arg path,mode
  definition=definitions~resolve(path)
  if definition==.nil then return .nil
  if definition~mode \== mode then return .nil
  return definition
::method unary
  expose dispatcher frameCodec
  use strict arg path,framed,context=.nil
  definition=self~resolveRequest(path,'UNARY')
  if definition==.nil then return .GrpcCallResult~new(12,'RPC method unavailable')
  signal on syntax name malformedRequest
  payload=frameCodec~unpackOne(framed)
  requestCodec=.SerializationSelector~new(definition~requestCodec)
  arguments=requestCodec~decode(payload)
  signal off syntax
  reply=dispatcher~invoke(definition~service,definition~operation,arguments,context)
  if \reply~ok then return .GrpcStatusMap~fromFault(reply~fault)
  signal on syntax name responseFailure
  responseCodec=.SerializationSelector~new(definition~responseCodec)
  bytes=responseCodec~encode(reply~value)
  frame=frameCodec~pack(bytes)
  signal off syntax
  return .GrpcCallResult~new(0,'',.Array~of(frame))
malformedRequest:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'gRPC internal diagnostic' rc sigl condition("C") condition("D")
  signal off syntax
  return .GrpcCallResult~new(3,'Malformed gRPC request or protobuf value')
responseFailure:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'gRPC internal diagnostic' rc sigl condition("C") condition("D")
  signal off syntax
  return .GrpcCallResult~new(13,'Response serialization failed')
::method serverStream
  expose dispatcher frameCodec
  use strict arg path,framed,writer,context=.nil
  definition=self~resolveRequest(path,'SERVER_STREAM')
  if definition==.nil then return .GrpcCallResult~new(12,'RPC method unavailable')
  if writer~hasMethod('isCancelled') then do
    if writer~isCancelled then return .GrpcCallResult~new(1,'RPC cancelled')
  end
  signal on syntax name malformedStreamRequest
  payload=frameCodec~unpackOne(framed)
  requestCodec=.SerializationSelector~new(definition~requestCodec)
  arguments=requestCodec~decode(payload)
  responseCodec=.SerializationSelector~new(definition~responseCodec)
  sink=.GrpcCallbackSink~new(responseCodec,frameCodec,writer)
  signal off syntax
  reply=dispatcher~invokeCallback(definition~service,definition~operation,arguments,context,sink)
  if \reply~ok then do
    if sink~ended then do
      if \sink~outcome~ok then return sink~outcome
    end
    return .GrpcStatusMap~fromFault(reply~fault)
  end
  if \sink~ended then return .GrpcCallResult~new(13,'Streaming method did not complete')
  return sink~outcome
malformedStreamRequest:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'gRPC internal diagnostic' rc sigl condition("C") condition("D")
  signal off syntax
  return .GrpcCallResult~new(3,'Malformed gRPC stream request')

::class GrpcClientReply public
::attribute ok get
::attribute value get
::attribute status get
::attribute message get
::method init
  expose ok value status message
  use strict arg ok,value,status,message

::class GrpcClientRoute public
::attribute path get
::attribute requestCodec get
::attribute responseCodec get
::method init
  expose path requestCodec responseCodec
  use strict arg path,requestCodec,responseCodec

/* Codec registration and routing are explicit, not inferred from wire input.
 * Channel implements exchange(path,framed,context), and is supplied by caller.
 * A true gRPC network channel must perform HTTP/2 headers, DATA, trailers,
 * flow control, security, deadlines, and metadata handling.
 */
::class GrpcUnaryClient public
::method init
  expose channel routes frameCodec
  use strict arg channel,frameCodec=.nil
  if \channel~hasMethod('exchange') then raise syntax 93.900 additional('gRPC channel requires exchange(path,frame,context)')
  if frameCodec==.nil then frameCodec=.GrpcFrameCodec~new
  routes=.Table~new
::method bind
  expose routes
  use strict arg operation,path,requestCodec,responseCodec
  if routes~hasIndex(operation) then raise syntax 93.900 additional('Duplicate client RPC operation')
  if \.SerializationSelector~registered(requestCodec) | \.SerializationSelector~registered(responseCodec) then raise syntax 93.900 additional('Missing protobuf schema codec')
  routes[operation]=.GrpcClientRoute~new(path,requestCodec,responseCodec)
  return self
::method request
  expose channel routes frameCodec
  use strict arg operation,arguments,context=.nil
  route=routes[operation]
  if route==.nil then return .GrpcClientReply~new(.false,.nil,12,'RPC method not registered by client')
  signal on syntax name codecFailed
  requestCodec=.SerializationSelector~new(route~requestCodec)
  framed=frameCodec~pack(requestCodec~encode(arguments))
  signal off syntax
  reply=channel~exchange(route~path,framed,context)
  if \reply~ok then return .GrpcClientReply~new(.false,.nil,reply~status,reply~message)
  signal on syntax name invalidResponse
  if reply~frames~items\==1 then raise syntax 93.900 additional('Invalid unary response message count')
  payload=frameCodec~unpackOne(reply~frames[1])
  responseCodec=.SerializationSelector~new(route~responseCodec)
  answer=responseCodec~decode(payload)
  signal off syntax
  return .GrpcClientReply~new(.true,answer,0,'')
codecFailed:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'gRPC internal diagnostic' rc sigl condition("C") condition("D")
  signal off syntax
  return .GrpcClientReply~new(.false,.nil,3,'Request serialization failed')
invalidResponse:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'gRPC internal diagnostic' rc sigl condition("C") condition("D")
  signal off syntax
  return .GrpcClientReply~new(.false,.nil,13,'Malformed server response')

/* Deliberately local test channel, never an HTTP/2 or network substitute. */
::class GrpcLoopbackChannel public
::method init
  expose binding
  use strict arg binding
::method exchange
  expose binding
  use strict arg path,framed,context=.nil
  return binding~unary(path,framed,context)

::requires 'RpcServiceCore.cls'
::requires 'SerializationSelector.cls'
