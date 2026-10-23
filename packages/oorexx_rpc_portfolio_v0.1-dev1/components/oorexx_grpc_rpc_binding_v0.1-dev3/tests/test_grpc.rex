checks=0
requestSchema=.directory~new; requestSchema['id']='1:uint32'
responseSchema=.directory~new; responseSchema['id']='1:uint32'
call registerProtobuf 'grpc.req',requestSchema
call registerProtobuf 'grpc.res',responseSchema
call check .SerializationSelector~registered('grpc.req'), 'request codec registration'
call check .SerializationSelector~registered('grpc.res'), 'response codec registration'
framer=.GrpcFrameCodec~new(1024)
call check framer~pack(x2c('0001FF'))~c2x == '00000000030001FF', 'gRPC five byte network frame'
call check framer~pack('')~c2x == '0000000000', 'empty frame'
call check framer~unpackOne(framer~pack('hello')) == 'hello', 'single framed payload'
reader=framer~reader
call check reader~feed(x2c('000000'))~items==0, 'partial header accepted'
call check reader~feed(x2c('000568'))~items==0, 'partial body accepted'
out=reader~feed('ello')
call check out~items==1 & out[1]=='hello', 'split fragments reassembled'
call check reader~finish, 'reader complete'
reader=framer~reader
out=reader~feed(framer~pack('one')||framer~pack('two'))
call check out~items==2 & out[1]=='one' & out[2]=='two', 'multiple frames coalesced'
call check invalidFrame(framer,x2c('0100000000')), 'compressed flag rejected'
call check invalidFrame(framer,x2c('0200000000')), 'invalid flag rejected'
call check invalidFrame(framer,x2c('0000000401')), 'oversize declared payload rejected'
call check invalidFrame(framer,x2c('0000000001')), 'truncated frame rejected'
call check invalidFrame(framer,framer~pack('a')||framer~pack('b')), 'unary rejects multiple frames'
call check invalidFrame(framer,x2c('0000000001')), 'length and payload must agree'
call check tooLarge(framer), 'encoding size limit enforced'

methods=.GrpcMethodRegistry~new
registry=.RpcServiceRegistry~new
service=.SampleService~new
registry~registerMethod('inventory','get',service,'lookup')
registry~registerCallbackMethod('inventory','watch',service,'observe')
registry~registerMethod('inventory','fails',service,'explode')
registry~registerMethod('inventory','badreply',service,'invalidReply')
registry~registerCallbackMethod('inventory','unfinished',service,'unfinished')
registry~registerCallbackMethod('inventory','badstream',service,'badStream')
registry~registerCallbackMethod('inventory','streamfails',service,'streamFails')
registry~registerCallbackMethod('inventory','faultcallback',service,'faultCallback')
registry~freeze
call check badPath(methods), 'illegal gRPC method path rejected'
call check badSchema(methods), 'unregistered protobuf schema rejected'
methods~registerUnary('/demo.Inventory/Get','inventory','get','grpc.req','grpc.res')
methods~registerUnary('/demo.Inventory/Fail','inventory','fails','grpc.req','grpc.res')
methods~registerUnary('/demo.Inventory/BadReply','inventory','badreply','grpc.req','grpc.res')
methods~registerServerStream('/demo.Inventory/Unfinished','inventory','unfinished','grpc.req','grpc.res')
methods~registerServerStream('/demo.Inventory/BadStream','inventory','badstream','grpc.req','grpc.res')
methods~registerServerStream('/demo.Inventory/StreamFails','inventory','streamfails','grpc.req','grpc.res')
methods~registerServerStream('/demo.Inventory/FaultCallback','inventory','faultcallback','grpc.req','grpc.res')
methods~registerServerStream('/demo.Inventory/Watch','inventory','watch','grpc.req','grpc.res')
call check duplicatePath(methods), 'duplicate external operation rejected'
methods~freeze
call check frozenRegistry(methods), 'published registry immutable'
server=.GrpcRpcBinding~new(methods,.RpcServiceDispatcher~new(registry),framer)
req=.directory~new;req['id']=43
wire=framer~pack(.SerializationSelector~new('grpc.req')~encode(req))
res=server~unary('/demo.Inventory/Get',wire)
call check res~ok & res~frames~items==1, 'unary invokes registered receiver method'
decodedReply=.SerializationSelector~new('grpc.res')~decode(framer~unpackOne(res~frames[1]))
call check decodedReply['id']==44, 'typed protobuf decoded reply'
call check server~unary('/demo.Inventory/Unknown',wire)~status==12, 'missing method UNIMPLEMENTED'
call check server~unary('/demo.Inventory/Watch',wire)~status==12, 'callback cannot be called as unary'
call check server~unary('/demo.Inventory/Get',x2c('0100000000'))~status==3, 'invalid compressed unary request rejected'
call check server~unary('/demo.Inventory/Fail',wire)~status==13, 'implementation errors not disclosed'
call check server~unary('/demo.Inventory/BadReply',wire)~status==13, 'bad response serialization fails closed'
call check server~unary('/demo.Inventory/Get',framer~pack(x2c('0A01FF')))~status==3, 'malformed protobuf request rejected'
call check server~unary('/demo.Inventory/Get',wire||framer~pack(''))~status==3, 'unary rejects second request message'
client=.GrpcUnaryClient~new(.GrpcLoopbackChannel~new(server),framer)
client~bind('inventory.get','/demo.Inventory/Get','grpc.req','grpc.res')
reply=client~request('inventory.get',req)
call check reply~ok & reply~value['id']==44, 'loopback protobuf request/reply client'
reply=client~request('inventory.unknown',req)
call check \reply~ok & reply~status==12, 'unregistered client operation denied'

