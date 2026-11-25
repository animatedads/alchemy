/* xtp_request.rex -- ask the local xtpd for a session to a named service, and
 * hand the connected descriptor to OpenSSH (ProxyUseFdpass) on stdout.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 24 November 2026.
 *
 * In ~/.ssh/config:
 *   Host cats1
 *     ProxyUseFdpass yes
 *     ProxyCommand rexx /opt/xtpd/bin/xtp_request.rex ssh.management %n
 * Options: --socket PATH (default /run/xtpd/xtpd.sock).
 * dev2 (Claude (Opus 5.5), 25 Nov 2026): also
 *   rexx xtp_request.rex [--socket PATH] STATUS   prints xtpd's status line
 *   rexx xtp_request.rex [--socket PATH] ROLE     re-runs the role check, prints the line
 * Both are root only in xtpd; exit 0 when xtpd answered OK. */
parse arg args
sock = '/run/xtpd/xtpd.sock'
if args~word(1) == '--socket' then do
  sock = args~word(2)
  args = args~subWord(3)
end
parse var args service peer extra
if (service == 'STATUS' | service == 'ROLE') & peer == '' then do
  conn = .UnixSocket~new('SOCK_STREAM')
  if conn~connect(.UnixAddress~pathname(sock)) \= 0 then do
    .error~lineout('xtp_request: cannot reach xtpd at' sock':' conn~errorText)
    exit 1
  end
  conn~sendAll(service || '0a'x)
  answer = ''
  do 64 while answer~pos('0a'x) = 0
    msg = conn~recvMessage(512, 0)
    if msg == .nil | msg~data == '' then leave
    answer = answer || msg~data
  end
  conn~close
  parse var answer answer '0a'x .
  say answer
  if answer~word(1) == 'OK' then exit 0
  exit 1
end
if peer == '' | extra \== '' then do
  .error~lineout('usage: rexx xtp_request.rex [--socket PATH] SERVICE PEER | STATUS | ROLE')
  exit 2
end
conn = .UnixSocket~new('SOCK_STREAM')
if conn~connect(.UnixAddress~pathname(sock)) \= 0 then do
  .error~lineout('xtp_request: cannot reach xtpd at' sock':' conn~errorText)
  exit 1
end
conn~sendAll('OPEN' service peer || '0a'x)
msg = conn~recvMessage(512, 1)
if msg == .nil then do
  .error~lineout('xtp_request: no answer from xtpd:' conn~errorText)
  exit 1
end
if msg~descriptors~items = 0 then do
  parse value msg~data with answer '0a'x .
  .error~lineout('xtp_request:' answer)
  exit 1
end
out = .UnixSocket~adopt(1)
if out == .nil | out~sendDescriptors('K', msg~descriptors) < 0 then do
  .error~lineout('xtp_request: stdout is not a socket; use ProxyUseFdpass yes')
  exit 1
end
exit 0
::requires 'unixsocket.cls'
