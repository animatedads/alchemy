numeric digits 50
s = .UnixSocket~new('SOCK_DGRAM')
if s~fd < 0 then call fail s, 'create'

initialReceive = s~receiveBuffer
initialSend = s~sendBuffer
if initialReceive == .nil | initialReceive <= 0 then do; say 'FAIL initial receive buffer'; exit 1; end
if initialSend == .nil | initialSend <= 0 then do; say 'FAIL initial send buffer'; exit 1; end

requested = 8192
if s~setReceiveBuffer(requested) \= 0 then call fail s, 'setReceiveBuffer'
if s~setSendBuffer(requested) \= 0 then call fail s, 'setSendBuffer'
actualReceive = s~receiveBuffer
actualSend = s~sendBuffer
if actualReceive == .nil | actualReceive < requested then do
  say 'FAIL receive buffer requested='requested 'actual='actualReceive
  exit 1
end
if actualSend == .nil | actualSend < requested then do
  say 'FAIL send buffer requested='requested 'actual='actualSend
  exit 1
end

s~close
say 'PASS explicit SO_RCVBUF/SO_SNDBUF whitelist with kernel-normalized values'
exit 0

fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
