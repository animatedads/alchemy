numeric digits 50
carrier = .UnixSocket~socketPair('SOCK_STREAM')
resource = .UnixSocket~socketPair('SOCK_STREAM')

fds = .array~of(resource[1]~fd)
if carrier[1]~sendDescriptors('F', fds) \= 1 then do
  say 'sendDescriptors failed:' carrier[1]~errno carrier[1]~errorText
  exit 1
end

message = carrier[2]~recvDescriptors(64, 4)
if message == .nil then do
  say 'recvDescriptors failed:' carrier[2]~errno carrier[2]~errorText
  exit 1
end

received = message~descriptors[1]
passedSocket = .UnixSocket~adopt(received~release, 'SOCK_STREAM')
resource[2]~sendAll('the transferred socket is live')
say passedSocket~recv(4096)

passedSocket~close
carrier[1]~close; carrier[2]~close
resource[1]~close; resource[2]~close
::requires '../unixsocket.cls'
