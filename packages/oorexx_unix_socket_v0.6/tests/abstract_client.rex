numeric digits 50
parse arg socketName
client = .UnixSocket~new('SOCK_STREAM')
if client~connect(.UnixAddress~abstract(socketName)) \= 0 then call fail 'connect', client
localName = client~getSockName
if localName == .nil then call fail 'getSockName', client
if \localName~isUnnamed then do
  say 'FAIL expected unnamed local client address'
  exit 2
end
peerName = client~getPeerName
if peerName == .nil then call fail 'getPeerName', client
if \peerName~isAbstract | peerName~name \== socketName then do
  say 'FAIL abstract peer name ['peerName~string']'
  exit 2
end
if client~sendAll('HELLO') \= 5 then call fail 'sendAll', client
reply = client~recv(64)
if reply \== 'WORLD' then do
  say 'FAIL client expected WORLD got ['reply']'
  exit 2
end
client~close
say 'PASS abstract client'
exit 0

fail:
  use arg where, sock
  say 'FAIL' where 'errno='sock~errno sock~errorText
  exit 2

::requires '../unixsocket.cls'
