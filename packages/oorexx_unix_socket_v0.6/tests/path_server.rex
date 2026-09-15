numeric digits 50
parse arg socketPath readyFile
unlinkRc = .UnixSocket~unlinkPath(socketPath)
address = .UnixAddress~pathname(socketPath)
server = .UnixSocket~new('SOCK_STREAM')
if server~fd < 0 then call fail 'create', server
if \server~isCloseOnExec then do; say 'FAIL created server not CLOEXEC'; exit 2; end
if server~bind(address) \= 0 then call fail 'bind', server
if server~listen(8) \= 0 then call fail 'listen', server
call lineout readyFile, 'READY'
call lineout readyFile
peer = server~accept
if peer == .nil then call fail 'accept', server
if \peer~isCloseOnExec then do; say 'FAIL accepted peer not CLOEXEC'; exit 2; end
peerName = peer~getPeerName
if peerName == .nil then call fail 'getPeerName', peer
if \peerName~isUnnamed then do
  say 'FAIL expected unnamed client peer address'
  exit 2
end
msg = peer~recv(64)
if msg \== 'PING' then do
  say 'FAIL server expected PING got ['msg']'
  exit 2
end
cred = peer~peerCredentials
if cred == .nil then call fail 'peerCredentials', peer
if peer~sendAll('PONG') \= 4 then call fail 'sendAll', peer
peer~close
server~close
unlinkRc = .UnixSocket~unlinkPath(socketPath)
say 'PASS path server'
exit 0

fail:
  use arg where, sock
  say 'FAIL' where 'errno='sock~errno sock~errorText
  exit 2

::requires '../unixsocket.cls'
