numeric digits 50
pair = .UnixSocket~socketPair('SOCK_STREAM')
if pair == .nil then do; say 'FAIL socketPair'; exit 1; end
if \pair[1]~isCloseOnExec | \pair[2]~isCloseOnExec then do
  say 'FAIL socketPair descriptors not CLOEXEC'
  exit 1
end
carrier = .UnixSocket~socketPair('SOCK_STREAM')
fds = .array~of(pair[1]~fd)
if carrier[1]~sendDescriptors('C', fds) \= 1 then do
  say 'FAIL descriptor send errno='carrier[1]~errno carrier[1]~errorText
  exit 1
end
msg = carrier[2]~recvDescriptors(64, 4)
if msg == .nil then do
  say 'FAIL descriptor receive errno='carrier[2]~errno carrier[2]~errorText
  exit 1
end
received = msg~descriptors[1]
if \received~isCloseOnExec then do
  say 'FAIL received SCM_RIGHTS descriptor not CLOEXEC'
  exit 1
end
received~close
pair[1]~close; pair[2]~close
carrier[1]~close; carrier[2]~close
say 'PASS created and SCM_RIGHTS-received descriptors default to CLOEXEC'
exit 0
::requires '../unixsocket.cls'
