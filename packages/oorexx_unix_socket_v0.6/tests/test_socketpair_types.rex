numeric digits 50
do type over .array~of('SOCK_DGRAM', 'SOCK_SEQPACKET')
  pair = .UnixSocket~socketPair(type)
  if pair == .nil then do
    say 'FAIL socketPair' type
    exit 1
  end
  payload = type || ':' || '00'x || 'ok'
  if pair[1]~send(payload) \= payload~length then do
    say 'FAIL send' type 'errno='pair[1]~errno pair[1]~errorText
    exit 1
  end
  actual = pair[2]~recv(4096)
  if actual \== payload then do
    say 'FAIL recv payload' type
    exit 1
  end
  pair[1]~close; pair[2]~close
end
say 'PASS SOCK_DGRAM and SOCK_SEQPACKET socketPair transport'
exit 0
::requires '../unixsocket.cls'
