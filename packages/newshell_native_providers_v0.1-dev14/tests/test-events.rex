/* Architecture: Tom Dyer. Coding: ChatGPT. Disposable fixture only. */
parse arg path
p = .POSIXProvider~new
mux = p~eventMux
call check p~capabilities~hasItem('event.epoll') & p~capabilities~hasItem('event.timerfd'), 'event capabilities'
call check \p~timer(0)['OK'] & \p~timer(86400001)['OK'], 'timer bounds'
root = p~openRoot(path)['ROOT']
w = root~watch('eventdir')['WATCH']
t = p~timer(60000)['TIMER']
r = mux~wait(.Array~of(w,t),10)
call check r['OK'] & r['TIMED_OUT'] & r['EVENTS']~items=0, 'mux empty bounded wait'
call check t~drain['EXPIRATIONS']=0, 'timer not yet expired'
call check \mux~wait(.Array~of(w,t),5001)['OK'], 'mux wait bound'
call check \mux~wait(.Array~of(w,w))['OK'], 'mux duplicate source rejected'
s = .Stream~new(path'/eventdir/a'); s~charOut('abc'); s~close
r = mux~wait(.Array~of(w,t),100)
call check r['OK'] & ready(r,1,'FILESYSTEM'), 'mux filesystem ready'
r = w~nextBatch(1)
call check r['OK'] & r['EVENTS']~items=1, 'mux watch first partial drain'
r = mux~wait(.Array~of(w),0)
call check ready(r,1,'FILESYSTEM'), 'mux buffered watch readiness'
do i=1 to 32
 r=w~nextBatch(128)
 if r['DRAINED'] then leave
end
call check r['DRAINED'] & mux~wait(.Array~of(w))['EVENTS']~items=0, 'mux fully drained watch'
t~close
t=p~timer(20)['TIMER']
r=mux~wait(.Array~of(w,t),2000)
call check ready(r,2,'TIMER'), 'mux one shot timer ready'
call check t~drain['EXPIRATIONS']=1, 'timer one shot exact count'
call check t~drain['EXPIRATIONS']=0 & mux~wait(.Array~of(t))['EVENTS']~items=0, 'timer drained and disarmed'
t~close
r=mux~wait(.Array~of(t),1000)
call check r['OK'] & r['EVENTS'][1]['CLOSED'] & \r['EVENTS'][1]['READY'], 'mux closed source reported'
t=p~timer(5,5)['TIMER']
call SysSleep 0.08
r=mux~wait(.Array~of(t))
call check ready(r,1,'TIMER') & t~drain['EXPIRATIONS']>=2, 'periodic timer accumulates expirations'
t~uninit
call check \t~drain['OK'], 'timer uninit closes'
pr=.ProcessProvider~new
runner=.ProcessRunner~new(pr)
spec=.ProcessSpec~new(.Array~of('/bin/sleep','10'))
spec~detach=.true; spec~stdoutPolicy='DISCARD'; spec~stderrPolicy='DISCARD'
child=runner~run(spec)
if \child~started then exit 2
h=pr~openProcessHandle(pr~observe(child~pid))['PROCESS_HANDLE']
if h==.nil then exit 2
t=p~timer(20)['TIMER']
r=mux~wait(.Array~of(w,h,t),1000)
call check ready(r,3,'TIMER') & \ready(r,2,'PROCESS'), 'mux mixed sources timer first'
t~drain
h~signal(15)
r=mux~wait(.Array~of(w,h,t),5000)
call check ready(r,2,'PROCESS'), 'mux actual child exit'
reaped=pr~reap(child~pid)
call check reaped~termination='SIGNAL' & reaped~termSignal=15, 'mux child reaped by existing runner'
call check ready(mux~wait(.Array~of(h)),1,'PROCESS'), 'mux process exit level triggered'
s=.Stream~new(path'/eventdir/b');s~charOut('x');s~close
r=mux~wait(.Array~of(w,h,t))
call check ready(r,1,'FILESYSTEM') & ready(r,2,'PROCESS'), 'mux simultaneous watch and process readiness'
root~close
r=mux~wait(.Array~of(w,h,t))
call check r['EVENTS'][1]['CLOSED'] & ready(r,2,'PROCESS'), 'mux root closure invalidates watch only'
h~close;t~close
r=mux~wait(.Array~of(h,t))
call check r['OK'] & r['EVENTS']~items=2 & r['EVENTS'][1]['CLOSED'] & r['EVENTS'][2]['CLOSED'], 'mux multiple closed sources reported'
-- A watch may retain rescan state after its kernel queue has drained.
root=p~openRoot(path)['ROOT']
w=root~watch('eventdir')['WATCH']
'mv --' path'/eventdir' path'/eventmoved'
if rc<>0 then exit 2
r=w~nextBatch(128)
call check r['DRAINED'] & r['RESCAN_REQUIRED'], 'mux invalidated watch drained'
call check ready(mux~wait(.Array~of(w)),1,'FILESYSTEM'), 'mux sticky invalidation stays ready'
w~close;root~close
call check \ .POSIXTimer~new('1')~drain['OK'], 'timer guessed handle refused'
-- Registry exhaustion, independent of OS descriptor limit.
a=.Array~new
do i=1 to 128
 r=p~timer(60000)
 if \r['OK'] then exit 2
 a~append(r['TIMER'])
end
r=p~timer(60000)
call check \r['OK'] & r['ERRNO']=0 & r['ERROR']~pos('TIMER_REGISTRY_FULL')=1, 'timer registry exhaustion distinguished'
do t over a; t~close; end
r=p~timer(60000)
call check r['OK'], 'timer registry capacity recovered'
r['TIMER']~close
say 'EVENT SUITE PASSED'
exit 0
ready: procedure
 use arg r,index,kind
 do e over r['EVENTS']
   if e['INDEX']=index & e['KIND']=kind & e['READY'] then return .true
 end
 return .false
check:
 use arg ok,label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label
 return
::requires 'POSIXProvider.cls'
::requires 'ProcessProvider.cls'
::requires 'Process.cls'
