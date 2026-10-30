/* Native ingress qualification with injected policy and inert fake controller.
 * No outbound traffic or credentials consumed. */
x = .Directory~new
x['jobId']='job_1'
x['backend']='colab'
x['workload']=.Directory~new
x['inputRef']='storage:in'
x['outputRef']='storage:out'
x['lease']=.Directory~new
x['entitlement']=.Directory~new

e = .Directory~new
e['requestId']='req_1'
e['service']='compute.remote/0.1'
e['operation']='DISPATCH'
e['jobId']='job_1'
e['intent']=x
p=.TestMeshPolicy~new
c=.TestMeshController~new
f=.RemoteComputeMUFront~new(c)
s=.RemoteComputeMUMeshService~new(f,p)
call check s~handle(e)~at('outcome')='UNAUTHENTICATED', 'no transport context'
call check c~calls=0, 'must not dispatch without context'
ctx=.Directory~new
ctx['principal']='mi.TEST'
ctx['epoch']='current'
call check s~handle(e,ctx)~at('outcome')='ACCEPTED', 'authorized dispatch'
call check c~calls=1, 'exactly once called'
p~allow=.false
call check s~handle(e,ctx)~at('outcome')='NOT_AUTHORIZED', 'policy denial'
call check c~calls=1, 'no dispatch when policy denies'
p~allow=.true
ctx['epoch']='stale'
call check s~handle(e,ctx)~at('outcome')='NOT_AUTHORIZED', 'stale epoch'
ctx['epoch']='current'
e['jobId']='job_2'
call check s~handle(e,ctx)~at('outcome')='INTENT_ID_MISMATCH', 'mismatched id'
e['jobId']='job_1'
e['service']='ssh.management'
call check s~handle(e,ctx)~at('outcome')='SERVICE_NOT_FOUND', 'service isolation'
e['service']='compute.remote/0.1'
e['operation']='STATUS'
call check s~handle(e)~at('outcome')='UNAUTHENTICATED', 'status requires auth'
call check s~handle(e,ctx)~at('outcome')='ACCEPTED', 'authorized status'
call check c~last='STATUS', 'status routes'
e['operation']='CANCEL'
call check s~handle(e,ctx)~at('outcome')='ACCEPTED', 'authorized cancel'
call check c~last='CANCEL', 'cancel routes'
e['operation']='RECOVER'
call check s~handle(e,ctx)~at('outcome')='ACCEPTED', 'authorized recover'
call check c~last='RECOVER', 'recover routes'
e['jobId']='../../escape'
call check s~handle(e,ctx)~at('outcome')='BAD_JOB_ID', 'path traversal blocked'
call check c~calls=4, 'no surprise calls'
say 'PASS native Remote Compute MU mesh ingress (12 checks)'
exit 0

::routine check
  use strict arg ok, msg
  if \ok then do
    say 'FAIL' msg
    raise user msg
  end

::class TestMeshPolicy
::attribute allow
::method init
  expose allow
  allow=.true
::method admit
  expose allow
  use strict arg ctx, service, op, jobId, rid
  if \allow then return 'DENY'
  if \ctx~isA(.Directory) then return 'DENY'
  if ctx~at('epoch') \== 'current' then return 'DENY'
  if ctx~at('principal') \== 'mi.TEST' then return 'DENY'
  return 'ALLOW'

::class TestMeshController
::attribute calls
::attribute last
::method init
  expose calls last
  calls=0
  last=''
::method dispatch
  expose calls last
  use strict arg intent
  calls=calls+1
  last='DISPATCH'
  return 'submitted'
::method refresh
  expose calls last
  use strict arg jobId
  calls=calls+1
  last='STATUS'
  return 'running'
::method cancel
  expose calls last
  use strict arg jobId
  calls=calls+1
  last='CANCEL'
  return 'cancel-requested'
::method recover
  expose calls last
  use strict arg jobId
  calls=calls+1
  last='RECOVER'
  return 'uncertain'

::requires 'RemoteComputeMUMeshService.cls'
