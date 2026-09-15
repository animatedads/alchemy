numeric digits 50
leftName = 'oorexx-ux-dgram-left-v02'
rightName = 'oorexx-ux-dgram-right-v02'
left = .UnixSocket~new('SOCK_DGRAM')
right = .UnixSocket~new('SOCK_DGRAM')
if left~bind(.UnixAddress~abstract(leftName)) \= 0 then call fail left, 'bind left abstract'
if right~bind(.UnixAddress~abstract(rightName)) \= 0 then call fail right, 'bind right abstract'

payload = 'abstract-dgram'
if left~sendTo(payload, .UnixAddress~abstract(rightName)) \= payload~length then call fail left, 'sendTo abstract'
msg = right~recvFrom(4096)
if msg == .nil then call fail right, 'recvFrom abstract'
if msg~data \== payload then do; say 'FAIL abstract datagram payload'; exit 1; end
if \msg~address~isAbstract then do; say 'FAIL abstract sender namespace'; exit 1; end
if msg~address~name \== leftName then do; say 'FAIL abstract sender address'; exit 1; end
left~close
right~close
say 'PASS abstract SOCK_DGRAM sendTo/recvFrom'
exit 0

fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
