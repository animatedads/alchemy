numeric digits 50
parse arg path
if path == '' then path = '/tmp/oorexx-permission-example.sock'
ignore = .UnixSocket~unlinkSocketPath(path)

server = .UnixSocket~new('SOCK_STREAM')
if server~bind(.UnixAddress~pathname(path)) \= 0 then call fail server, 'bind'

if .UnixSocket~chmodSocketPath(path, '0600') \= 0 then do
  say 'chmod failed errno=' .UnixSocket~lastErrno .UnixSocket~lastErrorText
  exit 1
end

info = .UnixSocket~pathInfo(path)
say 'socket mode='info~at('MODE_OCTAL') 'uid='info~at('UID') 'gid='info~at('GID')

server~close
ignore = .UnixSocket~unlinkSocketPath(path)
exit 0

fail:
  use arg socket, where
  say where 'failed errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
