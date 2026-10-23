/* Live gRPC HTTP/2 invocation through ConnectSelector route authority. */
parse arg port
checks=0
schema=.directory~new;schema['id']='1:uint32'
call registerProtobuf 'h2.selector.req',schema
call registerProtobuf 'h2.selector.res',schema
client=.GrpcUnaryClient~new(.GrpcHttp2UnaryChannel~new('http://127.0.0.1:'||port,1000))
client~bind('inventory.get','/demo.Inventory/Get','h2.selector.req','h2.selector.res')
bridge=.GrpcConnectAdapter~new(client,'INVENTORY')
policy=.ConnectRoutePolicy~new
policy~allow('inventory.get','REQUEST','RPC','INVENTORY')
selector=.ConnectSelector~new(policy)
selector~register('RPC',bridge,'INVENTORY')
inputData=.directory~new;inputData['id']=41
intent=.ConnectIntent~new('inventory.get','REQUEST','IMMEDIATE','RPC','INVENTORY')
answer=selector~execute(intent,inputData)
call check answer~ok & answer~value['id']==42, 'actual HTTP/2 request through ConnectSelector RPC route'
call check answer~completed & \answer~durable, 'RPC completion does not imply durable delivery'
policy~deny('inventory.get','REQUEST','RPC','INVENTORY')
answer=selector~execute(intent,inputData)
call check \answer~ok & answer~code=='POLICY_DENIED', 'policy denial before network dispatch'
say 'PASS' checks 'live HTTP/2 ConnectSelector checks'
exit 0
check:
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  checks+=1
return
::requires 'Protobuf.cls'
::requires 'GrpcHttp2UnaryChannel.cls'
::requires 'GrpcConnectAdapter.cls'
