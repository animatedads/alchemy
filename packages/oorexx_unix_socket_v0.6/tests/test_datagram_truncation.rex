numeric digits 50
leftPath = '/tmp/oorexx-ux-dgram-trunc-left.sock'
rightPath = '/tmp/oorexx-ux-dgram-trunc-right.sock'
ignore = .UnixSocket~unlinkPath(leftPath)
ignore = .UnixSocket~unlinkPath(rightPath)
left = .UnixSocket~new('SOCK_DGRAM')
right = .UnixSocket~new('SOCK_DGRAM')
if left~bind(.UnixAddress~pathname(leftPath)) \= 0 then call fail left, 'bind left'
if right~bind(.UnixAddress~pathname(rightPath)) \= 0 then call fail right, 'bind right'
payload = copies('X', 128)
if left~sendTo(payload, .UnixAddress~pathname(rightPath)) \= payload~length then call fail left, 'sendTo'
msg = right~recvFrom(7)
if msg == .nil then call fail right, 'recvFrom'
if msg~data~length \= 7 then do; say 'FAIL truncated data length' msg~data~length; exit 1; end
if \msg~truncated then do; say 'FAIL MSG_TRUNC not surfaced'; exit 1; end
left~close; right~close
ignore = .UnixSocket~unlinkPath(leftPath)
ignore = .UnixSocket~unlinkPath(rightPath)
say 'PASS datagram truncation is surfaced explicitly'
exit 0
fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1
::requires '../unixsocket.cls'
