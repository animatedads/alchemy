numeric digits 50
parse arg path message
if path == '' then path = '/tmp/oorexx-unix-echo.sock'
if message == '' then message = 'hello from ooRexx'

client = .UnixSocket~new('SOCK_STREAM')
if client~connect(.UnixAddress~pathname(path)) \= 0 then do
  say 'FAIL errno='client~errno client~errorText
  exit 1
end

if client~sendAll(message) < 0 then do
  say 'FAIL send errno='client~errno client~errorText
  exit 1
end

reply = client~recv(4096)
if reply == .nil then do
  say 'FAIL recv errno='client~errno client~errorText
  exit 1
end
say reply
client~close
exit 0

::requires '../unixsocket.cls'
