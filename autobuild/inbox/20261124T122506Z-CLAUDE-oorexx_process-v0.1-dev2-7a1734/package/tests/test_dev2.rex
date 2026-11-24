/* test_dev2.rex -- oorexx_process dev2: descriptor stdio, detach, reap, signal,
 * and no inherited descriptors in the child.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 24 November 2026.
 * Needs oorexx_unix_socket v0.6 (unixsocket.cls) on REXX_PATH for the socketpair. */
r = .ProcessRunner~new
call assertTrue r~capabilities~hasItem('process.stdio.descriptor'), 'capability: descriptor stdio'

/* 1. A child talks over one end of a socketpair: /bin/cat echoes what we send. */
pair = .UnixSocket~socketPair('SOCK_STREAM')
left = pair[1]; right = pair[2]
s = .ProcessSpec~new(.array~of('/bin/cat'))
s~stdinDescriptor = right~fd
s~stdoutPolicy = 'DESCRIPTOR'
s~stdoutDescriptor = right~fd
s~stderrPolicy = 'DISCARD'
s~detach = .true
x = r~run(s)
call assertTrue x~started & x~termination == 'RUNNING' & x~pid > 0, 'detached start returns at once with a pid'
right~close                                   /* the child holds its own copy */
payload = 'hello' || '00'x || 'world' || '0a'x
call assertTrue left~sendAll(payload) = payload~length, 'send to the child'
got = ''
do 50 while got~length < payload~length
  chunk = left~recv(64)
  if chunk == .nil | chunk == '' then leave
  got = got || chunk
end
call assertTrue got == payload, 'the child echoed binary bytes over the descriptor'
left~shutdown(1)                              /* SHUT_WR */
rest = left~recv(64)
call assertTrue rest == '', 'end of file once the child exits'
left~close
call assertTrue waitFor(r, x~pid)~termination == 'EXIT', 'reap: EXIT'

/* 2. No inherited descriptors: the child sees only 0, 1, 2 (ls adds its own directory fd). */
keep = .stream~new('/tmp/oorexx_process_dev2_probe.txt'); keep~open('write replace')
s = .ProcessSpec~new(.array~of('/bin/ls', '/proc/self/fd'))
x = r~run(s)
keep~close
fds = x~stdout~makeArray
call assertTrue x~succeeded & fds~items <= 4, 'child holds at most 0, 1, 2 and ls''s own fd (saw' fds~items')'

/* 3. A detached exec that fails is a start failure, not a running child. */
s = .ProcessSpec~new(.array~of('/nonexistent/program'))
s~stdoutPolicy = 'DISCARD'; s~stderrPolicy = 'DISCARD'; s~detach = .true
x = r~run(s)
call assertTrue x~failedToStart & x~errorStage == 'EXEC', 'detached exec failure is reported'

/* 4. Contradictions fail closed. */
s = .ProcessSpec~new(.array~of('/bin/true')); s~detach = .true
x = r~run(s)
call assertTrue x~failedToStart & x~errorStage == 'DETACH_CONFLICT', 'detach with capture is refused'
s = .ProcessSpec~new(.array~of('/bin/true')); s~stdinDescriptor = 987654
x = r~run(s)
call assertTrue x~failedToStart & x~errorStage == 'STDIN_FD', 'a closed descriptor is refused'
s = .ProcessSpec~new(.array~of('/bin/true')); s~stdoutPolicy = 'DESCRIPTOR'
x = r~run(s)
call assertTrue x~failedToStart & x~errorStage == 'STDOUT_FD', 'DESCRIPTOR without a descriptor is refused'

/* 5. signal and reap a detached child */
s = .ProcessSpec~new(.array~of('/bin/sleep', '30'))
s~stdoutPolicy = 'DISCARD'; s~stderrPolicy = 'DISCARD'; s~detach = .true; s~processGroup = .true
x = r~run(s)
call assertTrue r~reap(x~pid)~termination == 'RUNNING', 'reap of a live child says RUNNING'
call assertTrue r~signal(x~pid, 15, .true) = 0, 'signal the process group'
y = waitFor(r, x~pid)
call assertTrue y~termination == 'SIGNAL' & y~termSignal = 15, 'reap after SIGTERM: SIGNAL 15'
call assertTrue r~reap(x~pid)~termination == 'GONE', 'a reaped child is GONE'

say 'PASS test_dev2: descriptor stdio, detach, reap, signal, no inherited descriptors'
exit 0

waitFor: procedure
  use arg runner, pid
  do 200
    res = runner~reap(pid)
    if res~termination \== 'RUNNING' then return res
    call SysSleep 0.05
  end
  return res

assertTrue:
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 2
  end
  return

::requires 'Process.cls'
::requires 'unixsocket.cls'
