numeric digits 50
leftPath = '/tmp/oorexx-ux-dgram-left.sock'
rightPath = '/tmp/oorexx-ux-dgram-right.sock'
ignore = .UnixSocket~unlinkPath(leftPath)
ignore = .UnixSocket~unlinkPath(rightPath)

left = .UnixSocket~new('SOCK_DGRAM')
right = .UnixSocket~new('SOCK_DGRAM')
if left~bind(.UnixAddress~pathname(leftPath)) \= 0 then call fail left, 'bind left'
if right~bind(.UnixAddress~pathname(rightPath)) \= 0 then call fail right, 'bind right'

payload = 'dgram' || '00'x || 'payload'
if left~sendTo(payload, .UnixAddress~pathname(rightPath)) \= payload~length then call fail left, 'sendTo'
msg = right~recvFrom(4096)
if msg == .nil then call fail right, 'recvFrom'
if msg~data \== payload then do; say 'FAIL datagram payload'; exit 1; end
if msg~address~namespace \== 'PATHNAME' then do; say 'FAIL datagram namespace'; exit 1; end
if msg~address~name \== leftPath then do; say 'FAIL datagram sender address:' msg~address~name; exit 1; end

left~close
right~close
ignore = .UnixSocket~unlinkPath(leftPath)
ignore = .UnixSocket~unlinkPath(rightPath)
say 'PASS pathname SOCK_DGRAM sendTo/recvFrom with binary payload and sender address'
exit 0

fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
