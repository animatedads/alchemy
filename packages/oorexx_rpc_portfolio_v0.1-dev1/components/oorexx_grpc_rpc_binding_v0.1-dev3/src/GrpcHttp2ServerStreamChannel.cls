/* Outbound, synchronous HTTP/2 server-streaming client with incremental
 * observer callbacks. Network worker cannot invoke ooRexx objects directly:
 * polling delivers events on the requesting ooRexx activity.
 * No retry, implicit routing, or protobuf implementation here.
 */
::class GrpcHttp2ServerStreamClient public
::method init
  expose base defaultTimeout caBundlePath routes frameCodec maxMessages
  use strict arg base,defaultTimeout=10000,caBundlePath='',maxMessages=10000
  if \base~isA(.String) | \caBundlePath~isA(.String) then
    raise syntax 93.900 additional('Invalid gRPC streaming connection')
  if \datatype(defaultTimeout,'W') | defaultTimeout<1 | defaultTimeout>600000 then
    raise syntax 93.900 additional('Invalid gRPC streaming timeout')
  if \datatype(maxMessages,'W') | maxMessages<1 | maxMessages>100000 then
    raise syntax 93.900 additional('Invalid gRPC message count bound')
  routes=.table~new
  frameCodec=.GrpcFrameCodec~new
::method bind
  expose routes
  use strict arg operation,path,requestCodec,responseCodec
  if \operation~isA(.String) | \path~isA(.String) then
    raise syntax 93.900 additional('Invalid streaming registration')
  if routes~hasIndex(operation) then
    raise syntax 93.900 additional('Duplicate streaming operation')
  if \.SerializationSelector~registered(requestCodec) | \.SerializationSelector~registered(responseCodec) then
    raise syntax 93.900 additional('Missing streaming protobuf codec')
  routes[operation]=.GrpcClientRoute~new(path,requestCodec,responseCodec)
  return self
::method request
  expose base defaultTimeout caBundlePath routes frameCodec maxMessages
  use strict arg operation,arguments,observer,context=.nil
  if \observer~hasMethod('onNext') | \observer~hasMethod('onComplete') | \observer~hasMethod('onFault') then
    raise syntax 93.900 additional('Observer needs onNext/onComplete/onFault')
  route=routes[operation]
  if route==.nil then do
    resultValue=.GrpcCallResult~new(12,'Streaming operation not registered')
    observer~onFault(resultValue)
    return resultValue
  end
  timeoutMs=defaultTimeout
  metadata=.directory~new
  if context \== .nil then do
    if \context~hasMethod('timeoutMs') | \context~hasMethod('metadata') then do
      resultValue=.GrpcCallResult~new(3,'Invalid streaming call context')
      observer~onFault(resultValue)
      return resultValue
    end
    timeoutMs=context~timeoutMs
    metadata=context~metadata
  end
  if \datatype(timeoutMs,'W') | timeoutMs<1 | timeoutMs>600000 | \metadata~isA(.Directory) then do
    resultValue=.GrpcCallResult~new(3,'Invalid streaming options')
    observer~onFault(resultValue)
    return resultValue
  end
  handle=''
  signal on syntax name streamError
  requestCodec=.SerializationSelector~new(route~requestCodec)
  responseCodec=.SerializationSelector~new(route~responseCodec)
  framed=frameCodec~pack(requestCodec~encode(arguments))
  opened=GrpcNativeStreamOpen(base,route~path,framed,timeoutMs~string,metadata,caBundlePath)
  if \opened['ok'] then do
    resultValue=.GrpcCallResult~new(opened['code'],opened['message'])
    observer~onFault(resultValue)
    signal off syntax
    return resultValue
  end
  handle=opened['handle']
  reader=frameCodec~reader
  count=0
  cancelled=.false
  limitReached=.false
  do forever
    if observer~hasMethod('isCancelled') then do
      if observer~isCancelled then cancelled=.true
    end
    if cancelled then ignored=GrpcNativeStreamCancel(handle)
    event=GrpcNativeStreamPoll(handle,'100')
    if \event['ok'] then do
      resultValue=.GrpcCallResult~new(14,'Streaming poll failure')
      leave
    end
    kind=event['kind']
    select
      when kind=='IDLE' then iterate
      when kind=='DATA' then do
        if cancelled then iterate
        chunks=reader~feed(event['chunk'])
        do k=1 to chunks~items
          if count>=maxMessages then do
            limitReached=.true
            cancelled=.true
            ignored=GrpcNativeStreamCancel(handle)
            leave
          end
          value=responseCodec~decode(chunks[k])
          count+=1
          accepted=observer~onNext(value)
          if \accepted then do
            cancelled=.true
            ignored=GrpcNativeStreamCancel(handle)
            leave
          end
        end
      end
      when kind=='END' then do
        resultValue=.GrpcCallResult~new(event['code'],event['message'])
        if resultValue~ok then do
          if \reader~finish then resultValue=.GrpcCallResult~new(13,'Truncated final streaming message')
        end
        if cancelled then resultValue=.GrpcCallResult~new(1,'RPC cancelled')
        if limitReached then resultValue=.GrpcCallResult~new(8,'Maximum stream message count exceeded')
        leave
      end
      otherwise do
        resultValue=.GrpcCallResult~new(13,'Unexpected streaming event')
        leave
      end
    end
  end
  ignored=GrpcNativeStreamClose(handle)
  handle=''
  signal off syntax
  if resultValue~ok then observer~onComplete
  else observer~onFault(resultValue)
  return resultValue
streamError:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then
    say 'gRPC stream internal diagnostic' rc sigl condition("C") condition("D")
  signal off syntax
  if handle \== '' then do
    ignored=GrpcNativeStreamCancel(handle)
    ignored=GrpcNativeStreamClose(handle)
  end
  resultValue=.GrpcCallResult~new(13,'Streaming callback or serialization failure')
  return resultValue
::requires 'GrpcRpcBinding.cls'
::requires 'grpcstream' LIBRARY
