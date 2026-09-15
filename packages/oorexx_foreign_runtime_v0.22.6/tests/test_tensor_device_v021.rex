failures=0
probe=.foreign~load('tensor-native.bridge.json')
id=probe~fake_device_new
call check id>0,'synthetic device tensor imported through v2'
call check probe~v2_device_type(id)=2,'v2 carries CUDA device type'
call check probe~v2_stream(id)=4369,'v2 carries opaque stream handle'
call check probe~v2_fence(id)=8738,'v2 carries opaque fence handle'
call check probe~v2_sync_policy(id)=1,'v2 carries stream-ordered policy'
call check probe~v2_affinity(id)=2,'v2 carries context affinity'
call check probe~v2_provider_ok(id)=1,'v2 carries provider identity'
call check probe~v2_cpu_deref_allowed(id)=0,'generic CPU consumer rejects device tensor dereference'
ignored=probe~v2_probe_reset
w=.DeviceTensorWorker~new(probe)
m=w~start('hold',id,120)
do while probe~v2_probe_is_started=0; call SysSleep .001; end
start=time('E'); ignored=probe~v2_close(id); elapsed=time('E')-start
m~result
call check elapsed>=.05,'device tensor close waits for active v2 descriptor pin'
probe~close
if failures=0 then do; say 'PASS device-aware tensor descriptor v2 9 assertions'; exit 0; end
say 'FAIL device tensor assertions='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
::class DeviceTensorWorker
::method init; expose _probe; use strict arg _probe
::method hold; expose _probe; use strict arg id,millis; return _probe~v2_delayed_context(id,millis)
::requires '../rexx/foreign.cls'
