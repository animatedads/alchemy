/* Exercise actual TLS with certificate and ALPN h2 against independent h2 fixture. */
parse arg port certificate
checks=0
schema=.directory~new;schema['id']='1:uint32'
call registerProtobuf 'tls.req',schema
call registerProtobuf 'tls.res',schema
requestData=.directory~new;requestData['id']=41
base='https://127.0.0.1:'||port
client=.GrpcUnaryClient~new(.GrpcHttp2UnaryChannel~new(base,1500))
client~bind('get','/demo.Inventory/Get','tls.req','tls.res')
reply=client~request('get',requestData)
call check \reply~ok & reply~status==14, 'self-signed untrusted certificate rejected'
client=.GrpcUnaryClient~new(.GrpcHttp2UnaryChannel~new(base,1500,certificate))
client~bind('get','/demo.Inventory/Get','tls.req','tls.res')
reply=client~request('get',requestData)
call check reply~ok & reply~value['id']==42, 'verified TLS HTTP/2 gRPC via explicit trusted certificate'
say 'PASS' checks 'ALPN HTTP/2 TLS trust checks'
exit 0
check:
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  checks+=1
return
::requires 'Protobuf.cls'
::requires 'GrpcHttp2UnaryChannel.cls'
