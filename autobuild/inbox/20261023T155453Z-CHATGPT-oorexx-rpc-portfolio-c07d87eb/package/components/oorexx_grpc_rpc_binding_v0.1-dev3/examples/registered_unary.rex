/* Run under the same exact dependency roots as tests/run.sh. */
requestSchema=.directory~new;requestSchema['id']='1:uint32'
replySchema=.directory~new;replySchema['id']='1:uint32'
call registerProtobuf 'demo.req',requestSchema
call registerProtobuf 'demo.reply',replySchema
registry=.RpcServiceRegistry~new
registry~registerMethod('demo','lookup',.CatalogService~new,'lookup')
registry~freeze
methods=.GrpcMethodRegistry~new
methods~registerUnary('/demo.Catalog/Lookup','demo','lookup','demo.req','demo.reply')
methods~freeze
binding=.GrpcRpcBinding~new(methods,.RpcServiceDispatcher~new(registry))
client=.GrpcUnaryClient~new(.GrpcLoopbackChannel~new(binding))
client~bind('demo.lookup','/demo.Catalog/Lookup','demo.req','demo.reply')
params=.directory~new;params['id']=40
response=client~request('demo.lookup',params)
if \response~ok then do
  say 'RPC FAILED' response~status response~message
  exit 1
end
say 'RPC result id:' response~value['id']
exit 0
::class CatalogService
::method lookup
  use strict arg args,context
  answer=.directory~new
  answer['id']=args['id']+2
  return answer
::requires 'Protobuf.cls'
::requires 'GrpcRpcBinding.cls'
