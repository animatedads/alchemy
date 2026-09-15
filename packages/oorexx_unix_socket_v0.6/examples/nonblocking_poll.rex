numeric digits 50
pair = .UnixSocket~socketPair('SOCK_STREAM')
if pair == .nil then do; say 'socketPair failed'; exit 1; end

receiver = pair[2]
receiver~setNonBlocking(.true)
watch = .UnixPollWatch~read(receiver)

pair[1]~send('hello from poll')
ready = .UnixPoll~wait(.array~of(watch), 1000)
if ready == .nil then do
  say 'poll failed:' .UnixPoll~errno .UnixPoll~errorText
  exit 1
end

if ready~items > 0 & ready[1]~readable then do
  data = receiver~recv(4096)
  if data == .nil & receiver~wouldBlock then say 'readiness changed before recv'
  else say data
end

pair[1]~close
pair[2]~close
exit 0

::requires '../unixsocket.cls'
