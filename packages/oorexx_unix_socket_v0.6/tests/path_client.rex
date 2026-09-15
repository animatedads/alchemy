numeric digits 50
parse arg socketPath
client = .UnixSocket~new('SOCK_STREAM')
if client~connect(.UnixAddress~pathname(socketPath)) \= 0 then call fail 'connect', client
localName = client~getSockName
if localName == .nil then call fail 'getSockName', client
if \localName~isUnnamed then do
  say 'FAIL expected unnamed local client address'
  exit 2
end
peerName = client~getPeerName
if peerName == .nil then call fail 'getPeerName', client
if peerName~string \== socketPath then do
  say 'FAIL peer path mismatch ['peerName~string']'
  exit 2
end
if client~sendAll('PING') \= 4 then call fail 'sendAll', client
reply = client~recv(64)
if reply \== 'PONG' then do
  say 'FAIL client expected PONG got ['reply']'
  exit 2
end
client~close
say 'PASS path client'
exit 0

fail:
  use arg where, sock
  say 'FAIL' where 'errno='sock~errno sock~errorText
  exit 2

::requires '../unixsocket.cls'
