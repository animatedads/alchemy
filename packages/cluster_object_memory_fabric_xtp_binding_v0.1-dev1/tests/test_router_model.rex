/* Semantic test for the route guard. Requires the package dependencies to be
 * on REXX_PATH. This test deliberately uses a fake final cluster client; it
 * does not claim XTP field transport. */
assertions=0
providers=.array~of('P-B')
fakeClient=.FakeClusterClient~new
route=.ClusterObjectXtpRoute~new('NODE-B','MU-B','queue.object.cluster','QM.A','QM.B','B.OBJECT','A.TO.B','OBJECT.REPLY.A','object-client',providers,fakeClient,.FakeThing~new,.FakeThing~new,.FakeThing~new)
router=.ClusterObjectXtpRouterTransport~new(.ClusterObjectXtpStaticReadiness~new(.true))
call assert router~registerRoute(route), 'register route'
req=.ClusterObjectCodec~newRequest('r1','NODE-A','NODE-B',.ClusterObjectOperation~MOVE)
target=.directory~new
target['provider_id']='P-B'
req['memory_target']=target
ans=router~request('NODE-B',req)
call assert ans<>.nil, 'matching provider delegates'
call assert fakeClient~calls=1, 'one delegate call'
wrong=.ClusterObjectCodec~newRequest('r2','NODE-A','NODE-B',.ClusterObjectOperation~MOVE)
wrongTarget=.directory~new
wrongTarget['provider_id']='P-C'
wrong['memory_target']=wrongTarget
ans=router~request('NODE-B',wrong)
call assert ans==.nil, 'wrong provider refused'
call assert router~lastFailure='MEMORY_PROVIDER_ROUTE_MISMATCH', 'wrong provider reason'
deny=.ClusterObjectXtpRouterTransport~new
call assert deny~registerRoute(route), 'register route on default deny router'
ans=deny~request('NODE-B',req)
call assert ans==.nil, 'default readiness refuses'
call assert deny~lastFailure='XTP_ROUTE_NOT_READY', 'default readiness reason'
if assertions<>7 then do
  say 'FAIL assertion count' assertions
  exit 1
end
say 'PASS ClusterObjectXtpRouterTransport' assertions
exit 0
assert: procedure expose assertions
  use strict arg condition,label
  assertions+=1
  if \condition then do
    say 'FAIL' label
    exit 1
  end
  return
::class FakeClusterClient public
::attribute calls get
::method init
  expose calls
  calls=0
::method request
  expose calls
  use strict arg peer,request
  calls+=1
  d=.directory~new
  d['ok']=.true
  return d
::class FakeThing public
