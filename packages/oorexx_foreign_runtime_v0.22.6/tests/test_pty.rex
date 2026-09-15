/* Real POSIX PTY + pollfd[] conformance for Foreign Runtime v0.14. */
pty=.foreign~load('pty.bridge.json')
ri=.foreign~runtimeInfo
if ri~maxArity<>0 then do
  say 'SKIP PTY requires runtime libffi dynamic arity'
  exit 0
end
r=pty~openpty(.foreign~out,.foreign~out,.nil,.nil,.nil)
if r~returnValue<>0 then do
  say 'FAIL openpty errno='r~errno r~errorMessage
  exit 1
end
master=r~out('master'); slave=r~out('slave')
if \master~isA(.ForeignHandle) | \slave~isA(.ForeignHandle) then do
  say 'FAIL openpty did not return ForeignHandle resources'
  exit 2
end
if master~type<>'POSIX_FD' | slave~type<>'POSIX_FD' then do
  say 'FAIL PTY resource semantic type'
  exit 3
end
rawMaster=master~value
payload='00610062ff00010203'x
wr=pty~write(slave,payload,payload~length)
if wr~returnValue<>payload~length then do
  say 'FAIL PTY write rc='wr~returnValue 'errno='wr~errno wr~errorMessage
  exit 4
end
polls=pty~structArray('pollfd',1)
polls~set(1,'fd',master)
polls~set(1,'events',pty~constant('POLLIN')~value)
pr=pty~poll(polls,1,1000)
if pr~returnValue<1 then do
  say 'FAIL poll rc='pr~returnValue 'errno='pr~errno pr~errorMessage
  exit 5
end
if polls~get(1,'revents')=0 then do
  say 'FAIL pollfd revents was zero'
  exit 6
end
buf=.foreign~buffer(64)
rr=pty~read(master,buf,64)
if rr~returnValue<>payload~length then do
  say 'FAIL PTY read rc='rr~returnValue 'errno='rr~errno rr~errorMessage
  exit 7
end
if buf~bytes~left(payload~length)<>payload then do
  say 'FAIL PTY exact-binary round trip'
  exit 8
end
polls~close
buf~close
master~close
slave~close
probe=.foreign~buffer(1)
bad=pty~read(rawMaster,probe,1)
if bad~returnValue<>-1 | bad~errno<>9 then do
  say 'FAIL expected EBADF after close rc='bad~returnValue 'errno='bad~errno bad~errorMessage
  exit 9
end
probe~close
say 'PASS Foreign Runtime -> POSIX openpty/poll/exact-binary/errno'
pty~close
exit 0
::requires '../rexx/foreign.cls'
