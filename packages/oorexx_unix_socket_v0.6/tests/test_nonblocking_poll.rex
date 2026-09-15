numeric digits 50
pair = .UnixSocket~socketPair('SOCK_STREAM')
if pair == .nil then do; say 'FAIL socketPair'; exit 1; end

if pair[2]~setNonBlocking(.true) \= 0 then call fail pair[2], 'setNonBlocking true'
if pair[2]~isNonBlocking \== .true then do; say 'FAIL nonblocking state'; exit 1; end

empty = pair[2]~recv(32)
if empty \== .nil then do; say 'FAIL empty nonblocking recv did not return nil'; exit 1; end
if \pair[2]~wouldBlock then do
  say 'FAIL empty nonblocking recv errno not would-block:' pair[2]~errno pair[2]~errorText
  exit 1
end

readWatch = .UnixPollWatch~read(pair[2])
watches = .array~of(readWatch)
ready = .UnixPoll~wait(watches, 0)
if ready == .nil then do; say 'FAIL initial poll errno=' .UnixPoll~errno .UnixPoll~errorText; exit 1; end
if ready~items \= 0 then do; say 'FAIL unread socket unexpectedly readable'; exit 1; end

payload = 'poll-ready' || '00'x || 'binary'
if pair[1]~send(payload) \= payload~length then call fail pair[1], 'send'
ready = .UnixPoll~wait(watches, 1000)
if ready == .nil then do; say 'FAIL readable poll errno=' .UnixPoll~errno .UnixPoll~errorText; exit 1; end
if ready~items \= 1 then do; say 'FAIL readable poll count='ready~items; exit 1; end
if \ready[1]~readable | ready[1]~fd \= pair[2]~fd then do; say 'FAIL readable poll result'; exit 1; end
if ready[1]~target \== pair[2] then do; say 'FAIL poll target identity'; exit 1; end
actual = pair[2]~recv(4096)
if actual \== payload then do; say 'FAIL nonblocking receive payload'; exit 1; end

writeReady = .UnixPoll~wait(.array~of(.UnixPollWatch~write(pair[1])), 0)
if writeReady == .nil | writeReady~items \= 1 | \writeReady[1]~writable then do
  say 'FAIL writable poll'
  exit 1
end

/* sendAll deliberately refuses nonblocking sockets: otherwise a partial write
   followed by EAGAIN would leave the caller unable to know the committed prefix. */
if pair[1]~setNonBlocking(.true) \= 0 then call fail pair[1], 'set sender nonblocking'
if pair[1]~sendAll('unsafe-on-nonblocking') \= -1 then do
  say 'FAIL sendAll accepted nonblocking descriptor'
  exit 1
end
if pair[1]~wouldBlock then do
  say 'FAIL sendAll nonblocking refusal incorrectly reported as would-block'
  exit 1
end

if pair[1]~setNonBlocking(.false) \= 0 then call fail pair[1], 'restore sender blocking'
if pair[2]~setNonBlocking(.false) \= 0 then call fail pair[2], 'restore receiver blocking'
if pair[2]~isNonBlocking \== .false then do; say 'FAIL blocking restore state'; exit 1; end

pair[1]~close
pair[2]~close
say 'PASS nonblocking mode, would-block classification, semantic poll readiness, and sendAll safety'
exit 0

fail:
  use arg socket, where
  say 'FAIL' where 'errno='socket~errno socket~errorText
  exit 1

::requires '../unixsocket.cls'
