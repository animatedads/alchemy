numeric digits 50
control = .UnixSocket~socketPair('SOCK_STREAM')
dataPair = .UnixSocket~socketPair('SOCK_STREAM')
if control == .nil | dataPair == .nil then do
  say 'FAIL socketPair setup'
  exit 1
end

fds = .array~new(1)
fds[1] = dataPair[1]~fd
if control[1]~sendDescriptors('F', fds) \= 1 then call fail control[1], 'sendDescriptors'
message = control[2]~recvDescriptors(64, 4)
if message == .nil then call fail control[2], 'recvDescriptors'
if message~data \== 'F' then do; say 'FAIL SCM_RIGHTS payload'; exit 1; end
if message~descriptors~items \= 1 then do; say 'FAIL descriptor count'; exit 1; end
receivedDescriptor = message~descriptors[1]
if receivedDescriptor~isClosed then do; say 'FAIL received descriptor unexpectedly closed'; exit 1; end
receivedFd = receivedDescriptor~release
if receivedFd < 0 then do; say 'FAIL descriptor release'; exit 1; end
receivedSocket = .UnixSocket~adopt(receivedFd, 'SOCK_STREAM')

probe = 'descriptor-pass' || '00'x || 'ok'
if dataPair[2]~sendAll(probe) \= probe~length then call fail dataPair[2], 'send data through original peer'
actual = receivedSocket~recv(4096)
if actual \== probe then do; say 'FAIL received fd is not live transferred socket'; exit 1; end

receivedSocket~close
control[1]~close
control[2]~close
dataPair[1]~close
dataPair[2]~close
say 'PASS SCM_RIGHTS descriptor transfer, ownership release, and live socket use'
exit 0

fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
