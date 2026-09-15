numeric digits 50
leftName = 'left' || '00'x || 'binary'
rightName = 'right' || '00'x || 'binary'
left = .UnixSocket~new('SOCK_DGRAM')
right = .UnixSocket~new('SOCK_DGRAM')
if left~bind(.UnixAddress~abstract(leftName)) \= 0 then call fail left, 'bind binary abstract left'
if right~bind(.UnixAddress~abstract(rightName)) \= 0 then call fail right, 'bind binary abstract right'
if left~getSockName~name \== leftName then do; say 'FAIL binary abstract getsockname'; exit 1; end
payload = 'binary-abstract-ok'
if left~sendTo(payload, .UnixAddress~abstract(rightName)) \= payload~length then call fail left, 'send binary abstract'
msg = right~recvFrom(4096)
if msg == .nil then call fail right, 'recv binary abstract'
if msg~data \== payload then do; say 'FAIL binary abstract payload'; exit 1; end
if \msg~address~isAbstract then do; say 'FAIL binary abstract namespace'; exit 1; end
if msg~address~name \== leftName then do; say 'FAIL embedded NUL abstract name not preserved'; exit 1; end
left~close; right~close
say 'PASS binary-safe Linux abstract namespace names including embedded NUL'
exit 0
fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1
::requires '../unixsocket.cls'
