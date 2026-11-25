/* selftest_ffi.rex -- the foreign calls xtpd makes must work on this node.
 * Without libffi the foreign runtime falls back to a dispatcher limited to three
 * arguments, so calls such as send, recvmsg and getsockopt fail; a poll does not
 * show it (found on Ubuntu 26.04 minimal, 25 Nov 2026).
 * Claude (Opus 5.5), 25 November 2026. */
signal on syntax name broken
/* the calls xtpd's control socket makes, several with four or more arguments */
pair = .UnixSocket~socketPair('SOCK_STREAM')
if pair == .nil then signal noPair
if pair[1]~sendAll('xtpd-selftest') < 0 then signal broken
ready = .UnixPoll~wait(.array~of(.UnixPollWatch~read(pair[2])), 1000)
msg = pair[2]~recvMessage(64, 0)
if msg == .nil then signal broken
if msg~data \== 'xtpd-selftest' then signal broken
cred = pair[2]~peerCredentials
if cred == .nil then signal broken
pair[1]~close; pair[2]~close
say 'PASS foreign calls (socketpair, send, poll, recvmsg, peer credentials) work on this node'
exit 0
noPair:
say 'FAIL foreign calls: no socketpair'
exit 1
broken:
why = 'a call returned an error'
if condition('C') == 'SYNTAX' then why = condition('O')['ADDITIONAL']~makeString~left(160)
say 'FAIL foreign calls:' why
exit 1
::requires 'unixsocket.cls'