writer=.FrameWriter~new
res=server~serverStream('/demo.Inventory/Watch',wire,writer)
call check res~ok, 'registered service callback completes'
call check writer~frames~items==3, 'three callback values framed'
a=.SerializationSelector~new('grpc.res')~decode(framer~unpackOne(writer~frames[2]))
call check a['id']==45, 'per-callback protobuf response encoded'
writer=.FrameWriter~new
writer~stopAt(2)
res=server~serverStream('/demo.Inventory/Watch',wire,writer)
call check res~status==14, 'writer rejection terminates stream with UNAVAILABLE'
call check writer~frames~items==1, 'no silent retry of failed stream write'
writer=.FrameWriter~new
writer~throwAt(2)
res=server~serverStream('/demo.Inventory/Watch',wire,writer)
call check res~status==14, 'writer exceptions converted to transport failure'
writer=.FrameWriter~new
writer~cancel
res=server~serverStream('/demo.Inventory/Watch',wire,writer)
call check res~status==1, 'cancelled inbound stream never dispatched'
writer=.FrameWriter~new
res=server~serverStream('/demo.Inventory/Unfinished',wire,writer)
call check res~status==13, 'missing callback completion fails closed'
writer=.FrameWriter~new
res=server~serverStream('/demo.Inventory/BadStream',wire,writer)
call check res~status==13, 'invalid callback protobuf rejected'
writer=.FrameWriter~new
res=server~serverStream('/demo.Inventory/StreamFails',wire,writer)
call check res~status==13 & writer~frames~items==1, 'callback exception after partial output does not report success'
writer=.FrameWriter~new
writer~cancelAfter(1)
res=server~serverStream('/demo.Inventory/Watch',wire,writer)
call check res~status==1 & writer~frames~items==1, 'midstream cancellation returns CANCELLED instead of success'
writer=.FrameWriter~new
res=server~serverStream('/demo.Inventory/FaultCallback',wire,writer)
call check res~status==8, 'registered callback fault mapped to gRPC RESOURCE_EXHAUSTED'
writer=.FrameWriter~new
res=server~serverStream('/demo.Inventory/Get',wire,writer)
call check res~status==12, 'unary cannot be invoked as stream'
res=server~serverStream('/demo.Inventory/Watch',x2c('00000000'),writer)
call check res~status==3, 'malformed streamed request rejected'
trailers=.GrpcCallResult~new(3,'bad arg')~wireTrailers
call check trailers['grpc-status']=='3' & trailers['grpc-message']=='bad%20arg', 'standard grpc-status and percent-encoded trailer'

