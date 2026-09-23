/* argv must survive without shell quoting or expansion. */
r = .ProcessRunner~new
arg = 'a b' || '09'x || '$HOME;*' || '0a'x || 'tail'
s = .ProcessSpec~new(.array~of('/usr/bin/python3', '-c', 'import sys;sys.stdout.buffer.write(sys.argv[1].encode())', arg))
x = r~run(s)
call assertTrue x~started & x~exitCode = 0, 'argv execution'
call assertTrue x~stdout == arg, 'argv exact'

/* stdin and binary strings. */
payload = 'A' || '00'x || 'B' || '0a'x
s = .ProcessSpec~new(.array~of('/usr/bin/python3', '-c', 'import sys;sys.stdout.buffer.write(sys.stdin.buffer.read())'))
s~stdinBytes = payload
x = r~run(s)
call assertTrue x~started & x~exitCode = 0, 'stdin execution'
call assertTrue x~stdout == payload, 'stdin exact'

/* non-zero exit is a process result, not provider failure. */
s = .ProcessSpec~new(.array~of('/usr/bin/python3', '-c', 'import sys;sys.exit(7)'))
x = r~run(s)
call assertTrue x~started, 'nonzero started'
call assertTrue x~termination == 'EXIT' & x~exitCode = 7, 'nonzero exit result'
call assertTrue \x~succeeded, 'nonzero not success'

/* bounded capture drains the pipe while retaining only the configured bound. */
s = .ProcessSpec~new(.array~of('/usr/bin/python3', '-c', 'import sys;sys.stdout.write("A"*100000)'))
s~maxOutputBytes = 17
x = r~run(s)
call assertTrue x~started & x~exitCode = 0, 'bounded execution'
call assertTrue length(x~stdout) = 17, 'bounded retained length'
call assertTrue x~outputTruncated, 'bounded truncated evidence'

/* timeout terminates the child and is a first-class result. */
s = .ProcessSpec~new(.array~of('/usr/bin/python3', '-c', 'import time;time.sleep(5)'))
s~timeoutMs = 100
x = r~run(s)
call assertTrue x~started, 'timeout started'
call assertTrue x~timedOut & x~termination == 'TIMEOUT', 'timeout classification'
call assertTrue x~durationMs < 2000, 'timeout bounded'

/* dev1 refuses unsupported higher contracts rather than silently weakening them. */
s = .ProcessSpec~new(.array~of('/bin/true'))
s~environment['TEST_ONLY'] = '1'
x = r~run(s)
call assertTrue x~failedToStart & x~errorStage == 'ENVIRONMENT', 'environment fail closed'

say 'PASS test_contract'
exit 0

assertTrue:
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 2
  end
  return

::requires 'Process.cls'
