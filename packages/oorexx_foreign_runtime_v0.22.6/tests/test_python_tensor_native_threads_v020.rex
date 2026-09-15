failures=0
np=.ForeignPython~import('numpy')
kw=.ForeignPython~keywords; kw~put('dtype','uint8')
arr=np~arange(8,kw)
t=arr~asTensor
probe=.foreign~load('tensor-native.bridge.json')
ignored=probe~probe_reset
w=.TensorWorker~new(probe)
m=w~start('delayed',t~nativeHandle,120)
do while probe~probe_started=0
  call SysSleep .001
end
start=time('E')
t~close
elapsed=time('E')-start
m~result
call check elapsed>=.05,'ForeignTensor close waits for native descriptor pin'
call check m~result=28,'native pinned tensor remained readable during close'
arr~close; probe~close; np~close
if failures=0 then do; say 'PASS native tensor pinning 2 assertions'; exit 0; end
say 'FAIL native tensor pinning failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
::class TensorWorker
::method init; expose p; use strict arg p
::method delayed unguarded; expose p; use strict arg h,ms; return p~delayed_sum(h,ms)
::requires '../rexx/python_foreign.cls'
