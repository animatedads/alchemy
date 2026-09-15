numeric digits 50
socketPath = '/tmp/oorexx-ux-path-helper.sock'
regularPath = '/tmp/oorexx-ux-path-helper.regular'
ignore = .UnixSocket~unlinkPath(socketPath)
ignore = .UnixSocket~unlinkPath(regularPath)

/* A regular file must never be accepted by the socket-only mutation helpers. */
call lineout regularPath, 'ordinary file'
call stream regularPath, 'c', 'close'
if .UnixSocket~unlinkSocketPath(regularPath) \= -1 then do
  say 'FAIL safe unlink removed regular file'
  exit 1
end
if .UnixSocket~lastErrno = 0 then do; say 'FAIL safe unlink regular file did not set errno'; exit 1; end
if .UnixSocket~chmodSocketPath(regularPath, '0600') \= -1 then do
  say 'FAIL socket chmod accepted regular file'
  exit 1
end
if stream(regularPath, 'c', 'query exists') == '' then do
  say 'FAIL regular file disappeared'
  exit 1
end

server = .UnixSocket~new('SOCK_STREAM')
if server~bind(.UnixAddress~pathname(socketPath)) \= 0 then call fail server, 'bind'
info = .UnixSocket~pathInfo(socketPath)
if info == .nil | \info~at('IS_SOCKET') then do; say 'FAIL pathInfo did not identify socket'; exit 1; end

if .UnixSocket~chmodSocketPath(socketPath, '0600') \= 0 then do
  say 'FAIL chmodSocketPath errno=' .UnixSocket~lastErrno .UnixSocket~lastErrorText
  exit 1
end
info = .UnixSocket~pathInfo(socketPath)
if info == .nil | info~at('MODE_OCTAL') \== '0600' then do
  say 'FAIL socket mode expected 0600 actual='info~at('MODE_OCTAL')
  exit 1
end

/* -1/-1 is an explicit no-change chown and exercises the pinned inode path. */
if .UnixSocket~chownSocketPath(socketPath, -1, -1) \= 0 then do
  say 'FAIL chownSocketPath errno=' .UnixSocket~lastErrno .UnixSocket~lastErrorText
  exit 1
end

server~close
if .UnixSocket~unlinkSocketPath(socketPath) \= 0 then do
  say 'FAIL unlinkSocketPath errno=' .UnixSocket~lastErrno .UnixSocket~lastErrorText
  exit 1
end
if .UnixSocket~pathInfo(socketPath) \== .nil then do; say 'FAIL socket path still exists'; exit 1; end

ignore = .UnixSocket~unlinkPath(regularPath)
say 'PASS socket-only pathname inspection, pinned chmod/chown, and non-socket unlink refusal'
exit 0

fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
