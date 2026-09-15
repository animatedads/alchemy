numeric digits 50
parse arg path
if path == '' then path = '/tmp/oorexx-credential-example.sock'
ignore = .UnixSocket~unlinkSocketPath(path)

receiver = .UnixSocket~new('SOCK_DGRAM')
if receiver~bind(.UnixAddress~pathname(path)) \= 0 then call fail receiver, 'bind'
if receiver~setPassCredentials(.true) \= 0 then call fail receiver, 'SO_PASSCRED'

say 'waiting on' path
message = receiver~recvMessage(4096, 0)
if message == .nil then call fail receiver, 'recvMessage'

say 'payload:' message~data
if message~hasCredentials then do
  c = message~credentials
  say 'kernel sender pid='c~at('PID') 'uid='c~at('UID') 'gid='c~at('GID')
end
else say 'no per-message credentials supplied'

receiver~close
ignore = .UnixSocket~unlinkSocketPath(path)
exit 0

fail:
  use arg socket, where
  say where 'failed errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
