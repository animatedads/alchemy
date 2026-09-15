numeric digits 50
path = '/tmp/oorexx-ux-dgram-unbound.sock'
ignore = .UnixSocket~unlinkPath(path)
receiver = .UnixSocket~new('SOCK_DGRAM')
sender = .UnixSocket~new('SOCK_DGRAM')
if receiver~bind(.UnixAddress~pathname(path)) \= 0 then call fail receiver, 'bind receiver'
payload = 'unbound sender'
if sender~sendTo(payload, .UnixAddress~pathname(path)) \= payload~length then call fail sender, 'sendTo unbound'
msg = receiver~recvFrom(4096)
if msg == .nil then call fail receiver, 'recvFrom unbound'
if msg~data \== payload then do; say 'FAIL unbound datagram payload'; exit 1; end
if \msg~address~isUnnamed then do; say 'FAIL expected unnamed datagram sender'; exit 1; end
sender~close; receiver~close
ignore = .UnixSocket~unlinkPath(path)
say 'PASS unbound SOCK_DGRAM sender is represented as UNNAMED'
exit 0
fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1
::requires '../unixsocket.cls'
