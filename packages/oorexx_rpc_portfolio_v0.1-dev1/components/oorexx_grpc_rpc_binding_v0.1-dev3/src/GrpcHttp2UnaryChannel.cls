/* Real gRPC unary HTTP/2 client channel. Libcurl owns HTTP/2/TLS.
 * This does not participate in transport selection: ConnectSelector owns it.
 * Metadata is transport data only; service registration is still RPC Core.
 */
::class GrpcHttp2CallContext public
::attribute timeoutMs get
::attribute metadata get
::method init
  expose timeoutMs metadata
  use strict arg timeoutMs=10000,metadata=.nil
  if metadata==.nil then metadata=.directory~new
  if \datatype(timeoutMs,'W') | timeoutMs<1 | timeoutMs>600000 then
    raise syntax 93.900 additional('gRPC context timeout out of range')
  if \metadata~isA(.Directory) then raise syntax 93.900 additional('gRPC metadata must be a Directory')
::class GrpcHttp2UnaryChannel public
::method init
  expose base defaultTimeout caBundlePath
  use strict arg base, defaultTimeout=10000, caBundlePath=''
  if \base~isA(.String) then raise syntax 93.900 additional('Invalid gRPC endpoint')
  if \datatype(defaultTimeout,'W') | defaultTimeout<1 | defaultTimeout>600000 then
    raise syntax 93.900 additional('Invalid gRPC default timeout')
  if \caBundlePath~isA(.String) then raise syntax 93.900 additional('Invalid gRPC CA bundle')
::method exchange
  expose base defaultTimeout caBundlePath
  use strict arg path, framed, context=.nil
  timeoutMs=defaultTimeout
  headers=.directory~new
  if context \== .nil then do
    if \context~hasMethod('timeoutMs') | \context~hasMethod('metadata') then
      return .GrpcCallResult~new(3,'Invalid gRPC call context')
    timeoutMs=context~timeoutMs
    headers=context~metadata
  end
  if \datatype(timeoutMs,'W') | timeoutMs<1 | timeoutMs>600000 then
    return .GrpcCallResult~new(3,'Invalid gRPC timeout')
  if \headers~isA(.Directory) then return .GrpcCallResult~new(3,'Invalid gRPC metadata')
  nativeReply=GrpcNativeHttp2Post(base,path,framed,timeoutMs~string,headers,caBundlePath)
  if \nativeReply['ok'] then return .GrpcCallResult~new(nativeReply['code'],nativeReply['message'])
  grpcStatus=nativeReply['grpcStatus']
  if \datatype(grpcStatus,'W') then return .GrpcCallResult~new(13,'Invalid gRPC response status')
  if grpcStatus<0 | grpcStatus>16 then return .GrpcCallResult~new(13,'Invalid gRPC response status')
  if grpcStatus\==0 then return .GrpcCallResult~new(grpcStatus,'Remote gRPC method failed')
  return .GrpcCallResult~new(0,'',.Array~of(nativeReply['body']))
::requires 'GrpcRpcBinding.cls'
::requires 'grpchttp2' LIBRARY
