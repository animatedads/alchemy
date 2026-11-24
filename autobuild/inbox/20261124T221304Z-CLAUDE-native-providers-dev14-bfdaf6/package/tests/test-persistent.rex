/* Architecture: Tom Dyer. Coding: ChatGPT. Disposable fixture. */
parse arg path
p=.POSIXProvider~new
m=p~openEventMux['MUX']
call check p~capabilities~hasItem('event.eventfd') & p~capabilities~hasItem('event.epoll.persistent'), 'persistent capabilities'
call check m~wait(10)['TIMED_OUT'], 'persistent empty timeout'
call check m~wake['OK'], 'persistent explicit wake'
r=m~wait(1000)
call check r['WOKEN'] & \r['TIMED_OUT'], 'persistent preposted wake retained'
call check m~wait(10)['TIMED_OUT'], 'persistent wake drained'
t=p~timer(30)['TIMER']
a=m~register(t)['REGISTRATION']
call check a>0 & \m~register(t)['OK'], 'persistent unique registration'
r=m~wait(1000)
call check found(r,a,'TIMER','READY'), 'persistent timer ready'
call check found(m~wait,a,'TIMER','READY'), 'persistent timer stays ready'
t~drain
call check m~wait(10)['TIMED_OUT'], 'persistent drained timer idle'
root=p~openRoot(path)['ROOT']; w=root~watch('persistentdir')['WATCH']; b=m~register(w)['REGISTRATION']
s=.Stream~new(path'/persistentdir/a');s~charOut('x');s~close
call check found(m~wait(1000),b,'FILESYSTEM','READY'), 'persistent filesystem ready'
w~nextBatch(1)
call check found(m~wait,b,'FILESYSTEM','READY'), 'persistent buffered watch ready'
do i=1 to 32
 r=w~nextBatch(128);if r['DRAINED'] then leave
end
call check r['DRAINED'] & m~wait(10)['TIMED_OUT'], 'persistent fully drained watch idle'
root~close
call check found(m~wait(1000),b,'FILESYSTEM','CLOSED'), 'persistent root closes registered watch'
call check m~wait(10)['TIMED_OUT'] & \m~unregister(b)['OK'], 'persistent closed source reported once'
call check m~unregister(a)['OK'] & \m~unregister(a)['OK'], 'persistent unregister'
t~close
call check m~wait(10)['TIMED_OUT'], 'persistent removed source closure ignored'
pr=.ProcessProvider~new
runner=.ProcessRunner~new(pr)
spec=.ProcessSpec~new(.Array~of('/bin/sleep','10'))
spec~detach=.true;spec~stdoutPolicy='DISCARD';spec~stderrPolicy='DISCARD'
child=runner~run(spec)
if \child~started then exit 2
h=pr~openProcessHandle(pr~observe(child~pid))['PROCESS_HANDLE']
if h==.nil then exit 2
a=m~register(h)['REGISTRATION']
h~signal(15)
call check found(m~wait(5000),a,'PROCESS','READY'), 'persistent process exit ready'
reaped=pr~reap(child~pid)
call check reaped~termination='SIGNAL' & reaped~termSignal=15, 'persistent process reaped'
h~close
call check found(m~wait,a,'PROCESS','CLOSED'), 'persistent process handle closure'

-- Native wait must not hold the Rexx object guard; run concurrent activity.
msg=.Message~new(m,'WAIT','A',.Array~of(3000))
msg~start
call SysSleep 0.15
call check \m~wait(0)['OK'], 'persistent second waiter refused'
call check m~wake['OK'], 'persistent concurrent wake accepted'
r=msg~result
call check r['WOKEN'] & \r['TIMED_OUT'], 'persistent concurrent waiter woken'
t=p~timer(60000)['TIMER'];a=m~register(t)['REGISTRATION']
msg=.Message~new(m,'WAIT','A',.Array~of(3000));msg~start
call SysSleep 0.15
t~close
r=msg~result
call check found(r,a,'TIMER','CLOSED') & \r['TIMED_OUT'], 'persistent concurrent source closure wakes'
t=p~timer(60000)['TIMER'];a=m~register(t)['REGISTRATION']
msg=.Message~new(m,'WAIT','A',.Array~of(3000));msg~start
call SysSleep 0.15
m~unregister(a)
r=msg~result
call check r['CHANGED'] & \r['TIMED_OUT'], 'persistent concurrent unregister wakes'
t~close
msg=.Message~new(m,'WAIT','A',.Array~of(3000));msg~start
call SysSleep 0.15
t=p~timer(60000)['TIMER'];a=m~register(t)['REGISTRATION']
r=msg~result
call check r['CHANGED'] & \r['TIMED_OUT'], 'persistent concurrent registration wakes'
m~unregister(a);t~close
msg=.Message~new(m,'WAIT','A',.Array~of(3000));msg~start
call SysSleep 0.15
m~close
r=msg~result
call check r['CLOSED'] & \r['TIMED_OUT'], 'persistent concurrent mux close wakes'
call check \m~wait['OK'] & \m~wake['OK'], 'persistent closed mux refused'
-- Closed registrations are tombstones until collected or explicitly removed.
m=p~openEventMux['MUX'];t=p~timer(60000)['TIMER'];a=m~register(t)['REGISTRATION'];t~close
call check m~unregister(a)['OK'] & m~wait(20)['TIMED_OUT'], 'persistent removed tombstone leaves no stale wake'
list=.Array~new
do i=1 to 128
 t=p~timer(60000)['TIMER'];list~append(t)
 r=m~register(t);if \r['OK'] then exit 2
end
r=m~register(list[1])
call check \r['OK'] & r['ERROR']~pos('MUX_SOURCE_REGISTRY_FULL')=1, 'persistent source registry limit'
do t over list;t~close;end
r=m~wait(0)
call check r['EVENTS']~items=128, 'persistent all closed registrations returned'
closed=0;do e over r['EVENTS'];closed=closed+e['CLOSED'];end
call check closed=128 & m~wait(0)['EVENTS']~items=0, 'persistent all closed registrations reclaimed'
t=p~timer(60000)['TIMER'];r=m~register(t)
call check r['OK'], 'persistent source registry capacity recovered'
m~close;t~close
-- Bounded mux registry.
list=.Array~new
do i=1 to 32
 r=p~openEventMux;if \r['OK'] then exit 2
 list~append(r['MUX'])
end
r=p~openEventMux
call check \r['OK'] & r['ERROR']~pos('MUX_REGISTRY_FULL')=1, 'persistent mux registry limit'
do m over list;m~close;end
r=p~openEventMux
call check r['OK'], 'persistent mux registry reclaimed'
r['MUX']~uninit
call check \r['MUX']~wait['OK'], 'persistent mux uninit closes'
say 'PERSISTENT SUITE PASSED'
exit 0
found: procedure
 use arg r,id,kind,field
 do e over r['EVENTS']
  if e['REGISTRATION']=id & e['KIND']=kind & e[field] then return .true
 end
 return .false
check:
 use arg ok,label
 if \ok then do;say 'FAIL' label;exit 1;end
 say 'PASS' label
 return
::requires 'POSIXProvider.cls'
::requires 'ProcessProvider.cls'
::requires 'Process.cls'
