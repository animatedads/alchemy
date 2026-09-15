numeric digits 50
pair = .UnixSocket~socketPair('SOCK_STREAM')
if pair == .nil then do
  say 'FAIL socketPair'
  exit 1
end
left = pair[1]
right = pair[2]

payload = 'abc' || '00'x || 'xyz'
if left~sendAll(payload) \= payload~length then do
  say 'FAIL sendAll errno='left~errno left~errorText
  exit 1
end
received = right~recv(64)
if received == .nil then do
  say 'FAIL recv errno='right~errno right~errorText
  exit 1
end
if received \== payload then do
  say 'FAIL binary payload mismatch'
  exit 1
end

cred = left~peerCredentials
if cred == .nil then do
  say 'FAIL peerCredentials errno='left~errno left~errorText
  exit 1
end
if cred~at('PID')~datatype('W') \= 1 then do
  say 'FAIL peer pid'
  exit 1
end

left~close
right~close
say 'PASS class smoke: socketpair, binary send/recv, peer credentials'
exit 0
::requires '../unixsocket.cls'
