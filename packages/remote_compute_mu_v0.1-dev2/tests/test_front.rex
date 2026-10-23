/* Native envelope qualification only; no live provider allocation. */

x = .directory~new
x['jobId']='job_1'
x['backend']='colab'
x['workload']=.directory~new
x['inputRef']='storage:in'
x['outputRef']='storage:out'
x['lease']=.directory~new
x['entitlement']=.directory~new
intent=.RemoteComputeMUIntent~new(x)
call assert intent~verify = 'OK', 'valid intent'
front=.RemoteComputeMUFront~new
call assert front~dispatch(intent) = 'NO_CONTROLLER_BOUND', 'default must be disabled'
call assert front~refresh('job_1') = 'NO_CONTROLLER_BOUND', 'unbound refresh'
call assert front~cancel('job_1') = 'NO_CONTROLLER_BOUND', 'unbound cancel'
call assert front~reconcile('job_1') = 'NO_CONTROLLER_BOUND', 'unbound recovery'
x['backend']='unknown'
call assert intent~verify = 'UNSUPPORTED_BACKEND', 'unknown backend'
x['backend']='colab'
x~remove('entitlement')
call assert intent~verify = 'MISSING_entitlement', 'missing authority envelope'
say 'PASS ooRexx remote compute semantic frontage'
exit 0

::routine assert
  use strict arg condition, message
  if \condition then do
    say 'FAIL:' message
    raise user message
  end

::requires 'RemoteComputeMUFront.cls'
