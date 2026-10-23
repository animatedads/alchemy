/* Live ooRexx callbacks through independent h2 streaming fixture. */
parse arg port
schema=.directory~new
schema['id']='1:uint32'
call registerProtobuf 'grpc.stream.id', schema
receiver=.TestObserver~new
client=.GrpcHttp2ServerStreamClient~new('http://127.0.0.1:'port)
unused=client~bind('watch','/demo.Inventory/Watch','grpc.stream.id','grpc.stream.id')
requestValue=.directory~new
requestValue['id']=1
reply=client~request('watch',requestValue,receiver)
if \reply~ok | receiver~values~items\==3 | receiver~completed\==1 | receiver~faulted\==0 then do
  say 'FAIL streaming callbacks' reply~status receiver~values~items receiver~completed receiver~faulted
  exit 1
end
if receiver~values[1]\==42 | receiver~values[2]\==43 | receiver~values[3]\==44 then do
  say 'FAIL decoded protobuf stream values'
  exit 2
end
say 'PASS ooRexx live HTTP/2 callbacks = 3'
receiver2=.TestObserver~new
bad=.GrpcHttp2ServerStreamClient~new('http://127.0.0.1:'port)
unused=bad~bind('watch','/demo.Inventory/Fault','grpc.stream.id','grpc.stream.id')
reply=bad~request('watch',requestValue,receiver2)
if reply~status\==7 | receiver2~values~items\==3 | receiver2~faulted\==1 | receiver2~completed\==0 then do
 say 'FAIL remote final fault' reply~status receiver2~values~items
 exit 3
end
say 'PASS streamed values then remote status 7'
receiver3=.TestObserver~new
receiver3~cancelAt(1)
slow=.GrpcHttp2ServerStreamClient~new('http://127.0.0.1:'port)
unused=slow~bind('watch','/demo.Inventory/Slow','grpc.stream.id','grpc.stream.id')
reply=slow~request('watch',requestValue,receiver3)
if reply~status\==1 | receiver3~values~items\==1 then do
 say 'FAIL callback cancellation' reply~status receiver3~values~items
 exit 4
end
say 'PASS callback cancellation'
receiver4=.TestObserver~new
bounded=.GrpcHttp2ServerStreamClient~new('http://127.0.0.1:'port,10000,'',1)
unused=bounded~bind('watch','/demo.Inventory/Watch','grpc.stream.id','grpc.stream.id')
reply=bounded~request('watch',requestValue,receiver4)
if reply~status\==8 | receiver4~values~items\==1 | receiver4~faulted\==1 then do
 say 'FAIL stream message-count bound' reply~status receiver4~values~items
 exit 5
end
say 'PASS message-count bound (RESOURCE_EXHAUSTED)'
exit 0
::class TestObserver
::attribute values get
::attribute completed get
::attribute faulted get
::attribute cancelAfter
::method init
  expose values completed faulted cancelAfter
  values=.array~new
  completed=0
  faulted=0
  cancelAfter=0
::method cancelAt
  expose cancelAfter
  use strict arg n
  cancelAfter=n
::method onNext
  expose values cancelAfter
  use strict arg value
  values~append(value['id'])
  if cancelAfter>0 then do
    if values~items>=cancelAfter then return .false
  end
  return .true
::method onComplete
  expose completed
  completed=completed+1
::method onFault
  expose faulted
  use strict arg value
  faulted=faulted+1

::requires 'GrpcHttp2ServerStreamChannel.cls'
::requires 'Protobuf.cls'
::requires 'json.cls'
