numeric digits 50
use strict arg path
ignore = .UnixSocket~unlinkPath(path)
socket = .UnixSocket~new('SOCK_DGRAM')
if socket~bind(.UnixAddress~pathname(path)) \= 0 then do
  say 'bind failed:' socket~errno socket~errorText
  exit 1
end
say 'receiving on' path
message = socket~recvFrom(4096)
if message == .nil then do
  say 'recvFrom failed:' socket~errno socket~errorText
  exit 1
end
say 'from:' message~address
say 'bytes:' message~data~length 'truncated:' message~truncated
say 'data:' message~data
socket~close
ignore = .UnixSocket~unlinkPath(path)
::requires '../unixsocket.cls'
