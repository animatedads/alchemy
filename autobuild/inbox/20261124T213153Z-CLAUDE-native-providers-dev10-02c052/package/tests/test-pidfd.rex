/* Architecture: Tom Dyer. Coding: ChatGPT. Only signal a child created here. */
pr = .ProcessProvider~new
pid = SysQueryProcess('PID')
p = pr~observe(pid)
r = pr~openProcessHandle(p)
if \r['OK'] then do; say 'FAIL self pidfd' r['ERRNO'] r['ERROR']; exit 1; end
h = r['PROCESS_HANDLE']
call check r['PID'] = pid & r['START_TICKS'] == p~identity~substr(p~identity~lastPos(':')+1), 'pidfd observed identity'
w = h~waitExit
call check w['OK'] & \w['EXITED'] & \w['TIMED_OUT'], 'pidfd live nonblocking probe'
w = h~waitExit(20)
call check w['OK'] & \w['EXITED'] & w['TIMED_OUT'], 'pidfd bounded wait timeout'
call check \h~waitExit(5001)['OK'], 'pidfd excessive wait rejected'
call check h~signal(0)['ACCEPTED'], 'pidfd kernel permission probe'
call check \h~signal(123)['OK'], 'pidfd unapproved signal rejected'
call check \ShellProcessHandleOpen(pid,'0')['OK'], 'pidfd stale start ticks rejected'
call check \ShellProcessHandleOpen(0,'0')['OK'], 'pidfd zero PID rejected'
call check \ShellProcessHandleOpen(pid,'invalid')['OK'], 'pidfd malformed ticks rejected'
call check \ .POSIXProcessHandle~new('1')~waitExit['OK'], 'pidfd guessed handle rejected'
call check h~close['OK'], 'pidfd explicit close'
call check \h~waitExit['OK'] & \h~signal(0)['OK'], 'pidfd closed handle invalid'
-- Child has no access to application data; /bin/sleep only.
runner = .ProcessRunner~new(pr)
spec = .ProcessSpec~new(.Array~of('/bin/sleep','10'))
spec~detach = .true
spec~stdoutPolicy = "DISCARD"
spec~stderrPolicy = "DISCARD"
child = runner~run(spec)
if \child~started then say child~errorStage child~errorMessage
call check child~started, 'pidfd disposable child started'
cp = pr~observe(child~pid)
call check cp \== .nil, 'pidfd child observed'
r = pr~openProcessHandle(cp)
call check r['OK'], 'pidfd child bound'
h = r['PROCESS_HANDLE']
call check \h~waitExit['EXITED'], 'pidfd child still running'
s = h~signal(15)
call check s['OK'] & s['ACCEPTED'] & s['SIGNAL'] = 15, 'pidfd child TERM accepted'
w = h~waitExit(5000)
call check w['OK'] & w['EXITED'] & \w['TIMED_OUT'], 'pidfd child exit observed'
outcome = pr~reap(child~pid)
call check outcome~termination == 'SIGNAL' & outcome~termSignal = 15, 'existing runner reaps child signal outcome'
call check h~waitExit['EXITED'], 'pidfd stays exited after reap'
call check \h~signal(0)['OK'], 'pidfd cannot signal reaped process'
call check \h~signal(15)['OK'], 'pidfd nonzero signal after reap refused'
h~uninit
call check \h~waitExit['OK'], 'pidfd uninit closes'
-- Test fixed registry without relying on GC scheduling.
a = .Array~new
 do i = 1 to 128
  r = pr~openProcessHandle(p)
  if \r['OK'] then do; say 'FAIL pidfd registry early' i r['ERROR']; exit 1; end
  a~append(r['PROCESS_HANDLE'])
 end
r = pr~openProcessHandle(p)
call check \r['OK'] & r['ERRNO'] = 0 & r['ERROR']~pos('PROCESS_REGISTRY_FULL') = 1, 'pidfd distinct registry exhaustion'
do h over a; h~close; end
r = pr~openProcessHandle(p)
call check r['OK'], 'pidfd registry capacity recovered'
r['PROCESS_HANDLE']~close
say 'PIDFD SUITE PASSED'
exit 0
check:
  use arg ok, label
  if \ok then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return
::requires 'ProcessProvider.cls'
::requires 'Process.cls'
::requires 'POSIXProvider.cls'
