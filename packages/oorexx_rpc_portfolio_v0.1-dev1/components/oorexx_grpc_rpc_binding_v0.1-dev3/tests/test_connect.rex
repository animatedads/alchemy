checks=0
requestSchema=.directory~new;requestSchema['id']='1:uint32'
responseSchema=.directory~new;responseSchema['id']='1:uint32'
call registerProtobuf 'test.grpc.req',requestSchema
call registerProtobuf 'test.grpc.res',responseSchema
service=.TestObject~new
register=.RpcServiceRegistry~new
register~registerMethod('catalog','lookup',service,'fetch')
register~freeze
methods=.GrpcMethodRegistry~new
methods~registerUnary('/demo.Catalog/Lookup','catalog','lookup','test.grpc.req','test.grpc.res')
methods~freeze
binding=.GrpcRpcBinding~new(methods,.RpcServiceDispatcher~new(register))
client=.GrpcUnaryClient~new(.GrpcLoopbackChannel~new(binding))
client~bind('catalog.lookup','/demo.Catalog/Lookup','test.grpc.req','test.grpc.res')
bridge=.GrpcConnectAdapter~new(client,'CATALOG')
call check bridge~hasMethod('supports') & bridge~hasMethod('execute'), 'ConnectSelector injected adapter contract'
policy=.ConnectRoutePolicy~new
policy~allow('catalog.lookup','REQUEST','RPC','CATALOG')
policy~allow('catalog.lookup','NOTIFY','RPC','CATALOG')
policy~allow('catalog.lookup','ENQUEUE','RPC','CATALOG')
selector=.ConnectSelector~new(policy)
selector~register('RPC',bridge,'CATALOG')
intent=.ConnectIntent~new('catalog.lookup','REQUEST','IMMEDIATE','RPC','CATALOG')
params=.directory~new;params['id']=99
answer=selector~execute(intent,params)
call check answer~ok, 'ConnectSelector request accepted'
call check answer~provider=='RPC' & answer~completed & \answer~durable, 'RPC completion is not durable enqueue'
call check answer~value['id']==100, 'ConnectSelector reaches correct published ooRexx method'
intent=.ConnectIntent~new('catalog.lookup','NOTIFY','BEST_EFFORT','RPC','CATALOG')
answer=selector~execute(intent,params)
call check \answer~ok & answer~code=='UNSUPPORTED', 'gRPC does not invent notification semantics'
intent=.ConnectIntent~new('catalog.lookup','ENQUEUE','DURABLE','RPC','CATALOG')
answer=selector~execute(intent,params)
call check \answer~ok, 'gRPC does not invent durable queue semantics'
intent=.ConnectIntent~new('catalog.lookup','REQUEST','IMMEDIATE','RPC','OTHER')
answer=selector~execute(intent,params)
call check \answer~ok, 'destination isolation enforced'
intent=.ConnectIntent~new('catalog.lookup','REQUEST','IMMEDIATE','RPC','CATALOG')
policy~deny('catalog.lookup','REQUEST','RPC','CATALOG')
answer=selector~execute(intent,params)
call check \answer~ok & answer~code=='POLICY_DENIED', 'ConnectSelector policy has final authority'
say 'PASS' checks 'ConnectSelector gRPC route checks'
exit 0
check:
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  checks+=1
return
::class TestObject
::method fetch
  use strict arg args,ctx
  answer=.directory~new
  answer['id']=args['id']+1
  return answer
::requires 'Protobuf.cls'
::requires 'GrpcRpcBinding.cls'
::requires 'GrpcConnectAdapter.cls'
