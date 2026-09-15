numeric digits 50
parse arg path
if path == '' then path = '/tmp/oorexx-unix-echo.sock'

ignore = .UnixSocket~unlinkPath(path)
server = .UnixSocket~new('SOCK_STREAM')
if server~bind(.UnixAddress~pathname(path)) \= 0 then call fail server
if server~listen(16) \= 0 then call fail server

say 'listening on' path
peer = server~accept
if peer == .nil then call fail server

credentials = peer~peerCredentials
if credentials \== .nil then ,
  say 'peer pid='credentials~at('PID') 'uid='credentials~at('UID') 'gid='credentials~at('GID')

message = peer~recv(4096)
if message \== .nil then peer~sendAll('echo:' || message)
peer~close
server~close
ignore = .UnixSocket~unlinkPath(path)
exit 0

fail:
  use arg socket
  say 'FAIL errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
