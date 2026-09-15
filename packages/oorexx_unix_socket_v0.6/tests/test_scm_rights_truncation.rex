numeric digits 50
control = .UnixSocket~socketPair('SOCK_STREAM')
data1 = .UnixSocket~socketPair('SOCK_STREAM')
data2 = .UnixSocket~socketPair('SOCK_STREAM')
if control == .nil | data1 == .nil | data2 == .nil then do
  say 'FAIL truncation setup'
  exit 1
end
fds = .array~new(2)
fds[1] = data1[1]~fd
fds[2] = data2[1]~fd
if control[1]~sendDescriptors('T', fds) \= 1 then do
  say 'FAIL sendDescriptors truncation setup errno='control[1]~errno control[1]~errorText
  exit 1
end
message = control[2]~recvDescriptors(64, 1)
if message \== .nil then do
  say 'FAIL expected ancillary truncation to fail closed'
  exit 1
end
if control[2]~errno = 0 then do
  say 'FAIL truncation returned no errno'
  exit 1
end
savedErrno = control[2]~errno
control[1]~close; control[2]~close
data1[1]~close; data1[2]~close
data2[1]~close; data2[2]~close
say 'PASS SCM_RIGHTS ancillary truncation fails closed errno='savedErrno
exit 0
::requires '../unixsocket.cls'
