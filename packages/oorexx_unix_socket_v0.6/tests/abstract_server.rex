numeric digits 50
parse arg socketName readyFile
server = .UnixSocket~new('SOCK_STREAM')
if \server~isCloseOnExec then do; say 'FAIL created server not CLOEXEC'; exit 2; end
if server~bind(.UnixAddress~abstract(socketName)) \= 0 then call fail 'bind', server
if server~listen(8) \= 0 then call fail 'listen', server
bound = server~getSockName
if bound == .nil then call fail 'getsockname', server
if \bound~isAbstract | bound~name \== socketName then do
  say 'FAIL abstract bound name ['bound~string']'
  exit 2
end
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
if msg \== 'HELLO' then do
  say 'FAIL server expected HELLO got ['msg']'
  exit 2
end
if peer~sendAll('WORLD') \= 5 then call fail 'sendAll', peer
peer~close
server~close
say 'PASS abstract server'
exit 0

fail:
  use arg where, sock
  say 'FAIL' where 'errno='sock~errno sock~errorText
  exit 2

::requires '../unixsocket.cls'
