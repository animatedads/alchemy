/* Live HTTP/2 unary gRPC interoperability against separate hyper-h2 server. */
parse arg port
checks=0
reqSchema=.directory~new; reqSchema['id']='1:uint32'
resSchema=.directory~new; resSchema['id']='1:uint32'
call registerProtobuf 'h2.req',reqSchema
call registerProtobuf 'h2.res',resSchema
channel=.GrpcHttp2UnaryChannel~new('http://127.0.0.1:'||port,1500)
client=.GrpcUnaryClient~new(channel)
client~bind('ok','/demo.Inventory/Get','h2.req','h2.res')
client~bind('metadata','/demo.Inventory/Metadata','h2.req','h2.res')
client~bind('remoteFault','/demo.Inventory/RemoteFault','h2.req','h2.res')
client~bind('missing','/demo.Inventory/NoStatus','h2.req','h2.res')
client~bind('content','/demo.Inventory/BadContent','h2.req','h2.res')
client~bind('httpError','/demo.Inventory/HTTPError','h2.req','h2.res')
client~bind('deadline','/demo.Inventory/Deadline','h2.req','h2.res')
client~bind('badCodec','/demo.Inventory/BadCodec','h2.req','h2.res')
client~bind('duplicate','/demo.Inventory/DuplicateStatus','h2.req','h2.res')
client~bind('timeoutHeader','/demo.Inventory/TimeoutHeader','h2.req','h2.res')
requestData=.directory~new; requestData['id']=41
reply=client~request('ok',requestData)
call check reply~ok & reply~value['id']==42, 'binary protobuf roundtrip over real HTTP/2'
metadata=.directory~new; metadata['x-trace']='token123'
ctx=.GrpcHttp2CallContext~new(1000,metadata)
reply=client~request('metadata',requestData,ctx)
call check reply~ok & reply~value['id']==42, 'lowercase application metadata propagated'
reply=client~request('remoteFault',requestData)
call check \reply~ok & reply~status==7, 'remote grpc-status trailer projected'
reply=client~request('missing',requestData)
call check \reply~ok & reply~status==13, 'missing grpc-status rejected'
reply=client~request('content',requestData)
call check \reply~ok & reply~status==13, 'wrong grpc content-type rejected'
reply=client~request('badCodec',requestData)
call check \reply~ok & reply~status==13, 'grpc+json content-type cannot pass protobuf-only binding'
reply=client~request('duplicate',requestData)
call check \reply~ok & reply~status==13, 'duplicate grpc-status values rejected'
reply=client~request('timeoutHeader',requestData,.GrpcHttp2CallContext~new(500))
call check reply~ok, 'gRPC wire timeout header generated correctly'
reply=client~request('httpError',requestData)
call check \reply~ok & reply~status==14, 'HTTP-level failure is not RPC success'
reply=client~request('deadline',requestData,.GrpcHttp2CallContext~new(30))
call check \reply~ok & reply~status==4, 'native HTTP/2 timeout enforced'
metadata=.directory~new; metadata['grpc-status']='0'
reply=client~request('metadata',requestData,.GrpcHttp2CallContext~new(1000,metadata))
call check \reply~ok & reply~status==3, 'reserved metadata rejected'
metadata=.directory~new;metadata['x-evil']='bad'||'0a'x||'Injected: true'
reply=client~request('metadata',requestData,.GrpcHttp2CallContext~new(1000,metadata))
call check \reply~ok & reply~status==3, 'header injection rejected'
badChannel=.GrpcHttp2UnaryChannel~new('http://example.com',1000)
reply=badChannel~exchange('/demo.Inventory/Get','0000000000'x)
call check \reply~ok & reply~status==3, 'cleartext remote HTTP/2 refused'
metadata=.directory~new; metadata['content-type']='text/plain'
reply=client~request('metadata',requestData,.GrpcHttp2CallContext~new(1000,metadata))
call check \reply~ok & reply~status==3, 'transport content-type cannot be overridden'
reply=channel~exchange('/demo.Inventory/Get','00000000'x)
call check \reply~ok & reply~status==3, 'malformed grpc frame rejected without network'
say 'PASS' checks 'real HTTP/2 unary/metadata/error/deadline checks'
exit 0
check:
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  checks+=1
return

::requires 'GrpcHttp2UnaryChannel.cls'
::requires 'Protobuf.cls'
