/* test_units.rex -- xtpd v0.1-dev1 file parsing, route table and checks; no root, no network.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 24 November 2026. */
fails = 0
dir = '/tmp/xtpd-units-'random(100000, 999999)
call SysMkDir dir

/* names and routes */
call check .XtpdCheck~serviceName('ssh.management'), 'service name accepted'
call check \.XtpdCheck~serviceName('ssh management'), 'a space in a service name is refused'
call check \.XtpdCheck~serviceName('SSH.Management'), 'upper case is refused'
call check .XtpdCheck~route(3, 'raw36', '20.0.154.12'), 'raw36 route accepted'
call check \.XtpdCheck~route(3, 'raw36', '20.0.154.256'), 'octet over 255 refused'
call check \.XtpdCheck~route(3, 'raw36', '20.0.154'), 'three octets refused'
call check .XtpdCheck~route(4, 'udp', '127.0.0.1:62801'), 'udp route accepted'
call check \.XtpdCheck~route(4, 'udp', '127.0.0.1'), 'udp without a port refused'
call check \.XtpdCheck~route(3, 'udp', '127.0.0.1:1'), 'layer and carrier must agree'

/* services.txt */
call write dir'/services.txt', .array~of('# comment', '', 'ssh.management management encrypt exec /usr/sbin/sshd -i -f /etc/ssh/x.conf')
s = .XtpdServices~new(dir'/services.txt')
reg = s~byName['ssh.management']
call check reg \== .nil, 'service registered'
call check reg['ARGV']~items = 4 & reg['ARGV'][1] == '/usr/sbin/sshd' & reg['ARGV'][4] == '/etc/ssh/x.conf', 'hook argv kept word by word'
call check s~csv == 'ssh.management', 'admitted set'
call refused 'XtpdServices', dir'/bad1.txt', 'svc management encrypt exec sshd -i', 'relative hook path'
call refused 'XtpdServices', dir'/bad2.txt', 'svc management secret exec /bin/x', 'unknown protection'
call refused 'XtpdServices', dir'/bad3.txt', 'svc management encrypt rexx /bin/x', 'hook kind other than exec'

/* peers.txt and the route table */
call write dir'/peers.txt', .array~of('cats2 3 raw36 20.118.224.14', 'ed209k 3 raw36 80.240.21.156')
p = .XtpdPeers~new(dir'/peers.txt')
call check p~peerForHost('80.240.21.156') == 'ed209k', 'peer found by host'
call check p~peerForHost('10.0.0.1') == '', 'an unknown host is no peer'
p~writeRoutes(dir'/routes.tsv', .array~of(.array~of(3, 'raw36', '20.0.154.12')))
r = .stream~new(dir'/routes.tsv'); lines = r~arrayIn; r~close
tab = '09'x
call check lines~items = 4, 'route table: header, two peers, one listen route'
call check lines[2] == 'cats2' || tab || '3' || tab || 'raw36' || tab || '20.118.224.14' || tab || tab || '100' || tab || '1' || tab || tab || '0', 'route line in libxtp format'
call check lines[4]~word(1) == 'xtpd.listen.1', 'listen route named xtpd.listen.1'
call refused 'XtpdPeers', dir'/bad4.txt', 'cats1 3 raw36 not.an.ip', 'bad address'

/* xtpd.conf */
call write dir'/xtpd.conf', .array~of('socket /run/xtpd/xtpd.sock', 'services /x', 'peers /y', 'routes /z', 'listen 3 raw36 20.0.154.12', 'allow_gid 1000')
c = .XtpdConfig~new(dir'/xtpd.conf')
call check c~listens~items = 1 & c~allowGids~hasIndex('1000') & c~allowUids~hasIndex(0), 'config parsed; root always allowed'
call refused 'XtpdConfig', dir'/bad5.conf', 'socket /a' || '0a'x || 'colour blue', 'unknown key'
call refused 'XtpdConfig', dir'/bad6.conf', 'socket /a', 'missing services, peers, routes'

/* a symbolic link is refused */
call write dir'/real.txt', .array~of('x')
address system 'ln -s' dir'/real.txt' dir'/link.txt'
signal on syntax name linkRefused
ignored = .XtpdText~lines(dir'/link.txt')
call check .false, 'a symbolic link is refused'
signal afterLink
linkRefused:
call check .true, 'a symbolic link is refused'
afterLink:
signal off syntax

address system 'rm -rf' dir
if fails = 0 then say 'PASS xtpd units: checks, services, peers, routes, config, symlink refusal'
else say 'FAIL xtpd units:' fails 'failed'
exit fails > 0

check: procedure expose fails
  use arg ok, label
  if \ok then do; fails = fails + 1; say 'FAIL' label; end
  return

write: procedure
  use arg path, lines
  call SysFileDelete path
  s = .stream~new(path); s~open('write replace')
  do l over lines; s~lineout(l); end
  s~close
  return

refused: procedure expose fails
  use arg className, path, text, label
  call write path, text~makeArray('0a'x)
  signal on syntax name wasRefused
  obj = .context~package~findClass(className)~new(path)
  fails = fails + 1; say 'FAIL refused:' label
  return
wasRefused:
  return

::requires 'Xtpd.cls'