say 'PASS' checks 'gRPC frame/registration/unary/stream/callback checks'
exit 0
check:
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  checks+=1
return
invalidFrame: procedure
  use strict arg codec, bytes
  signal on syntax name caught
  ignored=codec~unpackOne(bytes)
  signal off syntax
  return .false
caught:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'expected test exception' rc sigl condition("C") condition("D")
  signal off syntax
  return .true
tooLarge: procedure
  use strict arg codec
  signal on syntax name caught
  ignored=codec~pack('x'~copies(1025))
  signal off syntax
  return .false
caught:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'expected test exception' rc sigl condition("C") condition("D")
  signal off syntax
  return .true
badPath: procedure
  use strict arg methods
  signal on syntax name caught
  methods~registerUnary('/demo.Inventory/../Delete','inventory','delete','grpc.req','grpc.res')
  signal off syntax
  return .false
caught:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'expected test exception' rc sigl condition("C") condition("D")
  signal off syntax
  return .true
badSchema: procedure
  use strict arg methods
  signal on syntax name caught
  methods~registerUnary('/demo.Inventory/Bad','inventory','get','missing.schema','grpc.res')
  signal off syntax
  return .false
caught:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'expected test exception' rc sigl condition("C") condition("D")
  signal off syntax
  return .true
duplicatePath: procedure
  use strict arg methods
  signal on syntax name caught
  methods~registerUnary('/demo.Inventory/Get','inventory','get','grpc.req','grpc.res')
  signal off syntax
  return .false
caught:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'expected test exception' rc sigl condition("C") condition("D")
  signal off syntax
  return .true
frozenRegistry: procedure
  use strict arg methods
  signal on syntax name caught
  methods~registerUnary('/demo.Inventory/New','inventory','get','grpc.req','grpc.res')
  signal off syntax
  return .false
caught:
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then say 'expected test exception' rc sigl condition("C") condition("D")
  signal off syntax
  return .true
::class SampleService
::method lookup
  use strict arg arguments,ctx
  out=.directory~new
  out['id']=arguments['id']+1
  return out
::method observe
  use strict arg arguments,ctx,sink
  do i=1 to 3
    if sink~isCancelled then leave
    itemData=.directory~new
    itemData['id']=arguments['id']+i
    if \sink~onNext(itemData) then leave
  end
  sink~onComplete
  return 'done'
::method explode
  raise syntax 93.900 additional('SECRET FAILURE')
::method invalidReply
  return 'not a protobuf message directory'
::method unfinished
  use strict arg arguments,ctx,sink
  record=.directory~new;record['id']=1
  sink~onNext(record)
  return 'no completion'
::method badStream
  use strict arg arguments,ctx,sink
  sink~onNext('not protobuf')
  return 'bad codec'
::method streamFails
  use strict arg arguments,ctx,sink
  record=.directory~new;record['id']=1
  sink~onNext(record)
  raise syntax 93.900 additional('SERVICE PRIVATE FAILURE')
::method faultCallback
  use strict arg arguments,ctx,sink
  sink~onFault(.RpcServiceFault~new('RESOURCE_EXHAUSTED','Private service detail'))
  return 'failure reported'
::class FrameWriter
::attribute frames get
::method init
  expose frames rejected at throwing cancelled cancelAfterCount
  frames=.array~new
  rejected=.false
  at=9999
  throwing=9999
  cancelled=.false
  cancelAfterCount=9999
::method write
  expose frames at rejected throwing cancelled cancelAfterCount
  use strict arg frame
  if frames~items+1>=throwing then raise syntax 93.900 additional('Broken output writer')
  if frames~items+1>=at then do; rejected=.true; return .false; end
  frames~append(frame)
  if frames~items>=cancelAfterCount then cancelled=.true
  return .true
::method stopAt
  expose at
  use strict arg at
::method throwAt
  expose throwing
  use strict arg throwing
::method cancelAfter
  expose cancelAfterCount
  use strict arg cancelAfterCount
::method cancel
  expose cancelled
  cancelled=.true
::method isCancelled
  expose cancelled
  return cancelled
::requires 'Protobuf.cls'
::requires 'GrpcRpcBinding.cls'
