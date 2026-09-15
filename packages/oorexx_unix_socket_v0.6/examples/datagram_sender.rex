numeric digits 50
parse arg path message
if message == '' then message = 'hello over AF_UNIX datagram'
socket = .UnixSocket~new('SOCK_DGRAM')
rc = socket~sendTo(message, .UnixAddress~pathname(path))
if rc < 0 then do
  say 'sendTo failed:' socket~errno socket~errorText
  exit 1
end
say 'sent bytes:' rc
socket~close
::requires '../unixsocket.cls'
